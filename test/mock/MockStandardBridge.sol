// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title MockStandardBridge
/// @notice MockStandardBridge is a mock implementation of the Optimism standard bridge.
contract MockStandardBridge {
    using SafeERC20 for IERC20;

    /// @notice Mock the standard bridge depositERC20To function.
    function depositERC20To(address _l1Token, address, address, uint256 _amount, uint32, bytes calldata) public {
        IERC20(_l1Token).safeTransferFrom(msg.sender, address(this), _amount);
    }
}
