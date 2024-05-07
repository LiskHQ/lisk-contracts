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

/// @title TestDivaIntegrationScript
/// @notice This contract is used to run integration test with the Diva LST.
contract TestDivaIntegrationScript is Script {
    // SwapAndBridge contract
    SwapAndBridge swapAndBridgeDiva;

    // The L1 Diva LST token
    IWrappedETH l1WdivETH;

    // Address used for E2E tests
    address constant testAccount = address(0xc0ffee);

    // L1 address of the Diva bridge (this is the Lisk standard bridge)
    address constant L1_DIVA_BRIDGE_ADDR = 0x1Fb30e446eA791cd1f011675E5F3f5311b70faF5;

    // L1 address of the Diva token
    address constant L1_DIVA_TOKEN_ADDR = 0x91701E62B2DA59224e92C42a970d7901d02C2F24;

    // L2 address of the Diva token (from previous deployment)
    address constant L2_DIVA_TOKEN_ADDR = 0x0164b1BF8683794d53b75fA6Ae7944C5e59E91d4;

    function setUp() public {
        swapAndBridgeDiva = new SwapAndBridge(L1_DIVA_BRIDGE_ADDR, L1_DIVA_TOKEN_ADDR, L2_DIVA_TOKEN_ADDR);
        l1WdivETH = IWrappedETH(payable(L1_DIVA_TOKEN_ADDR));
        vm.deal(testAccount, 500000 ether);
    }

    function runMinToken() public {
        console2.log("Testing minL1TokensPerETH...");
        // The conversion rate is 1 ETH = 1e18 wstETH.
        // Any value of minL1TokensPerETH larger than 1e18 will revert the transaction.
        vm.startPrank(testAccount);

        console2.log("Testing no minimum...");
        swapAndBridgeDiva.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(testAccount, 0);
        console2.log("Ok");

        console2.log("Testing 'Insufficient L1 tokens minted'...");
        vm.expectRevert("Insufficient L1 tokens minted.");
        swapAndBridgeDiva.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(testAccount, 1e18 + 1);
        console2.log("Ok");

        console2.log("Testing 'Overflow'...");
        vm.expectRevert(); // Panic due to overflow.
        swapAndBridgeDiva.swapAndBridgeToWithMinimumAmount{ value: 10000 ether }(testAccount, 1e75);
        console2.log("Ok");

        console2.log("Testing 'High enough limit'...");
        swapAndBridgeDiva.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(testAccount, 1e18);
        console2.log("Ok");
    }

    function runReceive() public {
        console2.log("Testing converting ETH to wdivETH...");
        vm.recordLogs();
        vm.startPrank(testAccount);
        uint256 ethBalanceBefore = testAccount.balance;
        uint256 divBalanceBefore = l1WdivETH.balanceOf(testAccount);
        (bool sent, bytes memory sendData) = address(l1WdivETH).call{ value: 1 ether }("");
        if (!sent) {
            assembly {
                let revertStringLength := mload(sendData)
                let revertStringPtr := add(sendData, 0x20)
                revert(revertStringPtr, revertStringLength)
            }
        }

        require(sent == true, "Failed to send Ether.");
        uint256 ethBalanceAfter = testAccount.balance;
        uint256 divBalanceAfter = l1WdivETH.balanceOf(testAccount);
        require(ethBalanceBefore - ethBalanceAfter == 1 ether, "Invalid ETH balance update.");
        require(divBalanceAfter - divBalanceBefore == 1 ether, "Invalid DIV balance update.");
        vm.stopPrank();
        console2.log("Ok");
    }

    function run() public {
        runMinToken();
        runReceive();
    }
}
