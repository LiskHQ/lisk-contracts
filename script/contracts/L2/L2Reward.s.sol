// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2Reward } from "src/L2/L2Reward.sol";
import { IL2LiskToken } from "src/interfaces/L2/IL2LiskToken.sol";
import { IL2Staking } from "src/interfaces/L2/IL2Staking.sol";
import "script/contracts/Utils.sol";

/// @title L2RewardScript - L2 Reward contract deployment script.
/// @notice This contract is used to deploy L2 Reward contract.
contract L2RewardScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2 Reward contract.
    function run() public {
        // Deployer's private key. Owner of the L2 Reward. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2 Reward...");

        // get L2LiskToken contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile(utils.getL2AddressesFilePath());
        assert(l2AddressesConfig.L2LiskToken != address(0));
        console2.log("L2 Lisk Token address: %s", l2AddressesConfig.L2LiskToken);

        // get L2Reward contract owner address. Ownership is transferred to this address after deployment.
        address ownerAddress = vm.envAddress("L2_REWARD_OWNER_ADDRESS");
        assert(ownerAddress != address(0));
        console2.log("L2 Reward owner address: %s (after ownership will be accepted)", ownerAddress);

        // deploy L2Reward implementation contract
        vm.startBroadcast(deployerPrivateKey);
        L2Reward l2RewardImplementation = new L2Reward();
        vm.stopBroadcast();
        assert(address(l2RewardImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2RewardImplementation.proxiableUUID() == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        // deploy L2Reward proxy contract and at the same time initialize the proxy contract (calls the
        // initialize function in L2Reward)
        vm.startBroadcast(deployerPrivateKey);
        ERC1967Proxy l2RewardProxy = new ERC1967Proxy(
            address(l2RewardImplementation),
            abi.encodeWithSelector(l2RewardImplementation.initialize.selector, l2AddressesConfig.L2LiskToken)
        );
        vm.stopBroadcast();
        assert(address(l2RewardProxy) != address(0));

        // wrap in ABI to support easier calls
        L2Reward l2Reward = L2Reward(payable(address(l2RewardProxy)));
        assert(keccak256(bytes(l2Reward.version())) == keccak256(bytes("1.0.0")));
        assert(l2Reward.owner() == vm.addr(deployerPrivateKey));
        assert(l2Reward.l2TokenContract() == l2AddressesConfig.L2LiskToken);

        vm.startBroadcast(deployerPrivateKey);
        // reward contract is added as a creator at staking contract
        IL2Staking(l2AddressesConfig.L2Staking).addCreator(address(l2Reward));
        vm.stopBroadcast();

        assert(l2AddressesConfig.L2LockingPosition != address(0));
        assert(l2AddressesConfig.L2Staking != address(0));
        vm.startBroadcast(deployerPrivateKey);
        // reward contract initializes locking position and staking contracts
        l2Reward.initializeLockingPosition(l2AddressesConfig.L2LockingPosition);
        l2Reward.initializeStaking(l2AddressesConfig.L2Staking);

        // transfer ownership of the L2VotingPower contract to the owner address; because of using
        // Ownable2StepUpgradeable contract, new owner has to accept ownership
        l2Reward.transferOwnership(ownerAddress);
        vm.stopBroadcast();

        assert(l2Reward.owner() == vm.addr(deployerPrivateKey)); // ownership is not yet accepted
        assert(l2Reward.lockingPositionContract() == l2AddressesConfig.L2LockingPosition);
        assert(l2Reward.stakingContract() == l2AddressesConfig.L2Staking);

        console2.log("L2 Reward (implementation) address: %s", address(l2RewardImplementation));
        console2.log("L2 Reward (proxy) address: %s", address(l2Reward));
        console2.log("L2 Reward owner address: %s (after ownership will be accepted)", ownerAddress);

        // write L2 Reward address to l2addresses.json
        l2AddressesConfig.L2RewardImplementation = address(l2RewardImplementation);
        l2AddressesConfig.L2Reward = address(l2Reward);
        utils.writeL2AddressesFile(l2AddressesConfig, utils.getL2AddressesFilePath());
    }
}
