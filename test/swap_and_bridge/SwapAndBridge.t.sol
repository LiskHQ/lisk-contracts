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
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    IL2CrossDomainMessenger l2Messenger;

    SwapAndBridge swapAndBridgeLido;
    SwapAndBridge swapAndBridgeDiva;
    IWrappedETH l1WstETH;
    IWrappedETH l2WstETH;
    IWrappedETH l1WdivETH;
    IWrappedETH l2WdivETH;

    // Address used for E2E tests
    address test_account;

    // L2 Cross Domain Messenger address
    address constant L2_CROSS_DOMAIN_MESSENGER_ADDR = 0x4200000000000000000000000000000000000007;

    // L2 sequencer address (this is the Lisk Sepolia Sequencer address)
    address constant SEQUENCER_ADDR = 0x968924E6234f7733eCA4E9a76804fD1afA1a4B3D;

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

    function getSlice(uint256 begin, uint256 end, bytes memory text) public pure returns (bytes memory) {
        bytes memory a = new bytes(end - begin + 1);
        for (uint256 i = 0; i <= end - begin; i++) {
            a[i] = bytes(text)[i + begin - 1];
        }
        return a;
    }

    function setUp() public {
        utils = new Utils();

        l2Messenger = IL2CrossDomainMessenger(L2_CROSS_DOMAIN_MESSENGER_ADDR);

        swapAndBridgeLido = new SwapAndBridge(L1_LIDO_BRIDGE_ADDR, L1_LIDO_TOKEN_ADDR, L2_LIDO_TOKEN_ADDR);
        swapAndBridgeDiva = new SwapAndBridge(L1_DIVA_BRIDGE_ADDR, L1_DIVA_TOKEN_ADDR, L2_DIVA_TOKEN_ADDR);

        l1WstETH = IWrappedETH(payable(L1_LIDO_TOKEN_ADDR));
        l2WstETH = IWrappedETH(payable(L2_LIDO_TOKEN_ADDR));

        l1WdivETH = IWrappedETH(payable(L1_DIVA_TOKEN_ADDR));
        l2WdivETH = IWrappedETH(payable(L2_DIVA_TOKEN_ADDR));

        test_account = address(0xc0ffee);
        vm.deal(test_account, 500000 ether);
    }

    function test_unit_minL1TokensPerETH() public {
        console2.log("Testing minL1TokensPerETH...");

        // The conversion rate is 1 ETH = 1e18 wstETH.
        // Any value of minL1TokensPerETH larger than 1e18 will revert the transaction.
        vm.startPrank(test_account);
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(test_account, 0);
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(test_account, 1e18);
        vm.expectRevert("Insufficient L1 tokens minted.");
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(test_account, 1e18 + 1);

        vm.expectRevert(); // Panic due to overflow.
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 10000 ether }(test_account, 1e75);
        vm.stopPrank();
    }

    function test_unit_lido_valueTooLarge() public {
        console2.log("Testing value too large...");

        // The current value of getCurrentStakeLimit from
        // https://eth-sepolia.blockscout.com/address/0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af?tab=read_proxy
        uint256 currentStakeLimit = 150000 ether;
        vm.startPrank(test_account);
        console2.log("Current stake limit: %d", currentStakeLimit);
        (bool sent,) = address(swapAndBridgeLido).call{ value: currentStakeLimit }("");
        assertEq(sent, true, "Failed to send Ether.");
        (bool sent2,) = address(swapAndBridgeLido).call{ value: currentStakeLimit + 1 }("");
        assertEq(sent2, false, "Could send too much Ether.");
        vm.stopPrank();
    }

    function test_e2e_lido_L1() public {
        console2.log("Token holder address: %s", test_account);
        console2.log("Transferring ETH tokens from L1 to wstETH on L2 network...");

        vm.recordLogs();

        // Test bridging for Lido
        vm.startPrank(test_account);
        (bool sent,) = address(swapAndBridgeLido).call{ value: 10000 ether }("");
        assertEq(sent, true, "Failed to send Ether.");
        vm.stopPrank();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 11, "Invalid number of logs");

        // entries[3] is the mint event, transferring from 0 to swapAndBridge contract
        // Transfer(address indexed from, address indexed to, uint256 value)
        assertEq(entries[3].topics.length, 3, "Transfer: Invalid number of topics");
        assertEq(
            entries[3].topics[0], keccak256("Transfer(address,address,uint256)"), "Transfer: Invalid default topic"
        );
        assertEq(entries[3].topics[1], bytes32(0), "Transfer: Invalid from address topic");
        assertEq(
            entries[3].topics[2],
            bytes32(uint256(uint160(address(swapAndBridgeLido)))),
            "Transfer: Invalid to address topic"
        );
        uint256 mintedAmount = uint256(bytes32(entries[3].data));
        assertEq(mintedAmount, 10000 ether, "Transfer: Invalid amount");

        // entries[4] is the approve event
        // Approval(address indexed owner, address indexed spender, uint256 value)
        assertEq(entries[4].topics.length, 3, "Approval: Invalid number of topics");
        assertEq(
            entries[4].topics[0], keccak256("Approval(address,address,uint256)"), "Approval: Invalid default topic"
        );
        assertEq(
            entries[4].topics[1],
            bytes32(uint256(uint160(address(swapAndBridgeLido)))),
            "Approval: Invalid owner address topic"
        );
        assertEq(
            entries[4].topics[2],
            bytes32(uint256(uint160(L1_LIDO_BRIDGE_ADDR))),
            "Approval: Invalid spender address topic"
        );

        // entries[5] is the transfer event from swapAndBridge to L1_LIDO_BRIDGE_ADDR
        // Transfer(address indexed from, address indexed to, uint256 value)
        assertEq(entries[5].topics.length, 3, "Transfer: Invalid number of topics");
        assertEq(
            entries[5].topics[0], keccak256("Transfer(address,address,uint256)"), "Transfer: Invalid default topic"
        );
        assertEq(
            entries[5].topics[1],
            bytes32(uint256(uint160(address(swapAndBridgeLido)))),
            "Transfer: Invalid from address topic"
        );
        assertEq(
            entries[5].topics[2], bytes32(uint256(uint160(L1_LIDO_BRIDGE_ADDR))), "Transfer: Invalid to address topic"
        );

        // entries[8] is the SentMessage event
        // SentMessage(address indexed target, address sender, bytes message, uint256 messageNonce, uint256 gasLimit)
        assertEq(entries[8].topics.length, 2, "SentMessage: Invalid number of topics");
        assertEq(
            entries[8].topics[0],
            keccak256("SentMessage(address,address,bytes,uint256,uint256)"),
            "SentMessage: Invalid default topic"
        );

        assertEq(
            entries[8].topics[1],
            bytes32(uint256(uint160(L2_LIDO_BRIDGE_ADDR))),
            "SentMessage: Invalid target address topic"
        );

        (address sender, bytes memory message, uint256 messageNonce, uint256 gasLimit) =
            abi.decode(entries[8].data, (address, bytes, uint256, uint256));
        assertEq(sender, L1_LIDO_BRIDGE_ADDR, "SentMessage: Invalid sender address");
        assertEq(
            gasLimit,
            swapAndBridgeLido.MIN_DEPOSIT_GAS(),
            "SentMessage: Invalid gas limit, not matching contract MIN_DEPOSIT_GAS"
        );

        // The message is encoded in a weird way: bytes 4 is packed, the addresses are not
        // Hence, we slice the message to remove the bytes4 selector.
        bytes memory selectorBytes = getSlice(1, 5, message);
        assertEq(
            bytes4(selectorBytes),
            bytes4(keccak256("finalizeDeposit(address,address,address,address,uint256,bytes)")),
            "SentMessage: Invalid selector"
        );

        bytes memory slicedMessage = getSlice(5, message.length, message);
        (address remoteToken, address localToken, address from, address to, uint256 amount, bytes memory extraData) =
            abi.decode(slicedMessage, (address, address, address, address, uint256, bytes));

        assertEq(remoteToken, L1_LIDO_TOKEN_ADDR, "SentMessage: Invalid L1 token address");
        assertEq(localToken, L2_LIDO_TOKEN_ADDR, "SentMessage: Invalid L2 token address");
        assertEq(from, address(swapAndBridgeLido), "SentMessage: Invalid sender address");
        assertEq(to, test_account, "SentMessage: Invalid recipient address");
        assertEq(amount, 10000 ether, "SentMessage: Invalid amount");
        assertEq(extraData.length, 2, "SentMessage: Invalid extra data");

        vm.serializeAddress("", "sender", sender);
        vm.serializeAddress("", "target", L2_LIDO_BRIDGE_ADDR);
        vm.serializeBytes("", "message", message);
        vm.serializeUint("", "messageNonce", messageNonce);

        bytes memory data = abi.encode(sender, L2_LIDO_BRIDGE_ADDR, message, messageNonce, gasLimit);
        vm.writeFileBinary("./lido_e2e_data", data);
    }

    function test_e2e_lido_L2() public {
        console2.log("Relaying message to L2 network...");
        bytes memory data = vm.readFileBinary( "./lido_e2e_data");
        (address payable sender, address payable target, bytes memory message, uint256 messageNonce, uint256 gasLimit) =
            abi.decode(data, (address, address, bytes, uint256, uint256));

        uint256 balanceBefore = l2WstETH.balanceOf(test_account);
        console2.log("balanceBefore: %d", balanceBefore);

        vm.startBroadcast(SEQUENCER_ADDR);
        l2Messenger.relayMessage(messageNonce, sender, target, 0, gasLimit, message);
        vm.stopPrank();

        uint256 balanceAfter = l2WstETH.balanceOf(test_account);

        console2.log("balanceAfter: %d", balanceAfter);
        assertEq(balanceAfter - balanceBefore, 10000 ether);
    }

    function test_e2e_diva_L1() public {
        console2.log("Token holder address: %s", test_account);
        console2.log("Transferring ETH tokens from L1 to wdivETH on L2 network...");

        vm.recordLogs();

        // Test bridging for Diva
        vm.startPrank(test_account);
        (bool sent, bytes memory sendData) = address(swapAndBridgeDiva).call{ value: 1 ether }("");
        if (!sent) {
            assembly {
                let revertStringLength := mload(sendData)
                let revertStringPtr := add(sendData, 0x20)
                revert(revertStringPtr, revertStringLength)
            }
        }
        assertEq(sent, true, "Failed to send Ether.");
        vm.stopPrank();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 9, "Invalid number of logs");

        // entries[0] is the mint event, transferring from 0 to l1WdivETH contract
        // Transfer(address indexed from, address indexed to, uint256 value)
        assertEq(entries[0].topics.length, 3, "Transfer: Invalid number of topics");
        assertEq(
            entries[0].topics[0], keccak256("Transfer(address,address,uint256)"), "Transfer: Invalid default topic"
        );
        assertEq(entries[0].topics[1], bytes32(0), "Transfer: Invalid from address topic");
        assertEq(
            entries[0].topics[2], bytes32(uint256(uint160(address(l1WdivETH)))), "Transfer: Invalid to address topic"
        );
        uint256 mintedAmount = uint256(bytes32(entries[0].data));
        assertEq(mintedAmount, 1 ether, "Transfer: Invalid amount");
        // entries[2] is the approve event
        // Approval(address indexed owner, address indexed spender, uint256 value)
        assertEq(entries[2].topics.length, 3, "Approval: Invalid number of topics");
        assertEq(
            entries[2].topics[0], keccak256("Approval(address,address,uint256)"), "Approval: Invalid default topic"
        );
        assertEq(
            entries[2].topics[1],
            bytes32(uint256(uint160(address(swapAndBridgeDiva)))),
            "Approval: Invalid owner address topic"
        );
        assertEq(
            entries[2].topics[2],
            bytes32(uint256(uint160(L1_DIVA_BRIDGE_ADDR))),
            "Approval: Invalid spender address topic"
        );

        // entries[3] is the transfer event from swapAndBridge to L1_DIVA_BRIDGE_ADDR
        // Transfer(address indexed from, address indexed to, uint256 value)
        assertEq(entries[3].topics.length, 3, "Transfer: Invalid number of topics");
        assertEq(
            entries[3].topics[0], keccak256("Transfer(address,address,uint256)"), "Transfer: Invalid default topic"
        );
        assertEq(
            entries[3].topics[1],
            bytes32(uint256(uint160(address(swapAndBridgeDiva)))),
            "Transfer: Invalid from address topic"
        );
        assertEq(
            entries[3].topics[2], bytes32(uint256(uint160(L1_DIVA_BRIDGE_ADDR))), "Transfer: Invalid to address topic"
        );

        // entries[7] is the SentMessage event
        // SentMessage(address indexed target, address sender, bytes message, uint256 messageNonce, uint256 gasLimit)
        assertEq(entries[8].topics.length, 2, "SentMessage: Invalid number of topics");
        assertEq(
            entries[7].topics[0],
            keccak256("SentMessage(address,address,bytes,uint256,uint256)"),
            "SentMessage: Invalid default topic"
        );

        assertEq(
            entries[7].topics[1],
            bytes32(uint256(uint160(L2_DIVA_BRIDGE_ADDR))),
            "SentMessage: Invalid target address topic"
        );

        (address sender, bytes memory message, uint256 messageNonce, uint256 gasLimit) =
            abi.decode(entries[7].data, (address, bytes, uint256, uint256));
        assertEq(sender, L1_DIVA_BRIDGE_ADDR, "SentMessage: Invalid sender address");
        assertEq(
            gasLimit,
            swapAndBridgeDiva.MIN_DEPOSIT_GAS(),
            "SentMessage: Invalid gas limit, not matching contract MIN_DEPOSIT_GAS"
        );

        // The message is encoded in a weird way: bytes 4 is packed, the addresses are not
        // Hence, we slice the message to remove the bytes4 selector.
        bytes memory selectorBytes = getSlice(1, 5, message);
        assertEq(
            bytes4(selectorBytes),
            bytes4(keccak256("finalizeBridgeERC20(address,address,address,address,uint256,bytes)")),
            "SentMessage: Invalid selector"
        );

        bytes memory slicedMessage = getSlice(5, message.length, message);
        (address localToken, address remoteToken, address from, address to, uint256 amount, bytes memory extraData) =
            abi.decode(slicedMessage, (address, address, address, address, uint256, bytes));

        assertEq(remoteToken, L1_DIVA_TOKEN_ADDR, "SentMessage: Invalid L1 token address");
        assertEq(localToken, L2_DIVA_TOKEN_ADDR, "SentMessage: Invalid L2 token address");
        assertEq(from, address(swapAndBridgeDiva), "SentMessage: Invalid sender address");
        assertEq(to, test_account, "SentMessage: Invalid recipient address");
        assertEq(amount, 1 ether, "SentMessage: Invalid amount");
        assertEq(extraData.length, 2, "SentMessage: Invalid extra data");

        vm.serializeAddress("", "sender", sender);
        vm.serializeAddress("", "target", L2_DIVA_BRIDGE_ADDR);
        vm.serializeBytes("", "message", message);
        vm.serializeUint("", "messageNonce", messageNonce);

        bytes memory data = abi.encode(sender, L2_DIVA_BRIDGE_ADDR, message, messageNonce, gasLimit);
        vm.writeFileBinary("./diva_e2e_data", data);
    }

    function test_e2e_diva_L2() public {
        bytes memory data = vm.readFileBinary("./diva_e2e_data");
        (address payable sender, address payable target, bytes memory message, uint256 messageNonce, uint256 gasLimit) =
            abi.decode(data, (address, address, bytes, uint256, uint256));

        assertEq(
            gasLimit,
            swapAndBridgeDiva.MIN_DEPOSIT_GAS(),
            "SentMessage: Invalid gas limit, not matching contract MIN_DEPOSIT_GAS"
        );

        uint256 balanceBefore = l2WdivETH.balanceOf(test_account);

        vm.startBroadcast(SEQUENCER_ADDR);
        console2.log("Relaying message to L2 network...");
        l2Messenger.relayMessage(messageNonce, sender, target, 0, gasLimit, message);
        vm.stopPrank();

        uint256 balanceAfter = l2WdivETH.balanceOf(test_account);
        console2.log("balanceBefore: %d", balanceBefore);
        console2.log("balanceAfter: %d", balanceAfter);
        assertEq(balanceAfter - balanceBefore, 1 ether);
    }

    function test_diva_L1_receive() public {
        console2.log("Token holder address: %s", test_account);
        console2.log("Converting ETH to wdivETH on L1 network...");
        console2.log("Current height", block.number);

        console2.logBytes(address(l1WdivETH).code);
        vm.recordLogs();

        vm.startPrank(test_account);
        uint256 ethBalanceBefore = test_account.balance;
        console2.log("ethBalanceBefore: %d", ethBalanceBefore);
        uint256 divBalanceBefore = l1WdivETH.balanceOf(test_account);
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
        uint256 ethBalanceAfter = test_account.balance;
        console2.log("ethBalanceAfter: %d", ethBalanceAfter);
        uint256 divBalanceAfter = l1WdivETH.balanceOf(test_account);
        console2.log("divBalanceAfter: %d", divBalanceAfter);
        vm.stopPrank();
    }
}
