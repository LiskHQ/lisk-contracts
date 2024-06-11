// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { L2Reward } from "src/L2/L2Reward.sol";

/// @title L2RewardPaused - Paused version of L2Reward contract
/// @notice This contract is used to pause the L2Reward contract. In case of any emergency, the owner can upgrade and
///         pause the contract to prevent any further staking operations.
contract L2RewardPaused is L2Reward {
    /// @notice Setting global params.
    function initializePaused() public reinitializer(2) {
        version = "1.0.0-paused";
    }

    /// @notice Override the claimRewards function to prevent staking from being processed.
    function claimRewards(uint256[] memory) public virtual override {
        revert("L2RewardPaused: Staking is paused");
    }
}
