# Lisk Migration Airdrop

## Overview

This page documents the Lisk Migration Airdrop that is implemented in the contract [L2Airdrop.sol](../src/L2/L2Airdrop.sol) and the corresponding deployment script [L2Airdrop.s.sol](script/L2Airdrop.s.sol). Further, the Merkle tree generator for the maximum airdrop amounts for each addresses is implemented 
[here](https://github.com/LiskHQ/lisk-token-claim/tree/main/packages/tree-builder/src/applications/generate-airdrop-merkle-tree).

The goal of the migration airdrop is to reward the existing Lisk community by airdropping LSK tokens proportionally to the migrated LSK amounts if the community members show activity and commitment to the new Lisk L2 via bridging assets, staking tokens and participating in onchain governance. 

## Computation of the Airdrop Amount at Token Migration

Depending on the total amount of LSK distributed in the migration airdrop and the LSK token distribution at migration, we compute a value `MIGRATION_AIRDROP_PERCENTAGE` that is the desired percentage of the airdrop in relation to the account balance. The maximum airdrop amount in LSK that an account on the Lisk L2 can claim is then given by:

- `lskBalance * MIGRATION_AIRDROP_PERCENTAGE / 100` for any account with `lskBalance >= 50 LSK` and `lskBalance <= 250,000 LSK`.
- `0` for any account with `lskBalance < 50 LSK`.
- `250000 * MIGRATION_AIRDROP_PERCENTAGE / 100` for any account with `lskBalance > 250,000 LSK`.

Moreover, certain addresses such as centralized exchanges and addresses controlled by the Onchain Foundation are excluded from the airdrop.

From the snapshot of all LSK balances at the token migration, we compute the maximum airdrop amount for every account and compute a Merkle root that authenticates the maximum airdrop amount for each address. This Merkle root is then set in the airdrop contract [L2Airdrop.sol](../src/L2/L2Airdrop.sol).

## Claiming the Airdrop 

For each of the four conditions below that a user satisfies, they are eligible for 25 % of the maximum airdrop amount. For claiming, the user has to submit a Merkle proof authenticating the maximum airdrop amount for their address. The conditions are then checked onchain. The user can satisfy the conditions and claim the corresponding fraction of the maximum airdrop amount at different times.

- The user has currently bridged at least 0.01 ETH to the Lisk L2.
- The user has currently delegated their voting power in the Lisk DAO, either to themselves or a delegate.
- The user has currently staked 5 times the maximum airdrop amount for 1 month (Staking Tier 1).
- The user has currently staked 5 times the maximum airdrop amount for 6 month (Staking Tier 2).

## Owner and Contract Upgrades


