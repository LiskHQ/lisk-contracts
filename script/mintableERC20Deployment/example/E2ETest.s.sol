// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { Vm } from "forge-std/Vm.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title IL1StandardBridge - L1 Standard Bridge interface
/// @notice This contract is used to transfer L1 tokens to the L2 network as L2 tokens.
interface IL1StandardBridge {
    /// Deposits L1 Lisk tokens into a target account on L2 network.
    /// @param _l1Token L1 token address.
    /// @param _l2Token L2 token address.
    /// @param _to Target account address on L2 network.
    /// @param _amount Amount of L1 tokens to be transferred.
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
}

/// @title IL2StandardBridge - L2 Standard Bridge interface
/// @notice This contract is used to transfer L2 tokens to the L1 network as L1 tokens.
interface IL2StandardBridge {
    /// @notice Initiates a withdrawal from L2 to L1 to a target account on L1.
    ///         Note that if ETH is sent to a contract on L1 and the call fails, then that ETH will
    ///         be locked in the L1StandardBridge. ETH may be recoverable if the call can be
    ///         successfully replayed by increasing the amount of gas supplied to the call. If the
    ///         call will fail for any amount of gas, then the ETH will be locked permanently.
    ///         This function only works with OptimismMintableERC20 tokens or ether. Use the
    ///         `bridgeERC20To` function to bridge native L2 tokens to L1.
    ///         Subject to be deprecated in the future.
    /// @param _l2Token     Address of the L2 token to withdraw.
    /// @param _to          Recipient account on L1.
    /// @param _amount      Amount of the L2 token to withdraw.
    /// @param _minGasLimit Minimum gas limit to use for the transaction.
    /// @param _extraData   Extra data attached to the withdrawal.
    function withdrawTo(
        address _l2Token,
        address _to,
        uint256 _amount,
        uint32 _minGasLimit,
        bytes calldata _extraData
    )
        external;
}

/// @title ICrossDomainMessenger - L2 Cross Domain Messenger interface
/// @notice This contract is used to relay messages from L1 to L2 network.
interface ICrossDomainMessenger {
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

// event SentMessage(address indexed target, address sender, bytes message, uint256 messageNonce, uint256 gasLimit);
event SentMessage(address indexed target, bytes data);

/// @title TestL1DepositScript
/// @notice This contract is used to test depositing tokens from L1 to L2 network.
///         This contract runs the L1 part of it.
contract TestL1DepositScript is Script, StdCheats {
    // Address used for E2E tests
    address constant testAccount = address(0xc0ffee);

    // L1 address of the Lisk standard bridge on Sepolia L1
    address constant L1_BRIDGE_ADDR = 0x1Fb30e446eA791cd1f011675E5F3f5311b70faF5;

    // L2 address of the Lisk Sepolia standard bridge
    address constant L2_BRIDGE_ADDR = 0x4200000000000000000000000000000000000010;

    // The L1 standard bridge
    IL1StandardBridge l1Bridge;

    // The test value to be bridged
    uint256 constant TEST_AMOUNT = 5 ether;

    function getSlice(uint256 begin, uint256 end, bytes memory text) private pure returns (bytes memory) {
        bytes memory a = new bytes(end - begin + 1);
        for (uint256 i = 0; i <= end - begin; i++) {
            a[i] = bytes(text)[i + begin - 1];
        }
        return a;
    }

    function setUp() public {
        l1Bridge = IL1StandardBridge(L1_BRIDGE_ADDR);
    }

    function run(address l1TokenAddress, address l2TokenAddress) public {
        ERC20 l1Token = ERC20(l1TokenAddress);
        deal(l1TokenAddress, testAccount, 50 ether, true);

        console2.log("Token holder address: %s", testAccount);
        console2.log("Token holder balance:", l1Token.balanceOf(testAccount));
        console2.log("Transferring", l1Token.name(), "tokens from L1 to L2 network...");

        vm.recordLogs();
        vm.startPrank(testAccount);
        l1Token.approve(address(l1Bridge), TEST_AMOUNT);
        l1Bridge.depositERC20To(l1TokenAddress, l2TokenAddress, testAccount, TEST_AMOUNT, 0, "0x");
        vm.stopPrank();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 8, "Invalid number of logs");

        require(
            logs[6].topics[1] == bytes32(uint256(uint160(L2_BRIDGE_ADDR))), "SentMessage: Invalid target address topic"
        );

        (address sender, bytes memory message, uint256 messageNonce, uint256 gasLimit) =
            abi.decode(logs[6].data, (address, bytes, uint256, uint256));
        require(sender == L1_BRIDGE_ADDR, "SentMessage: Invalid sender address");

        // The message is encoded in a weird way: bytes 4 is packed, the addresses are not
        // Hence, we slice the message to remove the bytes4 selector.
        bytes memory selectorBytes = getSlice(1, 5, message);
        require(
            bytes4(selectorBytes)
                == bytes4(keccak256("finalizeBridgeERC20(address,address,address,address,uint256,bytes)")),
            "SentMessage: Invalid selector"
        );

        bytes memory slicedMessage = getSlice(5, message.length, message);
        (address localToken, address remoteToken, address from, address to, uint256 amount, bytes memory extraData) =
            abi.decode(slicedMessage, (address, address, address, address, uint256, bytes));

        require(remoteToken == l1TokenAddress, "SentMessage: Invalid L1 token address");
        require(localToken == l2TokenAddress, "SentMessage: Invalid L2 token address");
        require(from == testAccount, "SentMessage: Invalid sender address");
        require(to == testAccount, "SentMessage: Invalid recipient address");
        require(amount == TEST_AMOUNT, "SentMessage: Invalid amount");
        require(extraData.length == 2, "SentMessage: Invalid extra data");

        bytes memory data = abi.encode(sender, L2_BRIDGE_ADDR, message, messageNonce, gasLimit);
        console2.log("Transfer completed. Piping data: ");
        console2.logBytes(data);
    }
}

