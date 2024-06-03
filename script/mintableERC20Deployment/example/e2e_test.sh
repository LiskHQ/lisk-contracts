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

echo "Running E2E tests for OptimismMintableERC20 contract..."


OUTPUT=$(forge script --broadcast --rpc-url "$L1_RPC_URL" script/mintableERC20Deployment/example/E2ETest.s.sol:TestL1DepositScript $1 $2 --sig 'run(address,address)' | tee /dev/fd/2 | tail -1) 
# forge script --broadcast --rpc-url "$L2_RPC_URL" script/mintableERC20Deployment/example/E2ETest.s.sol:TestL2DepositScript --sig 'run(address,bytes)' $2 $OUTPUT

# OUTPUT=$(forge script -vvvvv --broadcast --rpc-url "$L2_RPC_URL" script/mintableERC20Deployment/example/E2ETest.s.sol:TestL2WithdrawalScript $2 $1 --sig 'run(address,address)' | tee /dev/fd/2 | tail -1) 
# forge script -vvvvv --broadcast --rpc-url "$L1_RPC_URL" script/mintableERC20Deployment/example/E2ETest.s.sol:TestL1WithdrawalScript --sig 'run(address,bytes)' $1 $OUTPUT


echo "Done."


# 0x7169D38820dfd117C3FA1f22a697dBA58d90BA06  0xb909049747ff3b863849e1a4fda6d4b30376ec03