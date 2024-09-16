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

<<<<<<< HEAD
echo "Deploying OptimismMintableERC20 WBTC token smart contract..."
=======
echo "Deploying OptimismMintableERC20 USDT token smart contract..."
>>>>>>> 8914457 (feat: add WBTC deployment script and addresses for mainnet and sepolia)
cast send --rpc-url $L2_RPC_URL "0x4200000000000000000000000000000000000012" "createOptimismMintableERC20WithDecimals(address,string,string,uint8)" $REMOTE_TOKEN_ADDR_WBTC "Wrapped BTC" "WBTC" 8 -i