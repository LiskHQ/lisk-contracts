// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import "script/Utils.sol";

/// @title IL2Staking
/// @notice Interface for L2 Staking contract. Used to transfer ownership of the L2 Staking contract.
interface IL2Staking {
    function transferOwnership(address newOwner) external;
    function owner() external view returns (address);
}

/// @title IL2LockingPosition
/// @notice Interface for L2 LockingPosition contract. Used to transfer ownership of the L2 LockingPosition contract.
interface IL2LockingPosition {
    function transferOwnership(address newOwner) external;
    function owner() external view returns (address);
}

/// @title TransferStakingOwnershipScript
/// @notice This contract is used to transfer ownership of the L2 staking contracts (Staking and LockingPosition) to
///         different addresses.
contract TransferStakingOwnershipScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function transfers ownership of the L2 Staking and LockingPosition contracts to a different
    /// address.
    /// @dev This function first reads the L2 addresses from the JSON file and then transfers ownership of the L2
    /// Staking and LockingPosition contracts to a different address.
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Transferring ownership of the L2 Staking and LockingPosition contracts...");

        // get L2Staking contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        console2.log("L2 Staking address: %s", l2AddressesConfig.L2Staking);
        IL2Staking l2Staking = IL2Staking(l2AddressesConfig.L2Staking);

        // get L2LockingPosition contract address
        console2.log("L2 LockingPosition address: %s", l2AddressesConfig.L2LockingPosition);
        IL2Staking l2LockingPosition = IL2Staking(l2AddressesConfig.L2LockingPosition);

        // Get L2Staking contract new owner address. Ownership is transferred to this address.
        address newStakingOwnerAddress = vm.envAddress("L2_STAKING_OWNER_ADDRESS");
        assert(newStakingOwnerAddress != address(0));
        console2.log("L2 Staking future owner address: %s (after ownership will be accepted)", newStakingOwnerAddress);

        // Get L2LockingPosition contract new owner address. Ownership is transferred to this address.
        address newLockingPositionOwnerAddress = vm.envAddress("L2_LOCKING_POSITION_OWNER_ADDRESS");
        assert(newLockingPositionOwnerAddress != address(0));
        console2.log(
            "L2 Locking Position future owner address: %s (after ownership will be accepted))",
            newLockingPositionOwnerAddress
        );

        // transfer ownership of the L2 Staking contract; because of using Ownable2StepUpgradeable contract, new owner
        // has to accept ownership
        vm.startBroadcast(deployerPrivateKey);
        l2Staking.transferOwnership(newStakingOwnerAddress);
        vm.stopBroadcast();
        assert(l2Staking.owner() == vm.addr(deployerPrivateKey)); // ownership is not yet accepted

        // transfer ownership of the L2 LockingPosition contract; because of using Ownable2StepUpgradeable contract, new
        // owner has to accept ownership
        vm.startBroadcast(deployerPrivateKey);
        l2LockingPosition.transferOwnership(newLockingPositionOwnerAddress);
        vm.stopBroadcast();
        assert(l2LockingPosition.owner() == vm.addr(deployerPrivateKey)); // ownership is not yet accepted

        console2.log("L2 Staking owner address: %s (after ownership will be accepted)", newStakingOwnerAddress);
        console2.log(
            "L2 L2LockingPosition owner address: %s (after ownership will be accepted)", newLockingPositionOwnerAddress
        );

        console2.log("Ownership of the L2 Staking and LockingPosition contracts successfully transferred!");
    }
}
