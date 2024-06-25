#!/usr/bin/env bash

echo "*** This script should only run at DEVNET ***"

echo "Instructing the shell to exit immediately if any command returns a non-zero exit status..."
set -e
echo "Done."

echo "Navigating to the root directory of the project..."
cd ../../
echo "Done."

echo "Setting environment variables..."
source .env
echo "Done."

if [ "$NETWORK" != "devnet" ]
then
    echo "This script can only be running at devnet, please change your NETWORK at .env"
    exit
fi

echo "Removing files inside deployment/artifacts/contracts directory if they exists..."
rm -rf deployment/artifacts/contracts/devnet
echo "Done."

echo "Creating devnet directory inside deployment/artifacts/contracts directory..."
mkdir deployment/artifacts/contracts/devnet
echo "Done."

echo "Deploying Demo L2LiskToken smart contract..."
forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/example/L2DemoToken.s.sol:L2DemoTokenScript
echo "Done."

echo "Deploying L2Claim smart contract..."
forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/L2Claim.s.sol:L2ClaimScript
echo "Done."

echo "Transferring funds to L2Claim smart contract..."
forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/example/DemoTransferFunds.s.sol:DemoTransferFundsScript
echo "Done."

echo "Submitting Claim..."
forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/example/L2ClaimTokens.s.sol:L2ClaimTokensScript
echo "Done."

echo "Completed."