/// @title TestL2DepositScript
/// @notice This contract is used to test depositing tokens from L1 to L2 network.
///         This contract runs the L2 part of it.
contract TestL2DepositScript is Script {
    // The L2 crossi domain messenger contract
    ICrossDomainMessenger l2Messenger;

    // Address used for E2E tests
    address testAccount;

    // The test value to be bridged
    uint256 constant TEST_AMOUNT = 5 ether;

    // L2 Cross Domain Messenger address
    address constant L2_CROSS_DOMAIN_MESSENGER_ADDR = 0x4200000000000000000000000000000000000007;

    // L2 sequencer address (this is the Lisk Sepolia Sequencer address)
    address constant SEQUENCER_ADDR = 0x968924E6234f7733eCA4E9a76804fD1afA1a4B3D;

    function setUp() public {
        l2Messenger = ICrossDomainMessenger(L2_CROSS_DOMAIN_MESSENGER_ADDR);
        testAccount = address(0xc0ffee);
    }

    function run(address l2TokenAddress, bytes memory data) public {
        ERC20 l2Token = ERC20(l2TokenAddress);
        (address payable sender, address payable target, bytes memory message, uint256 messageNonce, uint256 gasLimit) =
            abi.decode(data, (address, address, bytes, uint256, uint256));

        uint256 balanceBefore = l2Token.balanceOf(testAccount);

        vm.startBroadcast(SEQUENCER_ADDR);
        console2.log("Relaying message to L2 network...");
        l2Messenger.relayMessage(messageNonce, sender, target, 0, gasLimit, message);
        vm.stopPrank();

        uint256 balanceAfter = l2Token.balanceOf(testAccount);
        console2.log("balanceBefore: %d", balanceBefore);
        console2.log("balanceAfter: %d", balanceAfter);
        require(balanceAfter - balanceBefore == TEST_AMOUNT, "Invalid new balance.");
    }
}

