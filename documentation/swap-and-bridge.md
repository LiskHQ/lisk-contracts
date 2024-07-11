# Overview of the swap-and-bridge feature

The swap-and-bridge feature allows users to swap ETH for an ERC20 Liquid Staking Token (LST) and to bridge it directly to an L2 with a single user interaction. This is achieved by implementing the `SwapAndBridge` contract, handling both conversion and bridging. For better integrating the LST with user interfaces, the contract swaps ETH for the wrapped version of it, that can always be converted back to the underlying LST.

## Motivation

Liquid staking pools allow users to participate in ETH staking without managing their own validator node or owning the full 32 ETH deposit amount. ETH from several users is pooled together and used to register a validator which then shares the rewards with the users. A Liquid Staking Token is an ERC20 token representing one of these staking positions. As such, it can be converted back to ETH, while at the same time being freely tradable as an independent token. Furthermore, this token provides the extra yield from the validators reward either by rebasing, i.e. changing the user balance to account for the extra tokens acquired, or, in their wrapped version, by changing the underlying conversion rate to ETH.

The swap-and-bridge feature prefers to interact with the wrapped version of a LST, as this tends to be better supported on the UX of several DeFi protocols (see the discussion for Lido's [wstETH](https://docs.lido.fi/contracts/wsteth/#why-use-wsteth)) and since the Optimism standard bridge [does not support rebasing tokens correctly](https://docs.optimism.io/builders/app-developers/bridging/standard-bridge).

A similar result for the end-user (swapping L1 ETH for L2 wrapped LST with a single interaction) can be achieved by using one of the several bridges available. However, this flow likely offers better security guarantees by relying on the L1<-->L2 bridging protocol and also stakes the ETH in the underlying staking pool protocol. Because of this, it should be considered an alternative option to stimulate participation in ETH staking.

## Rationale

Each `SwapAndBridge` contract supports a single wrapped LST, hence for each wrapped LST one wishes to support, a different `SwapAndBridge` contract needs to be deployed. We specified the contract to be as compatible as possible with a wide range of protocols. The minimum requirements are that the LST contract exposes the `receive` fallback to perform the staking and conversion of ETH to LST.

The `SwapAndBridge` contract itself uses the `receive` fallback as a shortcut to the the swap-and-bridge flow, so that users can send ETH to the contract and receive L2 LST directly.

The `SwapAndBridge` contract does not include any special role such as contract 'owner' and should not hold any ETH balance, with the notable exception of being the [target of a self-destructing contract](https://solidity-by-example.org/hacks/self-destruct/). Even in this case though, no one is able to extract the ETH balance of the contract. This means that, while no privileged operation can be executed on the contract in case of an emergency (like pausing it), no funds are at risk.

This repository does not include any UI-related code.

## Incident response plan

Because no special role is assigned and since we do not deploy any user-facing interface, there are no concrete steps that we can take in case of an emergency. As explained above though, the range of problems that can occur is quite limited:

- If a bug is present in the contract, users can lose at most the amount of ETH sent to perform the swap-and-bridge operation;
- The contract does not hold any mutable property, so the range of possible interactions that could result in a malicious state is limited.

## Specifications

### Constructor

The `SwapAndBridge` contract accepts the following parameters in its contructor:

- `address _l1Bridge`: The address of the L1 bridge contract used to transfer the tokens from the L1 to the L2. This bridge must implement the `depositERC20To` function. See, for instance, the [Optimism `L1StandardBridge` contract](https://github.com/ethereum-optimism/optimism/blob/op-contracts/v1.5.0/packages/contracts-bedrock/src/L1/L1StandardBridge.sol) or the [Lido `IL1ERC20Bridge` interface](https://github.com/lidofinance/lido-l2/blob/main/contracts/optimism/interfaces/IL1ERC20Bridge.sol);
- `address _l1Token`: The address of the L1 LST contract. This contract must implement the `receive` fallback to exchange the ETH sent with the transaction for the underlying LST. See, for instance, the [Lido `WstETH` contract](https://github.com/lidofinance/lido-dao/blob/master/contracts/0.6.12/WstETH.sol#L80) and [relative documentation](https://docs.lido.fi/contracts/wsteth/#staking-shortcut);
- `address _l2Token`: The address of the L2 LST contract. There are no particular restrictions on this contract apart from the usual bridging rules that depend on the bridge used. For instance, the standard bridge and the [`OptimismMintableERC20` standard](https://github.com/ethereum-optimism/optimism/blob/op-contracts/v1.5.0/packages/contracts-bedrock/src/universal/OptimismMintableERC20.sol) requires that this contract specifies `_l1Token` as the relative `REMOTE_TOKEN`.

### Public functions

The `SwapAndBridge` contract exposes the following public/external functions:

- `receive() external payable`: Convenience function allowing users to interact with the contract just by sending ETH. It redirects to `swapAndBridgeTo(msg.sender)`;
- `swapAndBridgeTo(address recipient) public payable`: Convenience function to swap ETH for LST without specifying the minimum amount of LST to be received. It redirects to `swapAndBridgeToWithMinimumAmount(recipient, 0)`;
- `swapAndBridgeToWithMinimumAmount(address recipient, uint256 minL1Tokens) public payable`: The core function performing boht ETH-->LST conversion (by sending ETH to the LST contract) and the L1 LST-->L2 LST bridging (by calling the bridge contract `depositERC20To` function). Several checks are included to ensure that the conversion is succesfull. It is possible to specify a `uint256 minL1Tokens` value larger than 0, in which case the contract will also check that swap resulted in an amount of LST larger than the specified minimum. A value of 0 passed to this function skips this check, allowing for any (non-zero) value to be accepted.

## Integrations

In this repository, we add integration tests and deployment scripts for two concrete liquid staking protocols: [Lido](https://lido.fi/) and [Diva](https://divastaking.com/).

The Diva deployment uses the Op-stack standard bridge as any other ERC20 token. The L2 LST contract can be deployed by running the `7_deployWdivETHContract.sh` script located in the parent folder.

The Lido deployment uses a custom bridge developed to deploy the Lido LST on L2s, as explained and specified in the [lido-l2 repository](https://github.com/lidofinance/lido-l2/tree/main). Because of this, the deployment of the Lido custom bridge and Lido L2 LST token are not part of this repository.
