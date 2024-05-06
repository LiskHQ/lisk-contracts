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
forge script -vv --rpc-url "http://localhost:8545" script/swap_and_bridge/contracts/SwapAndBridge_lido_integration_test.s.sol:TestLidoIntegrationScript
echo "Done."

echo "Running integration tests for Diva contract..."
forge script -vv --rpc-url "http://localhost:8545" script/swap_and_bridge/contracts/SwapAndBridge_diva_integration_test.s.sol:TestDivaIntegrationScript
echo "Done."