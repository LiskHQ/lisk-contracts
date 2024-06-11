// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { L2Staking } from "src/L2/L2Staking.sol";

/// @title L2StakingPaused - Paused version of L2Staking contract
/// @notice This contract is used to pause the L2Staking contract. In case of any emergency, the owner can upgrade and
///         pause the contract to prevent any further staking operations.
contract L2StakingPaused is L2Staking {
    /// @notice Setting global params.
    function initializePaused() public reinitializer(2) {
        version = "1.0.0-paused";
    }
}
