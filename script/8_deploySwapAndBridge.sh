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
forge script --rpc-url="$L1_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L1_VERIFIER_URL -vvvv script/swap_and_bridge/contracts/SwapAndBridge.s.sol:SwapAndBridgeScript $L1_STANDARD_BRIDGE_ADDR $L1_TOKEN_ADDR_DIVA $L2_TOKEN_ADDR_DIVA --sig 'run(address,address,address)' 
echo "Done."

echo "Deploying and if enabled verifying SwapAndBridge smart contract for LIDO protocol..."
forge script --rpc-url="$L1_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L1_VERIFIER_URL -vvvv script/swap_and_bridge/contracts/SwapAndBridge.s.sol:SwapAndBridgeScript  $L1_LIDO_BRIDGE_ADDR $L1_TOKEN_ADDR_LIDO $L2_TOKEN_ADDR_LIDO --sig 'run(address,address,address)'
echo "Done."
