// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { IL2LockingPosition } from "../../interfaces/L2/IL2LockingPosition.sol";
import { L2VotingPower } from "../L2VotingPower.sol";

contract L2VotingPowerPaused is L2VotingPower {
    /// @notice Setting global params.
    function initializePaused() public reinitializer(2) {
        version = "1.0.0-paused";
    }

    /// @notice Override the modifyLockingPosition function to pause VotingPower interactions.
    function adjustVotingPower(
        address,
        IL2LockingPosition.LockingPosition memory,
        IL2LockingPosition.LockingPosition memory
    )
        public
        virtual
        override
    {
        revert("L2VotingPowerPaused: VotingPower is paused");
    }

    /// @notice Override the modifyLockingPosition function to pause VotingPower interactions.
    function delegate(address) public virtual override {
        revert("L2VotingPowerPaused: VotingPower is paused");
    }

    /// @notice Override the modifyLockingPosition function to pause VotingPower interactions.
    function delegateBySig(address, uint256, uint256, uint8, bytes32, bytes32) public virtual override {
        revert("L2VotingPowerPaused: VotingPower is paused");
    }
}
