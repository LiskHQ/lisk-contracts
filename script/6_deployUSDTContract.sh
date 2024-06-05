#!/usr/bin/env bash

source ../.env.testnet
echo "Deploying OptimismMintableERC20 USDT token smart contract..."
# Use flag --nonce to specify suitable nonce in case of nonce mismatch
cast send --rpc-url $L2_RPC_URL "0xc0D3c0d3C0d3c0d3c0D3c0d3c0D3c0D3c0D30012" "createOptimismMintableERC20WithDecimals(address,string,string,uint8)" $REMOTE_TOKEN_ADDR_USDT "Tether USD" "USDT" 6 -i