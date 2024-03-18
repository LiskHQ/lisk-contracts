// SPDX-License-Identifier: GPL-3.0

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
    /// @notice Address of the L1 bridge contract. This is configurable since not all tokens are bridged sing the
    /// standard bridge.
    address public immutable L1_BRIDGE_ADDRESS;

    /// @notice Amount of gas to be used for the deposit message on L2.
    uint32 public DEPOSIT_GAS = 200000;

    /// @notice Address of the wrapped LST on L1.
    address public immutable L1_TOKEN;

    /// @notice Address of the wrapped LST on L2.
    address public immutable L2_TOKEN;

    IERC20 private L1_TOKEN_CONTRACT;
    IL1StandardBridge private L1_BRIDGE;

    constructor(address _BRIDGE_ADDRESS, address _l1Token, address _l2Token) {
        L1_BRIDGE_ADDRESS = _BRIDGE_ADDRESS;
        L1_TOKEN = _l1Token;
        L2_TOKEN = _l2Token;
        L1_TOKEN_CONTRACT = IERC20(L1_TOKEN);
        L1_BRIDGE = IL1StandardBridge(L1_BRIDGE_ADDRESS);
    }

    /// @notice Swap ETH to wrapped LST and bridge it to the recipient address on the L2.
    /// @param recipient The address to bridge the wrapped LST to.
    function swapAndBridgeTo(address recipient) public payable {
        // Check recipient is not an invalid address.
        require(recipient != address(0), "Invalid recipient address.");

        // Send ETH and mint wrapped liquid token for SwapAndBridge contract.
        (bool sent,) = L1_TOKEN.call{ value: msg.value }("");
        require(sent, "Failed to send Ether.");

        // Get current balance of wrapped LST for this contract.
        // We ensure at the end of the function that the contract balance is 0,
        // hence this is the amount of wrapped LST minted.
        uint256 balance = L1_TOKEN_CONTRACT.balanceOf(address(this));
        require(balance > 0, "No wrapped tokens minted.");

        // Approve the L1 bridge to transfer the wrapped tokens to the L2.
        L1_TOKEN_CONTRACT.approve(L1_BRIDGE_ADDRESS, balance);

        // Bridge wrapped tokens to L2.
        // We use depositERC20To rather than depositERC20 because the latter can only be called by EOA.
        L1_BRIDGE.depositERC20To(L1_TOKEN, L2_TOKEN, recipient, balance, DEPOSIT_GAS, "0x");

        // Check that this contract has no tokens left in its balance.
        require(L1_TOKEN_CONTRACT.balanceOf(address(this)) == 0, "Contract still has tokens.");
    }

    /// @notice Swap ETH to wrapped LST and bridge it to the sender address on the L2.
    function swapAndBridge() public payable {
        swapAndBridgeTo(msg.sender);
    }

    /// @notice Shortcut function to swap and bridge wrapped LST to the sender address on the L2.
    receive() external payable {
        swapAndBridgeTo(msg.sender);
    }
}
