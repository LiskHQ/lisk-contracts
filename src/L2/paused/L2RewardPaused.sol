// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { L2Reward } from "src/L2/L2Reward.sol";

/// @title L2RewardPaused - Paused version of L2Reward contract
/// @notice This contract is used to pause the L2Reward contract. In case of any emergency, the owner can upgrade and
///         pause the contract to prevent any further staking operations.
contract L2RewardPaused is L2Reward {
    error RewardIsPaused();

    /// @notice Setting global params.
    function initializePaused() public reinitializer(2) {
        version = "1.0.0-paused";
    }

    /// @notice Override the claimRewards function to prevent staking from being processed.
    function claimRewards(uint256[] memory) public virtual override {
        revert RewardIsPaused();
    }

    /// @notice Override the createPosition function to prevent staking from being processed.
    function createPosition(uint256, uint256) public virtual override returns (uint256) {
        revert RewardIsPaused();
    }

    /// @notice Override the deletePositions function to prevent staking from being processed.
    function deletePositions(uint256[] memory) public virtual override {
        revert RewardIsPaused();
    }

    /// @notice Override the initiateFastUnlock function to prevent staking from being processed.
    function initiateFastUnlock(uint256[] memory) public virtual override {
        revert RewardIsPaused();
    }

    /// @notice Override the increaseLockingAmount function to prevent staking from being processed.
    function increaseLockingAmount(IncreasedAmount[] memory) public virtual override {
        revert RewardIsPaused();
    }

    /// @notice Override the extendLockingDuration function to prevent staking from being processed.
    function extendDuration(ExtendedDuration[] memory) public virtual override {
        revert RewardIsPaused();
    }

    /// @notice Override the pauseUnlocking function to prevent staking from being processed.
    function pauseUnlocking(uint256[] memory) public virtual override {
        revert RewardIsPaused();
    }

    /// @notice Override the resumeUnlockingCountdown function to prevent staking from being processed.
    function resumeUnlockingCountdown(uint256[] memory) public virtual override {
        revert RewardIsPaused();
    }
}
