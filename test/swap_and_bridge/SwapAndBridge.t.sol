// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2, Vm } from "forge-std/Test.sol";

import { SwapAndBridge } from "src/L1/SwapAndBridge.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "script/contracts/Utils.sol";

/// @title IL2CrossDomainMessenger - L2 Cross Domain Messenger interface
/// @notice This contract is used to relay messages from L1 to L2 network.
interface IL2CrossDomainMessenger {
    /// @notice Sends a message to the target contract on L2 network.
    /// @param _nonce Unique nonce for the message.
    /// @param _sender Address of the sender on L1 network.
    /// @param _target Address of the target contract on L2 network.
    /// @param _value Amount of Ether to be sent to the target contract on L2 network.
    /// @param _minGasLimit Minimum gas limit for the message on L2 network.
    /// @param _message Message to be sent to the target contract on L2 network.
    function relayMessage(
        uint256 _nonce,
        address _sender,
        address _target,
        uint256 _value,
        uint256 _minGasLimit,
        bytes calldata _message
    )
        external;
}

/// @title IDivaEtherToken - Diva Ether Token interface
/// @notice This contract is used to wrap the Diva Ether Token.
interface IWrappedETH is IERC20 {
    receive() external payable;
}

// event SentMessage(address indexed target, address sender, bytes message, uint256 messageNonce, uint256 gasLimit);
event SentMessage(address indexed target, bytes data);

/// @title TestBridgingScript
/// @notice This contract is used to test bridging Lido tokens from L1 to L2 network.
contract TestBridgingScript is Test {
    SwapAndBridge swapAndBridgeLido;
    SwapAndBridge swapAndBridgeDiva;
    IWrappedETH l1WstETH;
    IWrappedETH l2WstETH;
    IWrappedETH l1WdivETH;
    IWrappedETH l2WdivETH;

    // Address used for E2E tests
    address testAccount;

    // L1 address of the Diva bridge (this is the Lisk standard bridge)
    address constant L1_DIVA_BRIDGE_ADDR = 0x1Fb30e446eA791cd1f011675E5F3f5311b70faF5;

    // L1 address of the Diva token
    address constant L1_DIVA_TOKEN_ADDR = 0x91701E62B2DA59224e92C42a970d7901d02C2F24;

    // L2 address of the Diva bridge (this is the standard bridge for Op chains)
    address constant L2_DIVA_BRIDGE_ADDR = 0x4200000000000000000000000000000000000010;

    // L2 address of the Diva token (from previous deployment)
    address constant L2_DIVA_TOKEN_ADDR = 0x0164b1BF8683794d53b75fA6Ae7944C5e59E91d4;

    // L1 address of the Lido bridge (this is the dedicated bridge from previous deployment)
    address constant L1_LIDO_BRIDGE_ADDR = 0xdDDbC273a81e6BC49c269Af55d007c08c005ea56;

    // L1 address of the Lido token
    address constant L1_LIDO_TOKEN_ADDR = 0xB82381A3fBD3FaFA77B3a7bE693342618240067b;

    // L2 address of the Lido bridge (this is the dedicated bridge from previous deployment)
    address constant L2_LIDO_BRIDGE_ADDR = 0x7A7265ae66b094b60D9196fD5d677c11a6A03438;

    // L2 address of the Lido token (from previous deployment)
    address constant L2_LIDO_TOKEN_ADDR = 0xA363167588e8b3060fFFf69519bC440D1D8e4945;

    function setUp() public {
        swapAndBridgeLido = new SwapAndBridge(L1_LIDO_BRIDGE_ADDR, L1_LIDO_TOKEN_ADDR, L2_LIDO_TOKEN_ADDR);
        swapAndBridgeDiva = new SwapAndBridge(L1_DIVA_BRIDGE_ADDR, L1_DIVA_TOKEN_ADDR, L2_DIVA_TOKEN_ADDR);

        l1WstETH = IWrappedETH(payable(L1_LIDO_TOKEN_ADDR));
        l2WstETH = IWrappedETH(payable(L2_LIDO_TOKEN_ADDR));

        l1WdivETH = IWrappedETH(payable(L1_DIVA_TOKEN_ADDR));
        l2WdivETH = IWrappedETH(payable(L2_DIVA_TOKEN_ADDR));

        testAccount = address(0xc0ffee);
        vm.deal(testAccount, 500000 ether);
    }

    function test_lido_minL1TokensPerETH() public {
        console2.log("Testing minL1TokensPerETH...");

        // The conversion rate is 1 ETH = 1e18 wstETH.
        // Any value of minL1TokensPerETH larger than 1e18 will revert the transaction.
        vm.startPrank(testAccount);
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(testAccount, 0);
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(testAccount, 1e18);
        vm.expectRevert("Insufficient L1 tokens minted.");
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(testAccount, 1e18 + 1);

        vm.expectRevert(); // Panic due to overflow.
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 10000 ether }(testAccount, 1e75);
        vm.stopPrank();
    }

    function test_lido_valueTooLarge() public {
        console2.log("Testing value too large...");

        // The current value of getCurrentStakeLimit from
        // https://eth-sepolia.blockscout.com/address/0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af?tab=read_proxy
        uint256 currentStakeLimit = 150000 ether;
        vm.startPrank(testAccount);
        console2.log("Current stake limit: %d", currentStakeLimit);
        (bool sent,) = address(swapAndBridgeLido).call{ value: currentStakeLimit }("");
        assertEq(sent, true, "Failed to send Ether.");
        (bool sent2,) = address(swapAndBridgeLido).call{ value: currentStakeLimit + 1 }("");
        assertEq(sent2, false, "Could send too much Ether.");
        vm.stopPrank();
    }

    function test_diva_L1_receive() public {
        console2.log("Token holder address: %s", testAccount);
        console2.log("Converting ETH to wdivETH on L1 network...");
        console2.log("Current height", block.number);

        console2.logBytes(address(l1WdivETH).code);
        vm.recordLogs();

        vm.startPrank(testAccount);
        uint256 ethBalanceBefore = testAccount.balance;
        console2.log("ethBalanceBefore: %d", ethBalanceBefore);
        uint256 divBalanceBefore = l1WdivETH.balanceOf(testAccount);
        console2.log("divBalanceBefore: %d", divBalanceBefore);
        (bool sent, bytes memory sendData) = address(l1WdivETH).call{ value: 1 ether }("");
        console2.logBytes(sendData);
        if (!sent) {
            assembly {
                let revertStringLength := mload(sendData)
                let revertStringPtr := add(sendData, 0x20)
                revert(revertStringPtr, revertStringLength)
            }
        }

        assertEq(sent, true, "Failed to send Ether.");
        uint256 ethBalanceAfter = testAccount.balance;
        console2.log("ethBalanceAfter: %d", ethBalanceAfter);
        uint256 divBalanceAfter = l1WdivETH.balanceOf(testAccount);
        console2.log("divBalanceAfter: %d", divBalanceAfter);
        vm.stopPrank();
    }
}
