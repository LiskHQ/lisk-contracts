// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2, Vm } from "forge-std/Test.sol";
import { WstETH } from "src/L1/lido/WstETH.sol";
import { SwapAndBridge } from "src/L1/SwapAndBridge.sol";
import "script/Utils.sol";

/// @title IL1StandardBridge - L1 Standard Bridge interface
/// @notice This contract is used to transfer L1 Lisk tokens to the L2 network as L2 Lisk tokens.
interface IL1StandardBridge {
    /// Deposits L1 Lisk tokens into a target account on L2 network.
    /// @param _l1Token L1 Lisk token address.
    /// @param _l2Token L2 Lisk token address.
    /// @param _to Target account address on L2 network.
    /// @param _amount Amount of L1 Lisk tokens to be transferred.
    /// @param _minGasLimit Minimum gas limit for the deposit message on L2.
    /// @param _extraData Optional data to forward to L2. Data supplied here will not be used to
    ///                   execute any code on L2 and is only emitted as extra data for the
    ///                   convenience of off-chain tooling.
    function depositERC20To(
        address _l1Token,
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _minGasLimit,
        bytes calldata _extraData
    )
        external;

    function finalizeERC20Withdrawal(
        address _l1Token,
        address _l2Token,
        address _to,
        uint256 _amount,
        bytes calldata _data
    )
        external;
}

struct finalizeERC20WithdrawalData {
    bytes4 selector;
    // Because this call will be executed on the remote chain, we reverse the order of
    // the remote and local token addresses relative to their order in the
    // finalizeBridgeERC20 function.
    address remoteToken;
    address localToken;
    address from;
    address to;
    uint256 amount;
    bytes extraData;
}

// event SentMessage(address indexed target, address sender, bytes message, uint256 messageNonce, uint256 gasLimit);
event SentMessage(address indexed target, bytes data);

/// @title TestBridgingScript
/// @notice This contract is used to test bridging Lido tokens from L1 to L2 network.
contract TestBridgingScript is Test {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    // IL1StandardBridge l1bridge;

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
        // l1bridge = IL1StandardBridge(vm.envAddress("L1_STANDARD_BRIDGE_ADDR"));

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

        //entries[4] is the approve event
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

        //entries[5] is the transfer event from swapAndBridge to L1_LIDO_BRIDGE_ADDR
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

        // console2.log("Sender");
        // console2.log(sender);

        // console2.log("Message");
        // console2.logBytes(message);

        // console2.log("MessageNonce");
        // console2.log(messageNonce);

        // console2.log("GasLimit");
        // console2.log(gasLimit);

        // The message is encoded in a weird way: bytes 4 is packed, the addresses are not
        // Hence, we slice the message to remove the bytes4 selector.
        bytes memory selectorBytes = getSlice(1, 5, message);
        assertEq(bytes4(selectorBytes), bytes4(0x662a633a), "SentMessage: Invalid selector");

        bytes memory slicedMessage = getSlice(5, message.length, message);
        (address remoteToken, address localToken, address from, address to, uint256 amount, bytes memory extraData) =
            abi.decode(slicedMessage, (address, address, address, address, uint256, bytes));

        assertEq(remoteToken, vm.envAddress("L1_LIDO_TOKEN_ADDR"), "SentMessage: Invalid L1 token address");
        assertEq(localToken, vm.envAddress("L2_LIDO_TOKEN_ADDR"), "SentMessage: Invalid L2 token address");
        assertEq(from, address(swapAndBridgeLido), "SentMessage: Invalid sender address");
        assertEq(to, vm.addr(vm.envUint("TOKEN_HOLDER_PRIV_KEY")), "SentMessage: Invalid recipient address");
        assertEq(amount, 10000 ether, "SentMessage: Invalid amount");
    }

    function test_lido_L2() public {
        uint256 token_holder_priv_key = vm.envUint("TOKEN_HOLDER_PRIV_KEY");
        address token_holder_addr = vm.addr(token_holder_priv_key);

        console2.log("Finalizing transfer on L2 network...");

        uint256 balanceBefore = l2WstETH.balanceOf(token_holder_addr);

        vm.recordLogs();

        // Test bridging for Lido
        vm.startBroadcast(token_holder_priv_key);
        (bool sent,) = address(swapAndBridgeLido).call{ value: 10000 ether }("");
        assertEq(sent, true, "Failed to send Ether.");
        vm.stopBroadcast();

        uint256 balanceAfter = l2WstETH.balanceOf(token_holder_addr);
        console2.log("balanceBefore: %d", balanceBefore);
        console2.log("balanceAfter: %d", balanceAfter);
        // assertEq(balanceAfter - balanceBefore, 10000 ether);
    }
}
