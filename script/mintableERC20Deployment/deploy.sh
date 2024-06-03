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

echo "Deploying and verifying OptimismMintableERC20 smart contract..."
forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/mintableERC20Deployment/contracts/OptimismMintableERC20Deployment.s.sol:OptimismMintableERC20Deployment $1 "$2" "$3" $4  --sig 'run(address,string,string,uint8)'
echo "Done."


# E.g: ./mintableERC20Deployment/deploy.sh 0xB82381A3fBD3FaFA77B3a7bE693342618240067b "Urca Token 2" URCA2 24  