# Privilege Roles and Operations

## Overview

Inside Lisk smart contracts repository, there are some smart contracts that require a specific role to perform some operations. These roles are defined in the smart contract code of the contract that requires them. Usually, the only role that is required is the `owner` role, which is the role that is assigned to the account that deployed the contract. However, after the contract is deployed, the owner can transfer the ownership to another account which may even be a multisignature account.

Some smart contracts are upgradable, which means that the owner can upgrade the contract code to a new version. In this case, the `owner` role is required to perform the upgrade operation.

There are also additional actions that require the `owner` role, like setting a DAO treasury address inside some contracts, add or remove `creator`, fund staking rewards, set emergency exit, etc.

## Privilege Roles

The following are the privilege roles that are defined in the smart contracts:

- `owner`: The account that owns the contract. This account has the highest level of privilege and can perform all critical operations like upgrading the contract, setting DAO treasury address, setting emergency exit, etc. The owner of deployed smart contracts is a `Security council`. This is a multisignature account that requires the approval of the majority of the members to perform any operation. The multisignature account is controlled by different parties, which ensures that no single party has full control over the contract.
- `burner`: The account that is allowed to burn LSK tokens.
- `creator`: The account (smart contract) which is allowed to lock LSK tokens and manipulate with them on behalf of the users inside [L2StakingContract](../src/L2/L2Staking.sol) smart contract. A security assumption is that the `creator` is a trusted smart contract that will not misuse the locked LSK tokens.

## Smart Contracts and Their Privilege Roles

The following are the smart contracts that have privilege roles defined in their code:

- [L1LiskToken.sol](../src/L1/L1LiskToken.sol): This contract has the `owner` and `burner` roles defined. The `owner` role is required to add or remove the `burner` role to and from an account. The `burner` role is required to burn LSK tokens.

- [L2Claim.sol](../src/L2/L2Claim.sol): This contract has the `owner` role defined. The `owner` role is required to upgrade the contract, set DAO treasury address and execute `recoverLSK()` function which is used to recover unclaimed LSK tokens to the DAO address after the claim period is over.

- [L2Governor.sol](../src/L2/L2Governor.sol): This contract has the `owner` role defined. The `owner` role is required to upgrade the contract.

- [L2LockingPosition.sol](../src/L2/L2LockingPosition.sol): This contract has the `owner` role defined. The `owner` role is required to upgrade the contract and set [L2VotingPower](../src/L2/L2VotingPower.sol) smart contract address inside this contract.

- [L2Reward.sol](../src/L2/L2Reward.sol): This contract has the `owner` role defined. The `owner` role is required to upgrade the contract, set [L2LockingPosition](../src/L2/L2LockingPosition.sol) and [L2Staking](../src/L2/L2Staking.sol) smart contracts addresses inside this contract and execute functions:
    - `addUnusedRewards`: Redistributes unused rewards.
    - `fundStakingRewards`: Adds new daily rewards between provided duration.

- [L2Staking.sol](../src/L2/L2Staking.sol): This contract has the `owner` and `creator` roles defined. The `owner` role is required to upgrade the contract, set [L2LockingPosition](../src/L2/L2LockingPosition.sol) and DAO treasury addresses inside this contract, set emergency exit and add or remove `creator`. The `creator` role is allowed to lock LSK tokens and manipulate with them on behalf of the users inside this smart contract.

- [L2VestingWallet.sol](../src/L2/L2VestingWallet.sol): This contract has the `owner` role defined. The `owner` role is required to upgrade the contract.

- [L2VotingPower.sol](../src/L2/L2VotingPower.sol): This contract has the `owner` role defined. The `owner` role is required to upgrade the contract.

## Operations and Their Required Roles

The following are the operations that are defined in the smart contracts and the roles that are required to perform them:

- `Upgrade Smart Contract`: The `owner` role is required to upgrade the contract code to a new version.
- `Set DAO Treasury Address`: The `owner` role is required to set the DAO treasury address inside the contract.
- `Set Address to Another Contract`: The `owner` role is required to set the address of another contract inside the contract.
- `Set Emergency Exit`: The `owner` role is required to set the emergency exit inside the [L2Staking](../src/L2/L2Staking.sol) smart contract.
- `Add or Remove Burner`: The `owner` role is required to add or remove the `burner` role to and from an account inside the [L1LiskToken](../src/L1/L1LiskToken.sol) smart contract.
- `Add or Remove Creator`: The `owner` role is required to add or remove `creator` inside the [L2Staking](../src/L2/L2Staking.sol) smart contract.
- `Fund Staking Rewards`: The `owner` role is required to fund staking rewards inside the [L2Reward](../src/L2/L2Reward.sol) smart contract.
- `Add Unused Rewards`: The `owner` role is required to execute `addUnusedRewards()` function inside the [L2Reward](../src/L2/L2Reward.sol) smart contract.
- `Recover LSK`: The `owner` role is required to execute `recoverLSK()` function inside the [L2Claim](../src/L2/L2Claim.sol) smart contract.
- `Burn LSK`: The `burner` role is required to burn LSK tokens inside the [L1LiskToken](../src/L1/L1LiskToken.sol) smart contract.

## Upgrading Smart Contracts

Smart contracts that are upgradable can be upgraded to a new version by the `owner` role.

All upgradable smart contracts are using the `Proxy` pattern to upgrade the contract code to a new version. The `Proxy` pattern is a design pattern that allows a contract to delegate all calls to another contract. This pattern is used to upgrade the contract code to a new version without losing the state of the contract and without changing the address of the contract.

The process of upgrading a smart contract is as follows:

1. The new version of the smart contract is deployed to the network.
2. The `owner` role of the old version of the smart contract executes the `upgradeToAndCall()` function of the `Proxy` contract and passes the address of the new version of the smart contract as an argument besides the data that is required to initialize the new version of the smart contract.
3. The new version of the smart contract is now active and the old version of the smart contract is no longer used.
4. The `owner` role of the new version of the smart contract can now perform all operations that are defined in the new version of the smart contract.

The main reasons why smart contracts upgrade will be required are:

- Fixing bugs
- Adding new features (proposed by the community)
- Enhancing security

**It is important to note that the upgrade process will be transparent and the users of the smart contracts will be always in advance informed about the upgrade process and the reasons behind it.**
