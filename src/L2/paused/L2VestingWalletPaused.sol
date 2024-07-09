// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import "src/L2/L2VestingWallet.sol";

contract L2VestingWalletPaused is L2VestingWallet {
    error VestingWalletIsPaused();

    /// @notice Setting global params.
    function initializePaused() public reinitializer(2) {
        version = "1.0.0-paused";
    }

    function release(address) public virtual override {
        revert VestingWalletIsPaused();
    }

    function release() public virtual override {
        revert VestingWalletIsPaused();
    }

    function acceptOwnership() public virtual override {
        revert VestingWalletIsPaused();
    }

    function transferOwnership(address) public virtual override {
        revert VestingWalletIsPaused();
    }

    function renounceOwnership() public virtual override {
        revert VestingWalletIsPaused();
    }
}
