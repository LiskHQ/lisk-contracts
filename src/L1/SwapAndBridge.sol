// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

/// @title SwapAndBridge
/// @notice SwapAndBridge is the utility contract that allows to swap ETH to a wrapped LST and bridge it to L2.
///         It is designed to be used as a part of the Lisk L2 ecosystem.
contract SwapAndBridge {
    /// @notice Minimum amount of gas to be used for the deposit message on L2.
    ///         This value is added to the base gas calculated by the CrossDomainMessenger contract.
    uint32 public constant MIN_DEPOSIT_GAS = 0;

    /// @notice The L1 bridge contract. This is configurable since not all tokens are bridged
    ///         using the standard bridge.
    IL1StandardBridge public immutable L1_BRIDGE;

    /// @notice The wrapped LST contract on L1.
    IERC20 public immutable L1_TOKEN;

    /// @notice Address of the wrapped LST on L2.
    address public immutable L2_TOKEN_ADDRESS;

    /// @notice Constructor
    /// @param _l1Bridge The L1 bridge contract address.
    /// @param _l1Token The wrapped LST contract address on L1.
    /// @param _l2Token The wrapped LST contract address on L2.
    constructor(address _l1Bridge, address _l1Token, address _l2Token) {
        require(_l1Bridge != address(0), "Invalid L1 bridge address.");
        require(_l1Token != address(0), "Invalid L1 token address.");
        require(_l2Token != address(0), "Invalid L2 token address.");
        L1_BRIDGE = IL1StandardBridge(_l1Bridge);
        L1_TOKEN = IERC20(_l1Token);
        L2_TOKEN_ADDRESS = _l2Token;
    }

    /// @notice Shortcut function to swap and bridge wrapped LST to the sender address on the L2.
    receive() external payable {
        swapAndBridgeTo(msg.sender);
    }

    /// @notice Swap ETH to wrapped LST and bridge it to the recipient address on the L2.
    ///         If the amount of l1 token obtained is less than minL1Tokens, the transaction will revert.
    /// @param recipient The address to bridge the wrapped LST to.
    /// @param minL1Tokens The minimum amount of L1 tokens to be obtained.
    function swapAndBridgeToWithMinimumAmount(address recipient, uint256 minL1Tokens) public payable {
        // Check that the swap is for a non-zero ETH amount.
        require(msg.value > 0, "Invalid msg value.");

        // Check recipient is not an invalid address.
        require(recipient != address(0), "Invalid recipient address.");

        // Send ETH and mint wrapped liquid token for SwapAndBridge contract.
        (bool sent,) = address(L1_TOKEN).call{ value: msg.value }("");
        require(sent, "Failed to send Ether.");

        // Get current balance of wrapped LST for this contract.
        // This value is at least the amount of wrapped LST minted,
        // but it could be larger if someone sent the LST to this contract.
        uint256 balance = L1_TOKEN.balanceOf(address(this));
        require(balance > 0, "No wrapped tokens minted.");

        // Ensure that the amount of L1 tokens minted is greater than the minimum required.
        // If minL1Tokens == 0, then no check is performed.
        if (minL1Tokens > 0) {
            require(balance >= minL1Tokens, "Insufficient L1 tokens minted.");
        }

        // Approve the L1 bridge to transfer the wrapped tokens to the L2.
        bool approved = L1_TOKEN.approve(address(L1_BRIDGE), balance);
        require(approved, "Failed to approve L1 token spender.");

        // Bridge wrapped tokens to L2.
        // We use depositERC20To rather than depositERC20 because the latter can only be called by EOA.
        L1_BRIDGE.depositERC20To(address(L1_TOKEN), L2_TOKEN_ADDRESS, recipient, balance, MIN_DEPOSIT_GAS, "0x");

        // Check that this contract has no tokens left in its balance.
        require(L1_TOKEN.balanceOf(address(this)) == 0, "Contract still has tokens.");
    }

    /// @notice Swap ETH to wrapped LST and bridge it to the recipient address on the L2.
    /// @param recipient The address to bridge the wrapped LST to.
    function swapAndBridgeTo(address recipient) public payable {
        swapAndBridgeToWithMinimumAmount(recipient, 0);
    }
}
