// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { L2VestingWalletPaused } from "src/L2/paused/L2VestingWalletPaused.sol";

/// @title L1VestingWalletPaused - Paused version of L1VestingWallet contract
/// @notice This contract is used to pause the L1VestingWallet contract. In case of any emergency, the owner can upgrade
/// and
///         pause the contract to prevent any further vesting operations.
///         L1VestingWalletPaused shares the same functionality of L1VestingWalletPaused.
contract L1VestingWalletPaused is L2VestingWalletPaused { }
