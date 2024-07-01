// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { SwapAndBridge } from "src/L1/SwapAndBridge.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IWrappedETH - Wrapped Ether Token interface
/// @notice This contract is used to wrap the a LST.
interface IWrappedETH is IERC20 {
    receive() external payable;
}

/// @title TestIntegrationScript
/// @notice This contract is used to run integration test for the SwapAndBridge contract.
contract TestIntegrationScript is Script {
    // SwapAndBridge contract
    SwapAndBridge swapAndBridge;

    // The L1 LST token
    IWrappedETH l1LSTToken;

    // Address used for E2E tests
    address constant testAccount = address(0xc0ffee);

    function setUp() public {
        vm.deal(testAccount, 500000 ether);
    }

    function runMinToken() public {
        console2.log("Testing minL1TokensPerETH...");
        // The conversion rate is 1 ETH = 1e18 LST.
        // Any value of minL1TokensPerETH larger than 1e18 will revert the transaction.
        vm.startPrank(testAccount);

        console2.log("Testing no minimum...");
        uint256 senderBalance = testAccount.balance;
        uint256 value = 1 ether;
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: value }(testAccount, 0);
        require(senderBalance == testAccount.balance + value, "Invalid sender balance update.");
        console2.log("Ok");

        console2.log("Testing 'Insufficient L1 tokens minted'...");
        senderBalance = testAccount.balance;
        vm.expectRevert("Insufficient L1 tokens minted.");
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(testAccount, 1e18 + 1);
        require(senderBalance == testAccount.balance, "Sender balance should not have changed.");
        console2.log("Ok");

        console2.log("Testing 'EvmError: OutOfFunds'...");
        senderBalance = testAccount.balance;
        uint256 MAX_INT = 2 ** 256 - 1;
        vm.expectRevert(); // Panic due to EvmError: OutOfFunds.
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: MAX_INT }(testAccount, 0);
        require(senderBalance == testAccount.balance, "Sender balance should not have changed.");
        console2.log("Ok");

        console2.log("Testing 'High enough limit'...");
        senderBalance = testAccount.balance;
        value = 1 ether;
        swapAndBridge.swapAndBridgeToWithMinimumAmount{ value: value }(testAccount, 1e18);
        require(senderBalance == testAccount.balance + value, "Invalid sender balance update.");
        console2.log("Ok");
    }

    function runReceive() public {
        console2.log("Testing converting ETH to LST token...");
        vm.startPrank(testAccount);
        uint256 ethBalanceBefore = testAccount.balance;
        uint256 lstBalanceBefore = l1LSTToken.balanceOf(testAccount);
        (bool sent, bytes memory sendData) = address(l1LSTToken).call{ value: 1 ether }("");
        if (!sent) {
            assembly {
                let revertStringLength := mload(sendData)
                let revertStringPtr := add(sendData, 0x20)
                revert(revertStringPtr, revertStringLength)
            }
        }

        require(sent == true, "Failed to send Ether.");
        uint256 ethBalanceAfter = testAccount.balance;
        uint256 divBalanceAfter = l1LSTToken.balanceOf(testAccount);
        require(ethBalanceBefore - ethBalanceAfter == 1 ether, "Invalid ETH balance update.");
        require(divBalanceAfter - lstBalanceBefore == 1 ether, "Invalid LST balance update.");
        vm.stopPrank();
        console2.log("Ok");
    }

    function run(address _l1Bridge, address _l1Token, address _l2Token) public {
        assert(_l1Bridge != address(0));
        assert(_l1Token != address(0));
        assert(_l2Token != address(0));
        swapAndBridge = new SwapAndBridge(_l1Bridge, _l1Token, _l2Token);
        l1LSTToken = IWrappedETH(payable(_l1Token));
        runMinToken();
        runReceive();
    }
}
