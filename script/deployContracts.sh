#!/usr/bin/env bash

echo "Instructing the shell to exit immediately if any command returns a non-zero exit status..."
set -e
echo "Done."

echo "Navigating to the root directory of the project..."
cd ../
echo "Done."

echo "Removing files inside deployment directory if they exists..."
rm -f deployment/*
echo "Done."

echo "Setting environment variables..."
source .env
echo "Done."

echo "Deploying L1LiskToken smart contract..."
if [ -z "$L1_ETHERSCAN_API_KEY" ]
then
      forge script --rpc-url="$L1_RPC_URL" --broadcast -vvvv script/L1LiskToken.s.sol:L1LiskTokenScript
else
      forge script --rpc-url="$L1_RPC_URL" --broadcast --verify --etherscan-api-key="$L1_ETHERSCAN_API_KEY" -vvvv script/L1LiskToken.s.sol:L1LiskTokenScript
fi
echo "Done."

echo "Deploying L2LiskToken smart contract..."
if [ -z "$L2_ETHERSCAN_API_KEY" ]
then
forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/L2LiskToken.s.sol:L2LiskTokenScript
else
forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --etherscan-api-key="$L2_ETHERSCAN_API_KEY" -vvvv script/L2LiskToken.s.sol:L2LiskTokenScript
fi
echo "Done."

echo "Deploying L2Claim smart contract..."
if [ -z "$L2_ETHERSCAN_API_KEY" ]
then
forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/L2Claim.s.sol:L2ClaimScript
else
forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --etherscan-api-key="$L2_ETHERSCAN_API_KEY" -vvvv script/L2Claim.s.sol:L2ClaimScript
fi
echo "Done."

echo "Transferring funds to L1 and L2 addresses and L2Claim smart contract..."
forge script --rpc-url="$L1_RPC_URL" --broadcast -vvvv script/TransferFunds.s.sol:TransferFundsScript
echo "Done."
