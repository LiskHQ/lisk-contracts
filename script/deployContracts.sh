#!/usr/bin/env bash

cd ../
source .env
forge script --rpc-url="$L1_RPC_URL" --broadcast --verify --etherscan-api-key="$L1_ETHERSCAN_API_KEY" -vvvv script/L1LiskToken.s.sol:L1LiskTokenScript
forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --etherscan-api-key="$L2_ETHERSCAN_API_KEY" -vvvv script/L2LiskToken.s.sol:L2LiskTokenScript
forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --etherscan-api-key="$L2_ETHERSCAN_API_KEY" -vvvv script/L2Claim.s.sol:L2ClaimScript
forge script --rpc-url="$L1_RPC_URL" --broadcast -vvvv script/TransferFunds.s.sol:TransferFundsScript
