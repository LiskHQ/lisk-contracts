// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2, Vm } from "forge-std/Test.sol";

// import { WstETH } from "src/L1/lido/WstETH.sol";
// import { L2WdivETH } from "src/L2/L2WdivETH.sol";
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

    // L2 Cross Domain Messenger address
    address constant L2_CROSS_DOMAIN_MESSENGER_ADDR = 0x4200000000000000000000000000000000000007;

    // L2 sequencer address
    address constant SEQUENCER_ADDR = 0x968924E6234f7733eCA4E9a76804fD1afA1a4B3D;

    function getSlice(uint256 begin, uint256 end, bytes memory text) public pure returns (bytes memory) {
        bytes memory a = new bytes(end - begin + 1);
        for (uint256 i = 0; i <= end - begin; i++) {
            a[i] = bytes(text)[i + begin - 1];
        }
        return a;
    }

    function setUp() public {
        utils = new Utils();

        l2Messenger = IL2CrossDomainMessenger(vm.envAddress("L2_CROSS_DOMAIN_MESSENGER_ADDR"));

        swapAndBridgeLido = new SwapAndBridge(
            vm.envAddress("L1_LIDO_BRIDGE_ADDR"),
            vm.envAddress("L1_LIDO_TOKEN_ADDR"),
            vm.envAddress("L2_LIDO_TOKEN_ADDR")
        );
        swapAndBridgeDiva = new SwapAndBridge(
            vm.envAddress("L1_DIVA_BRIDGE_ADDR"),
            vm.envAddress("L1_DIVA_TOKEN_ADDR"),
            vm.envAddress("L2_DIVA_TOKEN_ADDR")
        );

        l1WstETH = IWrappedETH(payable(vm.envAddress("L1_LIDO_TOKEN_ADDR")));
        l2WstETH = IWrappedETH(payable(vm.envAddress("L2_LIDO_TOKEN_ADDR")));

        l1WdivETH = IWrappedETH(payable(vm.envAddress("L1_DIVA_TOKEN_ADDR")));
        l2WdivETH = IWrappedETH(payable(vm.envAddress("L2_DIVA_TOKEN_ADDR")));

        console2.log("SwapAndBridge (Lido) address: %s", address(swapAndBridgeLido));
        console2.log("SwapAndBridge (Diva) address: %s", address(swapAndBridgeDiva));
        console2.log("L1 WstETH address: %s", address(l1WstETH));
        console2.log("L2 WstETH address: %s", address(l2WstETH));
        console2.log("L1 WdivETH address: %s", address(l1WdivETH));
        console2.log("L2 WdivETH address: %s", address(l2WdivETH));
    }

    function test_unit_minL1TokensPerETH() public {
        console2.log("Testing minL1TokensPerETH...");
        uint256 token_holder_priv_key = vm.envUint("TOKEN_HOLDER_PRIV_KEY");

        // The conversion rate is 1 ETH = 1e18 wstETH.
        // Any value of minL1TokensPerETH larger than 1e18 will revert the transaction.
        vm.startBroadcast(token_holder_priv_key);
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(vm.addr(token_holder_priv_key), 0);
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(vm.addr(token_holder_priv_key), 1e18);
        vm.expectRevert("Insufficient L1 tokens minted.");
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 1 ether }(vm.addr(token_holder_priv_key), 1e18 + 1);

        vm.expectRevert(); // Panic due to overflow.
        swapAndBridgeLido.swapAndBridgeToWithMinimumAmount{ value: 10000 ether }(vm.addr(token_holder_priv_key), 1e75);
        vm.stopBroadcast();
    }

    function test_unit_lido_valueTooLarge() public {
        console2.log("Testing value too large...");
        uint256 token_holder_priv_key = vm.envUint("TOKEN_HOLDER_PRIV_KEY");

        // The current value of getCurrentStakeLimit from
        // https://eth-sepolia.blockscout.com/address/0x3e3FE7dBc6B4C189E7128855dD526361c49b40Af?tab=read_proxy
        uint256 currentStakeLimit = 150000 ether;
        vm.startBroadcast(token_holder_priv_key);
        console2.log("Current stake limit: %d", currentStakeLimit);
        (bool sent,) = address(swapAndBridgeLido).call{ value: currentStakeLimit }("");
        assertEq(sent, true, "Failed to send Ether.");
        (bool sent2,) = address(swapAndBridgeLido).call{ value: currentStakeLimit + 1 }("");
        assertEq(sent2, false, "Could send Ether too much Ether.");
        vm.stopBroadcast();
    }

    function test_e2e_lido_L1() public {
        uint256 token_holder_priv_key = vm.envUint("TOKEN_HOLDER_PRIV_KEY");
        console2.log("Token holder address: %s", vm.addr(token_holder_priv_key));
        console2.log("Transferring ETH tokens from L1 to wstETH on L2 network...");

        vm.recordLogs();

        // Test bridging for Lido
        vm.startBroadcast(token_holder_priv_key);
        (bool sent,) = address(swapAndBridgeLido).call{ value: 10000 ether }("");
        assertEq(sent, true, "Failed to send Ether.");
        vm.stopBroadcast();

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
            bytes32(uint256(uint160(vm.envAddress("L1_LIDO_BRIDGE_ADDR")))),
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
            entries[5].topics[2],
            bytes32(uint256(uint160(vm.envAddress("L1_LIDO_BRIDGE_ADDR")))),
            "Transfer: Invalid to address topic"
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
            bytes32(uint256(uint160(vm.envAddress("L2_LIDO_BRIDGE_ADDR")))),
            "SentMessage: Invalid target address topic"
        );

        (address sender, bytes memory message, uint256 messageNonce, uint256 gasLimit) =
            abi.decode(entries[8].data, (address, bytes, uint256, uint256));
        assertEq(sender, vm.envAddress("L1_LIDO_BRIDGE_ADDR"), "SentMessage: Invalid sender address");
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

        assertEq(remoteToken, vm.envAddress("L1_LIDO_TOKEN_ADDR"), "SentMessage: Invalid L1 token address");
        assertEq(localToken, vm.envAddress("L2_LIDO_TOKEN_ADDR"), "SentMessage: Invalid L2 token address");
        assertEq(from, address(swapAndBridgeLido), "SentMessage: Invalid sender address");
        assertEq(to, vm.addr(vm.envUint("TOKEN_HOLDER_PRIV_KEY")), "SentMessage: Invalid recipient address");
        assertEq(amount, 10000 ether, "SentMessage: Invalid amount");
        assertEq(extraData.length, 2, "SentMessage: Invalid extra data");

        vm.serializeAddress("", "sender", sender);
        vm.serializeAddress("", "target", vm.envAddress("L2_LIDO_BRIDGE_ADDR"));
        vm.serializeBytes("", "message", message);
        vm.serializeUint("", "messageNonce", messageNonce);
        string memory json = vm.serializeUint("", "gasLimit", gasLimit);
        console2.log("Saved to JSON");
        vm.writeJson(json, string.concat(vm.projectRoot(), "/test/swap_and_bridge/lido.json"));

        bytes memory data = abi.encode(sender, vm.envAddress("L2_LIDO_BRIDGE_ADDR"), message, messageNonce, gasLimit);
        vm.writeFileBinary(string.concat(vm.projectRoot(), "/test/swap_and_bridge/lido.data"), data);
    }

    function test_e2e_lido_L2() public {
        address sequencer = vm.envAddress("SEQUENCER_ADDR");
        console2.log("Relaying message to L2 network...");

        bytes memory data = vm.readFileBinary(string.concat(vm.projectRoot(), "/test/swap_and_bridge/lido.data"));

        (address payable sender, address payable target, bytes memory message, uint256 messageNonce, uint256 gasLimit) =
            abi.decode(data, (address, address, bytes, uint256, uint256));

        uint256 balanceBefore = l2WstETH.balanceOf(vm.addr(vm.envUint("TOKEN_HOLDER_PRIV_KEY")));
        console2.log("balanceBefore: %d", balanceBefore);

        vm.startBroadcast(sequencer);
        l2Messenger.relayMessage(messageNonce, sender, target, 0, gasLimit, message);
        vm.stopBroadcast();

        uint256 balanceAfter = l2WstETH.balanceOf(vm.addr(vm.envUint("TOKEN_HOLDER_PRIV_KEY")));

        console2.log("balanceAfter: %d", balanceAfter);
        assertEq(balanceAfter - balanceBefore, 10000 ether);
    }

    function test_e2e_diva_L1() public {
        uint256 token_holder_priv_key = vm.envUint("TOKEN_HOLDER_PRIV_KEY");
        console2.log("Token holder address: %s", vm.addr(token_holder_priv_key));
        console2.log("Transferring ETH tokens from L1 to wdivETH on L2 network...");

        vm.recordLogs();

        // Test bridging for Diva
        vm.startBroadcast(token_holder_priv_key);
        (bool sent, bytes memory sendData) = address(swapAndBridgeDiva).call{ value: 1 ether }("");
        console2.log("Sent: %s", sent ? "true" : "false");
        if (!sent) {
            assembly {
                let revertStringLength := mload(sendData)
                let revertStringPtr := add(sendData, 0x20)
                revert(revertStringPtr, revertStringLength)
            }
        }
        assertEq(sent, true, "Failed to send Ether.");
        vm.stopBroadcast();

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
            bytes32(uint256(uint160(vm.envAddress("L1_DIVA_BRIDGE_ADDR")))),
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
            entries[3].topics[2],
            bytes32(uint256(uint160(vm.envAddress("L1_DIVA_BRIDGE_ADDR")))),
            "Transfer: Invalid to address topic"
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
            bytes32(uint256(uint160(vm.envAddress("L2_DIVA_BRIDGE_ADDR")))),
            "SentMessage: Invalid target address topic"
        );

        (address sender, bytes memory message, uint256 messageNonce, uint256 gasLimit) =
            abi.decode(entries[7].data, (address, bytes, uint256, uint256));
        assertEq(sender, vm.envAddress("L1_DIVA_BRIDGE_ADDR"), "SentMessage: Invalid sender address");
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

        assertEq(remoteToken, vm.envAddress("L1_DIVA_TOKEN_ADDR"), "SentMessage: Invalid L1 token address");
        assertEq(localToken, vm.envAddress("L2_DIVA_TOKEN_ADDR"), "SentMessage: Invalid L2 token address");
        assertEq(from, address(swapAndBridgeDiva), "SentMessage: Invalid sender address");
        assertEq(to, vm.addr(vm.envUint("TOKEN_HOLDER_PRIV_KEY")), "SentMessage: Invalid recipient address");
        assertEq(amount, 1 ether, "SentMessage: Invalid amount");
        assertEq(extraData.length, 2, "SentMessage: Invalid extra data");

        vm.serializeAddress("", "sender", sender);
        vm.serializeAddress("", "target", vm.envAddress("L2_DIVA_BRIDGE_ADDR"));
        vm.serializeBytes("", "message", message);
        vm.serializeUint("", "messageNonce", messageNonce);
        string memory json = vm.serializeUint("", "gasLimit", gasLimit);
        console2.log("Saved to JSON");
        vm.writeJson(json, string.concat(vm.projectRoot(), "/test/swap_and_bridge/diva.json"));

        bytes memory data = abi.encode(sender, vm.envAddress("L2_DIVA_BRIDGE_ADDR"), message, messageNonce, gasLimit);
        vm.writeFileBinary(string.concat(vm.projectRoot(), "/test/swap_and_bridge/diva.data"), data);
    }

    function test_e2e_diva_L2() public {
        address sequencer = vm.envAddress("SEQUENCER_ADDR");

        bytes memory data = vm.readFileBinary(string.concat(vm.projectRoot(), "/test/swap_and_bridge/diva.data"));
        (address payable sender, address payable target, bytes memory message, uint256 messageNonce, uint256 gasLimit) =
            abi.decode(data, (address, address, bytes, uint256, uint256));

        assertEq(
            gasLimit,
            swapAndBridgeDiva.MIN_DEPOSIT_GAS(),
            "SentMessage: Invalid gas limit, not matching contract MIN_DEPOSIT_GAS"
        );

        uint256 balanceBefore = l2WdivETH.balanceOf(vm.addr(vm.envUint("TOKEN_HOLDER_PRIV_KEY")));

        vm.startBroadcast(sequencer);
        console2.log("Relaying message to L2 network...");
        l2Messenger.relayMessage(messageNonce, sender, target, 0, gasLimit, message);
        vm.stopBroadcast();

        uint256 balanceAfter = l2WdivETH.balanceOf(vm.addr(vm.envUint("TOKEN_HOLDER_PRIV_KEY")));
        console2.log("balanceBefore: %d", balanceBefore);
        console2.log("balanceAfter: %d", balanceAfter);
        assertEq(balanceAfter - balanceBefore, 1 ether);
    }

    function test_diva_L1_receive() public {
        uint256 token_holder_priv_key = vm.envUint("TOKEN_HOLDER_PRIV_KEY");
        console2.log("Token holder address: %s", vm.addr(token_holder_priv_key));
        console2.log("Converting ETH to wdivETH on L1 network...");
        console2.log("Current height", block.number);

        console2.logBytes(address(l1WdivETH).code);
        vm.recordLogs();

        vm.startBroadcast(token_holder_priv_key);
        uint256 ethBalanceBefore = vm.addr(token_holder_priv_key).balance;
        console2.log("ethBalanceBefore: %d", ethBalanceBefore);
        uint256 divBalanceBefore = l1WdivETH.balanceOf(vm.addr(token_holder_priv_key));
        console2.log("divBalanceBefore: %d", divBalanceBefore);
        (bool sent, bytes memory sendData) = address(l1WdivETH).call{ value: 1 ether }("");
        console2.log("Sent: %s", sent ? "true" : "false");
        console2.logBytes(sendData);
        if (!sent) {
            assembly {
                let revertStringLength := mload(sendData)
                let revertStringPtr := add(sendData, 0x20)
                revert(revertStringPtr, revertStringLength)
            }
        }

        assertEq(sent, true, "Failed to send Ether.");
        uint256 ethBalanceAfter = vm.addr(token_holder_priv_key).balance;
        console2.log("ethBalanceAfter: %d", ethBalanceAfter);
        uint256 divBalanceAfter = l1WdivETH.balanceOf(vm.addr(vm.envUint("TOKEN_HOLDER_PRIV_KEY")));
        console2.log("divBalanceAfter: %d", divBalanceAfter);
        vm.stopBroadcast();
    }
}
