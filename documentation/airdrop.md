# Lisk Migration Airdrop

## Overview

This page documents the Lisk Migration Airdrop that is implemented in the contract [L2Airdrop.sol](../src/L2/L2Airdrop.sol) and the corresponding deployment script [L2Airdrop.s.sol](../script/contracts/L2/L2Airdrop.s.sol). Further, the Merkle tree generator for the maximum airdrop amounts for each Lisk v4 address is implemented
[here](https://github.com/LiskHQ/lisk-token-claim/tree/main/packages/tree-builder/src/applications/generate-airdrop-merkle-tree).

The goal of the migration airdrop is to reward the community of the Lisk L1 network by airdropping LSK tokens proportionally to the migrated LSK amounts if the community members show activity and commitment to the new Lisk L2 via bridging assets, staking tokens and participating in onchain governance.

## Computation of the Airdrop Amount at Token Migration

We fix the value `MIGRATION_AIRDROP_PERCENTAGE` that is the percentage of the airdrop in relation to the account balance and this impacts how much will be distributed in the airdrop. The maximum airdrop amount in LSK that a Lisk v4 account owner can claim on the Lisk L2 is then given by:

- `lskBalance * MIGRATION_AIRDROP_PERCENTAGE / 100` for any account with `lskBalance >= 50 LSK` and `lskBalance <= 250,000 LSK`.
- `0` for any account with `lskBalance < 50 LSK` (cutoff amount).
- `250000 * MIGRATION_AIRDROP_PERCENTAGE / 100` for any account with `lskBalance > 250,000 LSK` (whale cap).

Moreover, certain addresses such as centralized exchanges and addresses controlled by the Onchain Foundation are excluded from the airdrop.

From the snapshot of all LSK balances at the token migration, the code [here](https://github.com/LiskHQ/lisk-token-claim/tree/main/packages/tree-builder/src/applications/generate-airdrop-merkle-tree) computes the maximum airdrop amount for every account and generates a Merkle root that authenticates the maximum airdrop amount for each address. This Merkle root is then set in the airdrop contract [L2Airdrop.sol](../src/L2/L2Airdrop.sol).

## Claiming the Airdrop

The maximum airdrop amounts are generated for Lisk v4 addresses. In order to claim the airdrop on Lisk L2, a user must complete the claims process to connect their old Lisk address with the new Lisk L2 address. The migration airdrop can only be received to the same L2 address that was used in the LSK claims process. If a user owns several Lisk addresses they would have to claim the airdrop separately for each address.

For each of the four conditions below that a user satisfies, they are eligible for 25 % of the maximum airdrop amount. For claiming, the user has to submit a Merkle proof authenticating the maximum airdrop amount for their address. The conditions are then checked onchain. The user can satisfy the conditions and claim the corresponding fraction of the maximum airdrop amount at different times.

- The user has currently bridged at least 0.01 ETH to the Lisk L2.
- The user has currently delegated their voting power in the Lisk DAO, either to themselves or a delegate.
- The user has currently staked 50% of the migrated LSK tokens for 1 month (Staking Tier 1).
- The user has currently staked 50% of the migrated LSK tokens for 6 month (Staking Tier 2).

## Owner

The owner address for the migration airdrop smart contract is assigned to the multisignature account controlled by the Security Council. The owner is authorized to set the Merkle root to commence the airdrop period.

Additionally, the owner has the authority to transfer unclaimed airdrop LSK tokens to a designated airdrop wallet once the airdrop period concludes.
