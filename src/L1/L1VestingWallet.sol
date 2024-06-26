// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { L2VestingWallet } from "../L2/L2VestingWallet.sol";

/// @title L1VestingWallet
/// @notice This contract handles the Vesting functionality of LSK Token for the Ethereum network.
/// @dev Since L2VestingWallet has been audited, L1VestingWallet directly inherits from L2VestingWallet to ensure safety
///      of funds.
contract L1VestingWallet is L2VestingWallet { }
