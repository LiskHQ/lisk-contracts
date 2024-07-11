// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { L2VestingWallet } from "src/L2/L2VestingWallet.sol";

/// @title L2VestingWalletPaused - Paused version of L2VestingWallet contract
/// @notice This contract is used to pause the L2VestingWallet contract. In case of any emergency, the owner can upgrade
/// and
///         pause the contract to prevent any further vesting operations.
contract L2VestingWalletPaused is L2VestingWallet {
    error VestingWalletIsPaused();

    /// @notice Setting global params.
    function initializePaused() public reinitializer(2) {
        version = "1.0.0-paused";
    }

    /// @notice Override the release function to prevent release of token from being processed.
    function release(address) public virtual override {
        revert VestingWalletIsPaused();
    }

    /// @notice Override the release function to prevent release of token from being processed.
    function release() public virtual override {
        revert VestingWalletIsPaused();
    }

    /// @notice Override the acceptOwnership function to prevent change of ownership from being processed.
    function acceptOwnership() public virtual override {
        revert VestingWalletIsPaused();
    }

    /// @notice Override the acceptOwnership function to prevent change of ownership from being processed.
    function transferOwnership(address) public virtual override {
        revert VestingWalletIsPaused();
    }

    /// @notice Override the acceptOwnership function to prevent change of ownership from being processed.
    function renounceOwnership() public virtual override {
        revert VestingWalletIsPaused();
    }
}
