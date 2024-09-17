// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2, Vm } from "forge-std/Test.sol";
import { SwapAndBridge } from "src/L1/SwapAndBridge.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20LST } from "../../test/mock/MockERC20LST.sol";
import { MockERC20LSTBuggyApprove } from "../../test/mock/MockERC20LSTBuggyApprove.sol";
import { MockStandardBridge } from "../../test/mock/MockStandardBridge.sol";
import { MockStandardBridgeBuggyDeposit } from "../../test/mock/MockStandardBridgeBuggyDeposit.sol";

/// @title TestSwapAndBridge
/// @notice This contract is used to run unit tests for the SwapAndBridge contract.
contract TestSwapAndBridge is Test {
    // Address used for unit tests
    address constant testAccount = address(0xc0ffee);

    // test account balance
    uint256 testBalance = 1e60;

    function setUp() public {
        vm.deal(testAccount, testBalance);
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

        uint256 senderBalance = testAccount.balance;
        vm.expectRevert("Invalid recipient address.");
        swapAndBridge.swapAndBridgeTo{ value: 1 }(address(0));
        require(senderBalance == testAccount.balance, "Sender balance should not have changed.");
    }

    function testFuzz_ReceiveFallback(uint256 tokensPerETH, uint256 value) public {
        // We bound tokensPerETH in fuzzzing to avoid overflows in the MockERC20LST contract
        // and 'No wrapped tokens minted.' and 'Invalid msg value' reverts.
        vm.assume(tokensPerETH > 0);
        vm.assume(tokensPerETH <= 1e38);
        vm.assume(value > 0);
        vm.assume(value <= 1e38);
        // Ensure that some tokens will be minted in the MockERC20LST contract,
        // since the amount is calculated as msg.value * tokensPerETH / 1e18.
        vm.assume(tokensPerETH * value >= 1e18);

        MockERC20LST mockLST = new MockERC20LST(tokensPerETH);
        MockStandardBridge bridge = new MockStandardBridge();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridge), address(mockLST), address(0xbeef));

        uint256 senderBalance = testAccount.balance;
        vm.startPrank(testAccount);
        (bool sent,) = address(swapAndBridge).call{ value: value }("");
        require(sent == true, "Failed to send Ether.");
        vm.stopPrank();
        require(senderBalance == testAccount.balance + value, "Invalid sender balance update.");
    }

    function testFuzz_SwapAndBridgeTo(uint256 tokensPerETH, uint256 value, address recipient) public {
        // We bound tokensPerETH in fuzzzing to avoid overflows in the MockERC20LST contract
        // and 'No wrapped tokens minted.' and 'Invalid msg value' reverts.
        vm.assume(tokensPerETH > 0);
        vm.assume(tokensPerETH <= 1e38);
        vm.assume(value > 0);
        vm.assume(value <= 1e38);
        // Ensure that some tokens will be minted in the MockERC20LST contract,
        // since the amount is calculated as msg.value * tokensPerETH / 1e18.
        vm.assume(tokensPerETH * value >= 1e18);

        MockERC20LST mockLST = new MockERC20LST(tokensPerETH);
        MockStandardBridge bridge = new MockStandardBridge();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridge), address(mockLST), address(0xbeef));

        uint256 senderBalance = testAccount.balance;
        vm.startPrank(testAccount);
        if (recipient != address(0)) {
            swapAndBridge.swapAndBridgeTo{ value: value }(recipient);
            require(senderBalance == testAccount.balance + value, "Invalid sender balance update.");
        }
        vm.stopPrank();
    }

    function testFuzz_SwapAndBridgeToWithMinimumAmount(uint256 tokensPerETH, uint256 value) public {
        // We bound tokensPerETH in fuzzzing to avoid overflows in the MockERC20LST contract
        // and 'No wrapped tokens minted.' and 'Invalid msg value' reverts.
        vm.assume(tokensPerETH > 0);
        vm.assume(tokensPerETH <= 1e38);
        vm.assume(value > 0);
        vm.assume(value <= 1e38);
        // Ensure that some tokens will be minted in the MockERC20LST contract,
        // since the amount is calculated as msg.value * tokensPerETH / 1e18.
        vm.assume(tokensPerETH * value >= 1e18);

        MockERC20LST mockLST = new MockERC20LST(tokensPerETH);
        MockStandardBridge bridge = new MockStandardBridge();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridge), address(mockLST), address(0xbeef));

        uint256 expectedAmount = value * tokensPerETH / 1e18;

        uint256 senderBalance = testAccount.balance;
        vm.startPrank(testAccount);
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: value }(testAccount, expectedAmount - 1);
        vm.stopPrank();
        require(senderBalance == testAccount.balance + value, "Invalid sender balance update.");

        senderBalance = testAccount.balance;
        vm.startPrank(testAccount);
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: value }(testAccount, expectedAmount);
        vm.stopPrank();
        require(senderBalance == testAccount.balance + value, "Invalid sender balance update.");
    }

    function testFuzz_InsufficientTokensMinted(uint256 tokensPerETH, uint256 value) public {
        // We bound tokensPerETH in fuzzzing to avoid overflows in the MockERC20LST contract.
        vm.assume(tokensPerETH <= 1e38);
        vm.assume(value > 0);
        vm.assume(value <= 1e38);
        // Ensure that some tokens will be minted in the MockERC20LST contract,
        // since the amount is calculated as msg.value * tokensPerETH / 1e18.
        vm.assume(tokensPerETH * value >= 1e18);

        MockERC20LST mockLST = new MockERC20LST(tokensPerETH);
        MockStandardBridge bridge = new MockStandardBridge();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridge), address(mockLST), address(0xbeef));

        // Expected amount minted from the MockERC20LST contract.
        uint256 expectedAmount = value * tokensPerETH / 1e18;
        uint256 senderBalance = testAccount.balance;

        vm.startPrank(testAccount);
        vm.expectRevert("Insufficient L1 tokens minted.");
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: value }(testAccount, expectedAmount + 1);
        vm.stopPrank();

        require(senderBalance == testAccount.balance, "Sender balance should not have changed.");
    }

    function testFuzz_TokensMintedOverflow(uint256 value, uint256 tokensPerETH) public {
        // Guaranteee overflow in MockERC20LST contract.
        vm.assume(value > 1e40);
        vm.assume(tokensPerETH > 1e40);
        vm.assume(value <= testBalance);

        MockERC20LST mockLST = new MockERC20LST(tokensPerETH);
        MockStandardBridge bridge = new MockStandardBridge();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridge), address(mockLST), address(0xbeef));

        uint256 senderBalance = testAccount.balance;
        vm.startPrank(testAccount);
        vm.expectRevert(); // overflow panic.
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: value }(testAccount, tokensPerETH);
        vm.stopPrank();
        require(senderBalance == testAccount.balance, "Sender balance should not have changed.");
    }

    function testFuzz_InvalidMsgValue(uint256 tokensPerETH, uint256 minL1Tokens) public {
        MockERC20LST mockLST = new MockERC20LST(tokensPerETH);
        MockStandardBridge bridge = new MockStandardBridge();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridge), address(mockLST), address(0xbeef));

        uint256 senderBalance = testAccount.balance;
        vm.startPrank(testAccount);
        vm.expectRevert("Invalid msg value.");
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: 0 }(testAccount, minL1Tokens);
        vm.stopPrank();
        require(senderBalance == testAccount.balance, "Sender balance should not have changed.");
    }

    function testFuzz_NoTokensMinted(uint256 value, uint256 tokensPerETH) public {
        // We bound tokensPerETH in fuzzzing to avoid overflows in the MockERC20LST contract.
        vm.assume(tokensPerETH <= 1e38);
        vm.assume(value > 0);
        vm.assume(value <= 1e38);
        // Ensure that no tokens will be minted in the MockERC20LST contract,
        // since the amount is calculated as msg.value * tokensPerETH / 1e18.
        vm.assume(tokensPerETH * value < 1e18);

        MockERC20LST mockLST = new MockERC20LST(tokensPerETH);
        MockStandardBridge bridge = new MockStandardBridge();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridge), address(mockLST), address(0xbeef));

        uint256 senderBalance = testAccount.balance;
        vm.startPrank(testAccount);
        vm.expectRevert("No wrapped tokens minted.");
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: value }(testAccount, 0);
        vm.expectRevert("No wrapped tokens minted.");
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: value }(testAccount, 1e18);
        vm.stopPrank();
        require(senderBalance == testAccount.balance, "Sender balance should not have changed.");
    }

    function testFuzz_NoApproval(uint256 value, uint256 tokensPerETH) public {
        // We bound tokensPerETH in fuzzzing to avoid overflows in the MockERC20LST contract.
        vm.assume(tokensPerETH <= 1e38);
        vm.assume(value > 0);
        vm.assume(value <= 1e38);
        // Ensure that some tokens will be minted in the MockERC20LST contract,
        // since the amount is calculated as msg.value * tokensPerETH / 1e18.
        vm.assume(tokensPerETH * value >= 1e18);

        MockERC20LSTBuggyApprove mockLSTBuggyApprove = new MockERC20LSTBuggyApprove(tokensPerETH);
        MockStandardBridge bridge = new MockStandardBridge();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridge), address(mockLSTBuggyApprove), address(0xbeef));

        uint256 senderBalance = testAccount.balance;
        vm.startPrank(testAccount);
        vm.expectRevert("Failed to approve L1 token spender.");
        (bool sent,) = address(swapAndBridge).call{ value: value }("");
        vm.stopPrank();
        require(sent == true, "Failed to send Ether.");
        require(senderBalance == testAccount.balance, "Sender balance should not have changed.");
    }

    function testFuzz_StillHasTokens(uint256 value, uint256 tokensPerETH) public {
        // We bound tokensPerETH in fuzzzing to avoid overflows in the MockERC20LST contract.
        vm.assume(tokensPerETH <= 1e38);
        vm.assume(value > 0);
        vm.assume(value <= 1e38);

        // Ensure that some tokens will be minted in the MockERC20LST contract,
        // since the amount is calculated as msg.value * tokensPerETH / 1e18.
        vm.assume(tokensPerETH * value >= 1e18);

        MockERC20LST mockLST = new MockERC20LST(tokensPerETH);
        MockStandardBridgeBuggyDeposit bridgeBuggyDeposit = new MockStandardBridgeBuggyDeposit();
        SwapAndBridge swapAndBridge = new SwapAndBridge(address(bridgeBuggyDeposit), address(mockLST), address(0xbeef));

        uint256 senderBalance = testAccount.balance;
        vm.startPrank(testAccount);
        vm.expectRevert("Contract still has tokens.");
        (bool sent,) = address(swapAndBridge).call{ value: value }("");
        vm.stopPrank();
        require(sent == true, "Failed to send Ether.");
        require(senderBalance == testAccount.balance, "Sender balance should not have changed.");
    }
}
