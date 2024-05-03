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

echo "Running E2E tests for Lido contract..."
forge script -vvvv --rpc-url "http://localhost:8545" script/swap_and_bridge/contracts/SwapAndBridge_lido_e2e_test.s.sol:TestLidoBridgingL1Script
forge script -vvvv --rpc-url "http://localhost:8546" script/swap_and_bridge/contracts/SwapAndBridge_lido_e2e_test.s.sol:TestLidoBridgingL2Script
echo "Done."

echo "Running E2E tests for Diva contract..."
forge script -vvvv --rpc-url "http://localhost:8545" script/swap_and_bridge/contracts/SwapAndBridge_diva_e2e_test.s.sol:TestDivaBridgingL1Script
forge script -vvvv --rpc-url "http://localhost:8546" script/swap_and_bridge/contracts/SwapAndBridge_diva_e2e_test.s.sol:TestDivaBridgingL2Script
echo "Done."