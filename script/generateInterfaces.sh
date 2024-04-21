#!/usr/bin/env bash

echo "Instructing the shell to exit immediately if any command returns a non-zero exit status..."
set -e
echo "Done."

INTERFACE_L1_DIR="../src/interfaces/L1"
INTERFACE_L2_DIR="../src/interfaces/L2"

echo "Generating interface for L1LiskToken smart contract..."
cast interface -o $INTERFACE_L1_DIR/IL1LiskToken.sol -n IL1LiskToken .././out/L1LiskToken.sol/L1LiskToken.json
echo "Done."

echo "Generating interface for L2LiskToken smart contract..."
cast interface -o $INTERFACE_L2_DIR/IL2LiskToken.sol -n IL2LiskToken .././out/L2LiskToken.sol/L2LiskToken.json
echo "Done."

echo "Generating interface for L2Claim smart contract..."
cast interface -o $INTERFACE_L2_DIR/IL2Claim.sol -n IL2Claim .././out/L2Claim.sol/L2Claim.json
echo "Done."

echo "Generating interface for L2VotingPower smart contract..."
cast interface -o $INTERFACE_L2_DIR/IL2VotingPower.sol -n IL2VotingPower .././out/L2VotingPower.sol/L2VotingPower.json
echo "Done."

echo "Generating interface for L2Governor smart contract..."
cast interface -o $INTERFACE_L2_DIR/IL2Governor.sol -n IL2Governor .././out/L2Governor.sol/L2Governor.json
echo "Done."

echo "Generating interface for L2LockingPosition smart contract..."
cast interface -o $INTERFACE_L2_DIR/IL2LockingPosition.sol -n IL2LockingPosition .././out/L2LockingPosition.sol/L2LockingPosition.json
echo "Done."

echo "Generating interface for L2Staking smart contract..."
cast interface -o $INTERFACE_L2_DIR/IL2Staking.sol -n IL2Staking .././out/L2Staking.sol/L2Staking.json
echo "Done."

echo "Generating interface for L2VestingWallet smart contract..."
cast interface -o $INTERFACE_L2_DIR/IL2VestingWallet.sol -n IL2VestingWallet .././out/L2VestingWallet.sol/L2VestingWallet.json
echo "Done."
