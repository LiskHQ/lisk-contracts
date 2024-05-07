// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { SwapAndBridge } from "src/L1/SwapAndBridge.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IWrappedETH - Wrapped Ether Token interface
/// @notice This contract is used to wrap the a LST.
interface IWrappedETH is IERC20 {
    receive() external payable;
    function stETH() external returns (address);
}

/// @title IStETH - Lido Liquid Ether Token interface
/// @notice This contract is used to get the current staking limit on Lido.
interface IStETH is IERC20 {
    function getCurrentStakeLimit() external returns (uint256);
}

/// @title TestLidoIntegrationScript
/// @notice This contract is used to run integration test with the Lido LST.
contract TestLidoIntegrationScript is Script {
    // SwapAndBridge contract
    SwapAndBridge swapAndBridgeLido;

    // The L1 Lido LST token
    IWrappedETH l1WstETH;

    // Address used for E2E tests
    address constant testAccount = address(0xc0ffee);

    // L1 address of the Lido bridge (this is the dedicated bridge from previous deployment)
    address constant L1_LIDO_BRIDGE_ADDR = 0xdDDbC273a81e6BC49c269Af55d007c08c005ea56;

    // L1 address of the Lido token
    address constant L1_LIDO_TOKEN_ADDR = 0xB82381A3fBD3FaFA77B3a7bE693342618240067b;

    // L2 address of the Lido token (from previous deployment)
    address constant L2_LIDO_TOKEN_ADDR = 0xA363167588e8b3060fFFf69519bC440D1D8e4945;

    function setUp() public {
        swapAndBridgeLido = new SwapAndBridge(L1_LIDO_BRIDGE_ADDR, L1_LIDO_TOKEN_ADDR, L2_LIDO_TOKEN_ADDR);
        l1WstETH = IWrappedETH(payable(L1_LIDO_TOKEN_ADDR));
        vm.deal(testAccount, 500_000 ether);
    }

    function runMinToken() public {
        console2.log("Testing minL1TokensPerETH...");
        // The conversion rate is 1 ETH = 1e18 wstETH.
        // Any value of minL1TokensPerETH larger than 1e18 will revert the transaction.
        vm.startPrank(testAccount);

        console2.log("Testing no minimum...");
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(testAccount, 0);
        console2.log("Ok");

        console2.log("Testing 'Insufficient L1 tokens minted'...");
        vm.expectRevert("Insufficient L1 tokens minted.");
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(testAccount, 1e18 + 1);
        console2.log("Ok");

        console2.log("Testing 'Overflow'...");
        vm.expectRevert(); // Panic due to overflow.
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 10000 ether }(testAccount, 1e75);
        console2.log("Ok");

        console2.log("Testing 'High enough limit'...");
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(testAccount, 1e18);
        console2.log("Ok");
    }

    function runReceive() public {
        console2.log("Testing converting ETH to wstETH...");
        vm.recordLogs();
        vm.startPrank(testAccount);
        uint256 ethBalanceBefore = testAccount.balance;
        uint256 wstBalanceBefore = l1WstETH.balanceOf(testAccount);
        (bool sent, bytes memory sendData) = address(l1WstETH).call{ value: 1 ether }("");
        if (!sent) {
            assembly {
                let revertStringLength := mload(sendData)
                let revertStringPtr := add(sendData, 0x20)
                revert(revertStringPtr, revertStringLength)
            }
        }

        require(sent == true, "Failed to send Ether.");
        uint256 ethBalanceAfter = testAccount.balance;
        uint256 wstBalanceAfter = l1WstETH.balanceOf(testAccount);
        require(ethBalanceBefore - ethBalanceAfter == 1 ether, "Invalid ETH balance update.");
        require(wstBalanceAfter - wstBalanceBefore == 1 ether, "Invalid Wst balance update.");
        vm.stopPrank();
        console2.log("Ok");
    }

    function runStakeLimit() public {
        address stETHAddress = l1WstETH.stETH();
        IStETH stETH = IStETH(stETHAddress);
        uint256 currentStakeLimit = stETH.getCurrentStakeLimit();
        console2.log("Current Lido staking limit: %s ETH", currentStakeLimit);
        console2.log("Test sending exactly current stake limit...");
        (bool sent,) = address(swapAndBridgeLido).call{ value: currentStakeLimit }("");
        require(sent == true, "Failed to send Ether.");
        console2.log("Ok");
        console2.log("Test sending above current stake limit...");
        (bool sent2,) = address(swapAndBridgeLido).call{ value: currentStakeLimit + 1 }("");
        require(sent2 == false, "Could send too much Ether.");
        console2.log("Ok");
        vm.stopPrank();
    }

    function run() public {
        runMinToken();
        runReceive();
        runStakeLimit();
    }
}
