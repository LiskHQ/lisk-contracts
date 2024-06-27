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

echo "Running integration tests for Lido contract..."
forge script -vv --rpc-url "http://localhost:8545" script/swap_and_bridge/contracts/SwapAndBridge_integration_test.s.sol:TestIntegrationScript $L1_LIDO_BRIDGE_ADDR $L1_TOKEN_ADDR_LIDO $L2_TOKEN_ADDR_LIDO --sig 'run(address,address,address)'
echo "Done."

echo "Running integration tests for Diva contract..."
forge script -vv --rpc-url "http://localhost:8545" script/swap_and_bridge/contracts/SwapAndBridge_integration_test.s.sol:TestIntegrationScript $L1_STANDARD_BRIDGE_ADDR $L1_TOKEN_ADDR_DIVA $L2_TOKEN_ADDR_DIVA --sig 'run(address,address,address)'
echo "Done."