// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { IVotes } from "@openzeppelin-upgradeable/contracts/governance/extensions/GovernorVotesUpgradeable.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2Governor } from "src/L2/L2Governor.sol";
import "script/Utils.sol";

/// @title IL2Staking
/// @notice Interface for L2 Staking contract. Used to initialize Staking contract.
interface IL2Staking {
    function initializeDao(address daoContract) external;
    function daoContract() external view returns (address);
}

/// @title L2GovernorScript - L2 Timelock Controller and Governor contracts deployment script
/// @notice This contract is used to deploy L2 TimelockController and Governor contracts.
contract L2GovernorScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    /// @notice Array of addresses that can execute proposals.
    address[] executors;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2 Governor and TimelockController contracts, grants the proposer and executor
    /// roles to the Governor contract, and revokes the admin role of the deployer account for the TimelockController
    /// contract.
    function run() public {
        // Deployer's private key. Owner of the L2 Governor. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2 TimelockController and Governor contracts...");

        // get L2Staking contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        assert(l2AddressesConfig.L2Staking != address(0));
        console2.log("L2 Staking address: %s", l2AddressesConfig.L2Staking);
        IL2Staking stakingContract = IL2Staking(l2AddressesConfig.L2Staking);

        // get L2VotingPower contract address
        assert(l2AddressesConfig.L2VotingPower != address(0));
        console2.log("L2 Voting Power address: %s", l2AddressesConfig.L2VotingPower);
        IVotes votingPower = IVotes(l2AddressesConfig.L2VotingPower);

        // Get L2Governor contract owner address. Ownership is transferred to this address after deployment.
        address ownerAddress = vm.envAddress("L2_GOVERNOR_OWNER_ADDRESS");
        assert(ownerAddress != address(0));
        console2.log("L2 Governor owner address: %s (after ownership will be accepted)", ownerAddress);

        // deploy TimelockController contract
        vm.startBroadcast(deployerPrivateKey);
        executors.push(address(0)); // executor array contains address(0) such that anyone can execute proposals
        TimelockController timelock =
            new TimelockController(0, new address[](0), executors, vm.addr(deployerPrivateKey));
        vm.stopBroadcast();
        assert(address(timelock) != address(0));
        // address(0) has the executor role
        assert(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)) == true);

        // deploy L2Governor implementation contract
        vm.startBroadcast(deployerPrivateKey);
        L2Governor l2GovernorImplementation = new L2Governor();
        vm.stopBroadcast();
        assert(address(l2GovernorImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2GovernorImplementation.proxiableUUID() == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        // deploy L2Governor proxy contract and at the same time initialize the proxy contract (calls the
        // initialize function in L2Governor)
        vm.startBroadcast(deployerPrivateKey);
        ERC1967Proxy l2GovernorProxy = new ERC1967Proxy(
            address(l2GovernorImplementation),
            abi.encodeWithSelector(
                l2GovernorImplementation.initialize.selector, votingPower, timelock, vm.addr(deployerPrivateKey)
            )
        );
        vm.stopBroadcast();
        assert(address(l2GovernorProxy) != address(0));

        // wrap in ABI to support easier calls
        L2Governor l2Governor = L2Governor(payable(address(l2GovernorProxy)));
        assert(keccak256(bytes(l2Governor.name())) == keccak256(bytes("Lisk Governor")));
        assert(l2Governor.votingDelay() == 0);
        assert(l2Governor.votingPeriod() == 604800);
        assert(l2Governor.proposalThreshold() == 300_000 * 10 ** 18);
        assert(l2Governor.timelock() == address(timelock));
        assert(l2Governor.quorum(0) == 24_000_000 * 10 ** 18);
        assert(address(l2Governor.token()) == address(votingPower));
        assert(l2Governor.owner() == vm.addr(deployerPrivateKey));

        // initialize the L2Staking contract by calling initializeDao of the L2Staking contract
        vm.startBroadcast(deployerPrivateKey);
        stakingContract.initializeDao(address(timelock));
        vm.stopBroadcast();
        assert(stakingContract.daoContract() == address(timelock));

        // grant the proposer role to the Governor contract
        vm.startBroadcast(deployerPrivateKey);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(l2Governor));
        vm.stopBroadcast();
        assert(timelock.hasRole(timelock.PROPOSER_ROLE(), address(l2Governor)));
        // Governor contract does not have the executor role
        assert(!timelock.hasRole(timelock.EXECUTOR_ROLE(), address(l2Governor)));

        // revoke the admin role of our admin account for TimeLockController contract
        vm.startBroadcast(deployerPrivateKey);
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), vm.addr(deployerPrivateKey));
        vm.stopBroadcast();
        assert(!timelock.hasRole(timelock.DEFAULT_ADMIN_ROLE(), vm.addr(deployerPrivateKey)));

        // transfer ownership of the L2Governor contract to the owner address; because of using Ownable2StepUpgradeable
        // contract, new owner has to accept ownership
        vm.startBroadcast(deployerPrivateKey);
        l2Governor.transferOwnership(ownerAddress);
        vm.stopBroadcast();
        assert(l2Governor.owner() == vm.addr(deployerPrivateKey)); // ownership is not yet accepted

        console2.log("L2 TimelockController and Governor contracts successfully deployed!");
        console2.log("L2 TimelockController address: %s", address(timelock));
        console2.log("L2 Governor (implementation) address: %s", address(l2GovernorImplementation));
        console2.log("L2 Governor (proxy) address: %s", address(l2Governor));
        console2.log("L2 Governor owner address: %s (after ownership will be accepted)", ownerAddress);

        // write TimelockController and L2 Governor addresses to l2addresses.json
        l2AddressesConfig.L2TimelockController = address(timelock);
        l2AddressesConfig.L2GovernorImplementation = address(l2GovernorImplementation);
        l2AddressesConfig.L2Governor = address(l2Governor);
        utils.writeL2AddressesFile(l2AddressesConfig);
    }
}
