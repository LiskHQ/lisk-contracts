// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { L2VestingWalletEmergencyWithdraw } from "src/L2/paused/L2VestingWalletEmergencyWithdraw.sol";

/// @title L1VestingWalletEmergencyWithdraw - Paused version of L1VestingWallet contract
/// @notice This contract is used to pause the L1VestingWallet contract. In case of any emergency, the owner can upgrade
/// and
///         pause the contract to prevent any further vesting operations.
///         L1VestingWalletEmergencyWithdraw shares the same functionality of L2VestingWalletEmergencyWithdraw.
contract L1VestingWalletEmergencyWithdraw is L2VestingWalletEmergencyWithdraw { }
