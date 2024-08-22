// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { L2VestingWallet } from "src/L2/L2VestingWallet.sol";

/// @title L2VestingWalletEmergencyWithdraw - L2VestingWallet contract with Emergency Withdraw
/// @notice This is a contingency contract of L2VestingWallet. In case of any emergency, the owner can upgrade
///         and withdraw all tokens from the contract.
contract L2VestingWalletEmergencyWithdraw is L2VestingWallet {
    /// @notice Setting global params.
    function initializeWithEmergencyWithdraw(IERC20[] memory _token) public reinitializer(2) {
        version = "1.0.0-emergency-withdraw";

        for (uint256 i; i < _token.length; i++) {
            IERC20 token = _token[i];
            token.transfer(getRoleMember(CONTRACT_ADMIN_ROLE, 0), token.balanceOf(address(this)));
        }
    }
}
