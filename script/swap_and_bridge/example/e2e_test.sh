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
forge script -vvvv --rpc-url "http://localhost:8545" script/swap_and_bridge/contracts/SwapAndBridge_e2e_test.s.sol:TestE2EL1Script $L1_LIDO_BRIDGE_ADDR $L1_TOKEN_ADDR_LIDO $L2_LIDO_BRIDGE_ADDR $L2_TOKEN_ADDR_LIDO --sig 'runLido(address,address,address,address)'
forge script -vvvv --rpc-url "http://localhost:8546" script/swap_and_bridge/contracts/SwapAndBridge_e2e_test.s.sol:TestE2EL2Script $L2_TOKEN_ADDR_LIDO --sig 'run(address)'
echo "Done."

echo "Running E2E tests for Diva contract..."
forge script -vv --rpc-url "http://localhost:8545" script/swap_and_bridge/contracts/SwapAndBridge_e2e_test.s.sol:TestE2EL1Script $L1_STANDARD_BRIDGE_ADDR $L1_TOKEN_ADDR_DIVA $L2_STANDARD_BRIDGE_ADDR $L2_TOKEN_ADDR_DIVA --sig 'runDiva(address,address,address,address)'
forge script -vv --rpc-url "http://localhost:8546" script/swap_and_bridge/contracts/SwapAndBridge_e2e_test.s.sol:TestE2EL2Script $L2_TOKEN_ADDR_DIVA --sig 'run(address)'
echo "Done."