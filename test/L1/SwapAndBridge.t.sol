// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2, Vm } from "forge-std/Test.sol";
import { SwapAndBridge } from "src/L1/SwapAndBridge.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// event SentMessage(address indexed target, address sender, bytes message, uint256 messageNonce, uint256 gasLimit);
event SentMessage(address indexed target, bytes data);

/// @title TestBridgingScript
/// @notice This contract is used to test bridging Lido tokens from L1 to L2 network.
contract TestBSwapAndBridge is Test {
    function test_InvalidConstructor() public {
        vm.expectRevert("Invalid L1 bridge address.");
        new SwapAndBridge(address(0), address(0xdead), address(0xbeef));

        vm.expectRevert("Invalid L1 token address.");
        new SwapAndBridge(address(0xbeef), address(0), address(0xdead));

        vm.expectRevert("Invalid L2 token address.");
        new SwapAndBridge(address(0xbeef), address(0xdead), address(0));
    }

    function test_InvalidRecipient() public {
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(0xdead), address(0xbeef), address(0x1111));
        vm.expectRevert("Invalid recipient address.");
        swapAndBridge.swapAndBridgeTo(address(0));
    }
}
