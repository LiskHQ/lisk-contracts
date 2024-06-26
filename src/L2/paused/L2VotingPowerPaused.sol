// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { L2VotingPower } from "../L2VotingPower.sol";

contract L2VotingPowerPaused is L2VotingPower {
    error VotingPowerIsPaused();

    /// @notice Setting global params.
    function initializePaused() public reinitializer(2) {
        version = "1.0.0-paused";
    }

    /// @notice Override the modifyLockingPosition function to pause VotingPower interactions.
    function delegate(address) public virtual override {
        revert VotingPowerIsPaused();
    }

    /// @notice Override the modifyLockingPosition function to pause VotingPower interactions.
    function delegateBySig(address, uint256, uint256, uint8, bytes32, bytes32) public virtual override {
        revert VotingPowerIsPaused();
    }
}
