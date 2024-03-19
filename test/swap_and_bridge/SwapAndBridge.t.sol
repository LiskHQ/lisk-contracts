// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2, Vm } from "forge-std/Test.sol";
import "forge-std/StdJson.sol";

using stdJson for string;

import { WstETH } from "src/L1/lido/WstETH.sol";
import { SwapAndBridge } from "src/L1/SwapAndBridge.sol";
import "script/Utils.sol";

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

struct BridgeData {
    address sender;
    address target;
    bytes message;
    uint256 messageNonce;
    uint256 gasLimit;
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
    WstETH l1WstETH;
    WstETH l2WstETH;

    function getSlice(uint256 begin, uint256 end, bytes memory text) public pure returns (bytes memory) {
        bytes memory a = new bytes(end - begin + 1);
        for (uint256 i = 0; i <= end - begin; i++) {
            a[i] = bytes(text)[i + begin - 1];
        }
        return a;
    }

    function setUp() public {
        utils = new Utils();
        vm.setNonce(vm.addr(vm.envUint("PRIVATE_KEY")), 1234);

        l2Messenger = IL2CrossDomainMessenger(vm.envAddress("L2_CROSS_DOMAIN_MESSENGER_ADDR"));

        swapAndBridgeLido = new SwapAndBridge(
            vm.envAddress("L1_LIDO_BRIDGE_ADDR"),
            vm.envAddress("L1_LIDO_TOKEN_ADDR"),
            vm.envAddress("L2_LIDO_TOKEN_ADDR")
        );

        l1WstETH = WstETH(payable(vm.envAddress("L1_LIDO_TOKEN_ADDR")));
        l2WstETH = WstETH(payable(vm.envAddress("L2_LIDO_TOKEN_ADDR")));

        console2.log("L1_LIDO_BRIDGE_ADDR: %s", vm.envAddress("L1_LIDO_BRIDGE_ADDR"));
        console2.log("L1_LIDO_TOKEN_ADDR: %s", vm.envAddress("L1_LIDO_TOKEN_ADDR"));
        console2.log("L2_LIDO_TOKEN_ADDR: %s", vm.envAddress("L2_LIDO_TOKEN_ADDR"));
        console2.log("SwapAndBridge (Lido) address: %s", address(swapAndBridgeLido));
    }

    function test_lido_L1() public {
        uint256 token_holder_priv_key = vm.envUint("TOKEN_HOLDER_PRIV_KEY");
        vm.setNonce(vm.addr(token_holder_priv_key), 1234);
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
        assertEq(gasLimit, 200000, "SentMessage: Invalid gas limit");

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
        console2.log("Saved JSON: %s", json);
        vm.writeJson(json, string.concat(vm.projectRoot(), "/test/data/swap_and_bridge_data_l1.json"));

        bytes memory data = abi.encode(sender, vm.envAddress("L2_LIDO_BRIDGE_ADDR"), message, messageNonce, gasLimit);
        vm.writeFileBinary(string.concat(vm.projectRoot(), "/test/data/swap_and_bridge_data_l1.data"), data);
    }

    function test_lido_L2() public {
        address sequencer = vm.envAddress("SEQUENCER_ADDR");

        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/test/data/swap_and_bridge_data_l1.json");
        console2.log("Reading JSON from path: %s", path);
        string memory json = vm.readFile(path);
        console2.log("Loaded JSON: %s", json);

        bytes memory data = vm.readFileBinary(string.concat(root, "/test/data/swap_and_bridge_data_l1.data"));
        (address payable sender, address payable target, bytes memory message, uint256 messageNonce, uint256 gasLimit) =
            abi.decode(data, (address, address, bytes, uint256, uint256));

        uint256 balanceBefore = l2WstETH.balanceOf(vm.addr(vm.envUint("TOKEN_HOLDER_PRIV_KEY")));

        vm.recordLogs();

        vm.startBroadcast(sequencer);
        // vm.prank(sequencer);
        console2.log("Relaying message to L2 network...");
        l2Messenger.relayMessage(messageNonce, sender, target, 0, gasLimit, message);
        vm.stopBroadcast();

        uint256 balanceAfter = l2WstETH.balanceOf(vm.addr(vm.envUint("TOKEN_HOLDER_PRIV_KEY")));
        console2.log("balanceBefore: %d", balanceBefore);
        console2.log("balanceAfter: %d", balanceAfter);
        assertEq(balanceAfter - balanceBefore, 10000 ether);
    }
}
