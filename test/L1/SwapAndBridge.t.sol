// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2, Vm } from "forge-std/Test.sol";
import { SwapAndBridge } from "src/L1/SwapAndBridge.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20LST } from "../../test/mock/MockERC20LST.sol";
import { MockStandardBridge } from "../../test/mock/MockStandardBridge.sol";

/// @title TestSwapAndBridge
/// @notice This contract is used to run unit tests for the SwapAndBridge contract.
contract TestSwapAndBridge is Test {
    // Address used for unit tests
    address constant testAccount = address(0xc0ffee);

    function setUp() public {
        vm.deal(testAccount, 500000 ether);
    }

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

    function test_ReceiveFallback() public {
        MockERC20LST mockLST = new MockERC20LST(1e18);
        MockStandardBridge bridge = new MockStandardBridge();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridge), address(mockLST), address(0xbeef));

        vm.startPrank(testAccount);
        (bool sent,) = address(swapAndBridge).call{ value: 1 ether }("");
        require(sent == true, "Failed to send Ether.");
        vm.stopPrank();
    }

    function test_SwapAndBridgeTo() public {
        MockERC20LST mockLST = new MockERC20LST(1e18);
        MockStandardBridge bridge = new MockStandardBridge();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridge), address(mockLST), address(0xbeef));

        vm.startPrank(testAccount);
        swapAndBridge.swapAndBridgeTo{ value: 1 ether }(testAccount);
        vm.stopPrank();
    }

    function test_SwapAndBridgeToWithMinimumAmount() public {
        uint256 conversionRate = 1e18;
        uint256 value = 1 ether;
        uint256 expectedMinAmount = conversionRate * value / 1e18;

        MockERC20LST mockLST = new MockERC20LST(conversionRate);
        MockStandardBridge bridge = new MockStandardBridge();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridge), address(mockLST), address(0xbeef));

        vm.startPrank(testAccount);
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: value }(testAccount, 0);
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: value }(testAccount, expectedMinAmount - 1);
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: value }(testAccount, expectedMinAmount);
        vm.stopPrank();
    }

    function test_InsufficientTokensMinted() public {
        uint256 conversionRate = 1e18;
        uint256 value = 1 ether;
        uint256 expectedMinAmount = conversionRate * value / 1e18;

        MockERC20LST mockLST = new MockERC20LST(conversionRate);
        MockStandardBridge bridge = new MockStandardBridge();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridge), address(mockLST), address(0xbeef));

        vm.startPrank(testAccount);
        vm.expectRevert("Insufficient L1 tokens minted.");
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: value }(testAccount, expectedMinAmount + 1);
        vm.stopPrank();
    }

    function test_TokensMintedOverflow() public {
        uint256 conversionRate = 1e18;

        MockERC20LST mockLST = new MockERC20LST(conversionRate);
        MockStandardBridge bridge = new MockStandardBridge();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridge), address(mockLST), address(0xbeef));

        vm.startPrank(testAccount);
        vm.expectRevert(); // Panic due to overflow.
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: 10000 ether }(testAccount, 1e75);
        vm.stopPrank();
    }

    function test_NoTokensMinted() public {
        MockERC20LST mockLST = new MockERC20LST(0);
        MockStandardBridge bridge = new MockStandardBridge();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridge), address(mockLST), address(0xbeef));

        vm.startPrank(testAccount);
        vm.expectRevert("No wrapped tokens minted.");
        swapAndBridge.swapAndBridgeTo{ value: 1 ether }(testAccount);
        vm.stopPrank();
    }
}
