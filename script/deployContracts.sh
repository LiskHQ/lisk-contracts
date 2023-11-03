#!/usr/bin/env bash

cd ../
source .env
forge script --rpc-url="$L1_RPC_URL" --broadcast --verify -vvvv script/L1LiskToken.s.sol:L1LiskTokenScript
forge script --rpc-url="$L2_RPC_URL" --broadcast --verify -vvvv script/L2LiskToken.s.sol:L2LiskTokenScript
forge script --rpc-url="$L2_RPC_URL" --broadcast --verify -vvvv script/L2Claim.s.sol:L2ClaimScript
forge script --rpc-url="$L1_RPC_URL" --broadcast --verify -vvvv script/TransferFunds.s.sol:TransferFundsScript
