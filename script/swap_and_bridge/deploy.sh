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

echo "Deploying and if enabled verifying SwapAndBridge smart contract..."
if [ -z "$CONTRACT_VERIFIER" ]
then
      forge script --rpc-url="$L1_RPC_URL" --broadcast -vvvv script/swap_and_bridge/SwapAndBridge.s.sol:SwapAndBridgeScript
else
      if [ $CONTRACT_VERIFIER = "blockscout" ]
      then
            forge script --rpc-url="$L1_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L1_VERIFIER_URL -vvvv script/swap_and_bridge/SwapAndBridge.s.sol:SwapAndBridgeScript
      fi
      if [ $CONTRACT_VERIFIER = "etherscan" ]
      then        
            forge script --rpc-url="$L1_RPC_URL" --broadcast --verify --verifier etherscan --etherscan-api-key="$L1_ETHERSCAN_API_KEY" -vvvv script/swap_and_bridge/SwapAndBridge.s.sol:SwapAndBridgeScript
      fi
fi
echo "Done."