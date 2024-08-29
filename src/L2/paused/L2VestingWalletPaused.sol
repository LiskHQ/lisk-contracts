// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { L2VestingWallet } from "src/L2/L2VestingWallet.sol";

/// @title L2VestingWalletPaused - Paused version of L2VestingWallet contract
/// @notice This contract is used to pause the L2VestingWallet contract. In case of any emergency, the owner can upgrade
///         and pause the contract to prevent any further vesting operations.
contract L2VestingWalletPaused is L2VestingWallet {
    using SafeERC20 for IERC20;

    error VestingWalletIsPaused();

    /// @notice Setting global params.
    function initializePaused() public reinitializer(2) {
        version = "1.0.1-paused";
    }

    /// @notice Hard-coded address to recover tokens.
    function custodianAddress() public pure virtual returns (address) {
        return 0x394Ae9d48eeca1C69a989B5A8C787081595c55A7;
    }

    /// @notice Withdraw all balances of token to recoveryAddress.
    function sendToCustodian(IERC20 _token) public virtual onlyRole(CONTRACT_ADMIN_ROLE) {
        _token.safeTransfer(custodianAddress(), _token.balanceOf(address(this)));
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