/// @title TestL2WithdrawalScript
/// @notice This contract is used to test withdrawing tokens from L2 to L1 network.
///         This contract runs the L2 part of it.
contract TestL2WithdrawalScript is Script, StdCheats {
    // Address used for E2E tests
    address constant testAccount = address(0xc0ffee);

    // L1 address of the Lisk standard bridge on Sepolia L1
    address constant L1_BRIDGE_ADDR = 0x1Fb30e446eA791cd1f011675E5F3f5311b70faF5;

    // L2 address of the Lisk Sepolia standard bridge
    address constant L2_BRIDGE_ADDR = 0x4200000000000000000000000000000000000010;

    // The L2 standard bridge
    IL2StandardBridge l2Bridge;

    // The test value to be bridged
    uint256 constant TEST_AMOUNT = 5 ether;

    function getSlice(uint256 begin, uint256 end, bytes memory text) private pure returns (bytes memory) {
        bytes memory a = new bytes(end - begin + 1);
        for (uint256 i = 0; i <= end - begin; i++) {
            a[i] = bytes(text)[i + begin - 1];
        }
        return a;
    }

    function setUp() public {
        l2Bridge = IL2StandardBridge(L2_BRIDGE_ADDR);
    }

    function run(address l2TokenAddress, address l1TokenAddress) public {
        ERC20 l2Token = ERC20(l2TokenAddress);
        // deal(l2TokenAddress, testAccount, 500000 ether, true);

        console2.log("Token holder address: %s", testAccount);
        console2.log("Transferring", l2Token.name(), "tokens from L2 to L1 network...");

        vm.recordLogs();
        vm.startPrank(testAccount);
        l2Token.approve(address(l2Bridge), TEST_AMOUNT);
        l2Bridge.withdrawTo(l2TokenAddress, testAccount, TEST_AMOUNT, 0, "0x");
        vm.stopPrank();

        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 8, "Invalid number of logs");

        require(
            logs[6].topics[1] == bytes32(uint256(uint160(L1_BRIDGE_ADDR))), "SentMessage: Invalid target address topic"
        );

        (address sender, bytes memory message, uint256 messageNonce, uint256 gasLimit) =
            abi.decode(logs[6].data, (address, bytes, uint256, uint256));
        require(sender == L2_BRIDGE_ADDR, "SentMessage: Invalid sender address");

        // The message is encoded in a weird way: bytes 4 is packed, the addresses are not
        // Hence, we slice the message to remove the bytes4 selector.
        bytes memory selectorBytes = getSlice(1, 5, message);
        require(
            bytes4(selectorBytes)
                == bytes4(keccak256("finalizeBridgeERC20(address,address,address,address,uint256,bytes)")),
            "SentMessage: Invalid selector"
        );

        bytes memory slicedMessage = getSlice(5, message.length, message);
        (address localToken, address remoteToken, address from, address to, uint256 amount, bytes memory extraData) =
            abi.decode(slicedMessage, (address, address, address, address, uint256, bytes));

        require(remoteToken == l2TokenAddress, "SentMessage: Invalid L2 token address");
        require(localToken == l1TokenAddress, "SentMessage: Invalid L1 token address");
        require(from == testAccount, "SentMessage: Invalid sender address");
        require(to == testAccount, "SentMessage: Invalid recipient address");
        require(amount == TEST_AMOUNT, "SentMessage: Invalid amount");
        require(extraData.length == 2, "SentMessage: Invalid extra data");

        bytes memory data = abi.encode(sender, L1_BRIDGE_ADDR, message, messageNonce, gasLimit);
        console2.log("Transfer completed. Piping data: ");
        console2.logBytes(data);
    }
}

/// @title TestL1WithdrawalScript
/// @notice This contract is used to test withdrawing tokens from L2 to L1 network.
///         This contract runs the L12 part of it.
contract TestL1WithdrawalScript is Script {
    // The L1 crossi domain messenger contract
    ICrossDomainMessenger l1Messenger;

    // Address used for E2E tests
    address testAccount;

    // The test value to be bridged
    uint256 constant TEST_AMOUNT = 5 ether;

    // L2 Cross Domain Messenger address
    address constant L1_CROSS_DOMAIN_MESSENGER_ADDR = 0x857824E6234f7733ecA4e9A76804fd1afa1A3A2C;

    // L2 sequencer address (this is the Lisk Sepolia Sequencer address)
    address constant SEQUENCER_ADDR = 0x968924E6234f7733eCA4E9a76804fD1afA1a4B3D;

    function setUp() public {
        l1Messenger = ICrossDomainMessenger(L1_CROSS_DOMAIN_MESSENGER_ADDR);
        testAccount = address(0xc0ffee);
    }

    function run(address l1TokenAddress, bytes memory data) public {
        ERC20 l1Token = ERC20(l1TokenAddress);
        (address payable sender, address payable target, bytes memory message, uint256 messageNonce, uint256 gasLimit) =
            abi.decode(data, (address, address, bytes, uint256, uint256));

        uint256 balanceBefore = l1Token.balanceOf(testAccount);

        vm.startBroadcast(SEQUENCER_ADDR);
        console2.log("Relaying message to L2 network...");
        l1Messenger.relayMessage(messageNonce, sender, target, 0, gasLimit, message);
        vm.stopPrank();

        uint256 balanceAfter = l1Token.balanceOf(testAccount);
        console2.log("balanceBefore: %d", balanceBefore);
        console2.log("balanceAfter: %d", balanceAfter);
        require(balanceAfter - balanceBefore == TEST_AMOUNT, "Invalid new balance.");
    }
}
