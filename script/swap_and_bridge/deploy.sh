#!/usr/bin/env bash

echo "Instructing the shell to exit immediately if any command returns a non-zero exit status..."
set -e
echo "Done."

echo "Navigating to the root directory of the project..."
cd ../
echo "Done."

echo "Setting environment variables..."
source .env
echo "Done."

echo "Creating $NETWORK directory inside deployment directory..."
if [ -z "$NETWORK" ]
then
      echo "NETWORK variable inside .env file is not set. Please set NETWORK environment variable."
      exit 1
else
      if [ -d "deployment/$NETWORK" ]
      then
            echo "Directory deployment/$NETWORK already exists."
      else
            mkdir deployment/$NETWORK
      fi
fi
echo "Done."

echo "Deploying and if enabled verifying L2WdivETH smart contract..."
forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L2_VERIFIER_URL -vvvv script/swap_and_bridge/SwapAndBridge.s.sol:L2WdivETHScript 
echo "Done."

echo "Deploying and if enabled verifying SwapAndBridge smart contract..."
forge script --rpc-url="$L1_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L1_VERIFIER_URL -vvvv script/swap_and_bridge/SwapAndBridge.s.sol:SwapAndBridgeDivaScript
echo "Done."

echo "Deploying and if enabled verifying SwapAndBridge smart contract..."
forge script --rpc-url="$L1_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L1_VERIFIER_URL -vvvv script/swap_and_bridge/SwapAndBridge.s.sol:SwapAndBridgeLidoScript
echo "Done."