// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { L2LockingPosition } from "src/L2/L2LockingPosition.sol";

/// @title L2LockingPositionPaused - Paused version of L2LockingPosition contract
/// @notice This contract is used to pause the L2LockingPosition contract. In case of any emergency, the owner can
///         upgrade and pause the contract to prevent any further staking operations.
contract L2LockingPositionPaused is L2LockingPosition {
    error LockingPositionIsPaused();

    /// @notice Setting global params.
    function initializePaused() public reinitializer(2) { }

    /// @notice Override the transferFrom function to prevent staking from being processed.
    function transferFrom(address, address, uint256) public virtual override {
        revert LockingPositionIsPaused();
    }

    /// @notice Override the createLockingPosition function to prevent staking from being processed.
    function createLockingPosition(
        address,
        address,
        uint256,
        uint256
    )
        external
        virtual
        override
        onlyStaking
        returns (uint256)
    {
        revert LockingPositionIsPaused();
    }

    /// @notice Override the modifyLockingPosition function to prevent staking from being processed.
    function modifyLockingPosition(uint256, uint256, uint256, uint256) external virtual override onlyStaking {
        revert LockingPositionIsPaused();
    }

    /// @notice Override the removeLockingPosition function to prevent staking from being processed.
    function removeLockingPosition(uint256) external virtual override onlyStaking {
        revert LockingPositionIsPaused();
    }
}
