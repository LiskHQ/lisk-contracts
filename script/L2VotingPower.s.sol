// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";
import "script/Utils.sol";

/// @title IL2LockingPosition
/// @notice Interface for L2 Locking Position contract. Used to initialize Voting Power contract.
interface IL2LockingPosition {
    function initializeVotingPower(address votingPowerContract) external;
    function votingPowerContract() external view returns (address);
}

/// @title L2VotingPowerScript - L2 Voting Power contract deployment script
/// @notice This contract is used to deploy L2 Voting Power contract.
contract L2VotingPowerScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2 Voting Power contract.
    function run() public {
        // Deployer's private key. Owner of the L2 Voting Power. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2 Voting Power...");

        // get L2LockingPosition contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        assert(l2AddressesConfig.L2LockingPosition != address(0));
        console2.log("L2 Locking Position address: %s", l2AddressesConfig.L2LockingPosition);
        IL2LockingPosition lockingPositionContract = IL2LockingPosition(l2AddressesConfig.L2LockingPosition);

        // Get L2VotingPower contract owner address. Ownership is transferred to this address after deployment.
        address ownerAddress = vm.envAddress("L2_VOTING_POWER_OWNER_ADDRESS");
        console2.log("L2 Voting Power owner address: %s (after ownership will be accepted)", ownerAddress);

        // deploy L2VotingPower implementation contract
        vm.startBroadcast(deployerPrivateKey);
        L2VotingPower l2VotingPowerImplementation = new L2VotingPower();
        vm.stopBroadcast();
        assert(address(l2VotingPowerImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2VotingPowerImplementation.proxiableUUID()
                == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        // deploy L2VotingPower proxy contract and at the same time initialize the proxy contract (calls the
        // initialize function in L2VotingPower)
        vm.startBroadcast(deployerPrivateKey);
        ERC1967Proxy l2VotingPowerProxy = new ERC1967Proxy(
            address(l2VotingPowerImplementation),
            abi.encodeWithSelector(l2VotingPowerImplementation.initialize.selector, lockingPositionContract)
        );
        vm.stopBroadcast();
        assert(address(l2VotingPowerProxy) != address(0));

        // wrap in ABI to support easier calls
        L2VotingPower l2VotingPower = L2VotingPower(payable(address(l2VotingPowerProxy)));
        assert(keccak256(bytes(l2VotingPower.name())) == keccak256(bytes("Lisk Voting Power")));
        assert(keccak256(bytes(l2VotingPower.symbol())) == keccak256(bytes("vpLSK")));
        assert(keccak256(bytes(l2VotingPower.version())) == keccak256(bytes("1.0.0")));
        assert(l2VotingPower.owner() == vm.addr(deployerPrivateKey));

        // initialize the Voting Power contract by calling initializeVotingPower of the Locking Position contract
        vm.startBroadcast(deployerPrivateKey);
        lockingPositionContract.initializeVotingPower(address(l2VotingPower));
        vm.stopBroadcast();
        assert(lockingPositionContract.votingPowerContract() == address(l2VotingPower));

        // transfer ownership of the L2VotingPower contract to the owner address; because of using
        // Ownable2StepUpgradeable contract, new owner has to accept ownership
        vm.startBroadcast(deployerPrivateKey);
        l2VotingPower.transferOwnership(ownerAddress);
        vm.stopBroadcast();
        assert(l2VotingPower.owner() == vm.addr(deployerPrivateKey)); // ownership is not yet accepted

        console2.log("L2 Voting Power (implementation) address: %s", address(l2VotingPowerImplementation));
        console2.log("L2 Voting Power (proxy) address: %s", address(l2VotingPower));
        console2.log("L2 Voting Power owner address: %s (after ownership will be accepted)", ownerAddress);

        // write L2 Voting Power address to l2addresses.json
        l2AddressesConfig.L2VotingPowerImplementation = address(l2VotingPowerImplementation);
        l2AddressesConfig.L2VotingPower = address(l2VotingPower);
        utils.writeL2AddressesFile(l2AddressesConfig);
    }
}
