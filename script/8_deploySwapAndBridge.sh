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

echo "Deploying and if enabled verifying SwapAndBridge smart contract for DIVA protocol..."
if [ -z "$CONTRACT_VERIFIER" ]
then
    forge script --rpc-url="$L1_RPC_URL" --broadcast -vvvv script/contracts/L1/SwapAndBridge.s.sol:SwapAndBridgeScript $L1_STANDARD_BRIDGE_ADDR $L1_TOKEN_ADDR_DIVA $L2_TOKEN_ADDR_DIVA --sig 'run(address,address,address)' 
else
      if [ $CONTRACT_VERIFIER = "blockscout" ]
      then
            forge script --rpc-url="$L1_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L1_VERIFIER_URL -vvvv script/contracts/L1/SwapAndBridge.s.sol:SwapAndBridgeScript $L1_STANDARD_BRIDGE_ADDR $L1_TOKEN_ADDR_DIVA $L2_TOKEN_ADDR_DIVA --sig 'run(address,address,address)' 
      fi
      if [ $CONTRACT_VERIFIER = "etherscan" ]
      then        
            forge script --rpc-url="$L1_RPC_URL" --broadcast --verify --verifier etherscan --etherscan-api-key="$L1_ETHERSCAN_API_KEY" --verifier-url $L1_VERIFIER_URL -vvvv script/contracts/L1/SwapAndBridge.s.sol:SwapAndBridgeScript $L1_STANDARD_BRIDGE_ADDR $L1_TOKEN_ADDR_DIVA $L2_TOKEN_ADDR_DIVA --sig 'run(address,address,address)' 
      fi
fi
echo "Done."

echo "Deploying and if enabled verifying SwapAndBridge smart contract for LIDO protocol..."
if [ -z "$CONTRACT_VERIFIER" ]
then
    forge script --rpc-url="$L1_RPC_URL" --broadcast -vvvv script/contracts/L1/SwapAndBridge.s.sol:SwapAndBridgeScript $L1_LIDO_BRIDGE_ADDR $L1_TOKEN_ADDR_LIDO $L2_TOKEN_ADDR_LIDO --sig 'run(address,address,address)' 
else
      if [ $CONTRACT_VERIFIER = "blockscout" ]
      then
            forge script --rpc-url="$L1_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L1_VERIFIER_URL -vvvv script/contracts/L1/SwapAndBridge.s.sol:SwapAndBridgeScript $L1_LIDO_BRIDGE_ADDR $L1_TOKEN_ADDR_LIDO $L2_TOKEN_ADDR_LIDO --sig 'run(address,address,address)' 
      fi
      if [ $CONTRACT_VERIFIER = "etherscan" ]
      then        
            forge script --rpc-url="$L1_RPC_URL" --broadcast --verify --verifier etherscan --etherscan-api-key="$L1_ETHERSCAN_API_KEY" --verifier-url $L1_VERIFIER_URL -vvvv script/contracts/L1/SwapAndBridge.s.sol:SwapAndBridgeScript $L1_LIDO_BRIDGE_ADDR $L1_TOKEN_ADDR_LIDO $L2_TOKEN_ADDR_LIDO --sig 'run(address,address,address)' 
      fi
fi
echo "Done."
