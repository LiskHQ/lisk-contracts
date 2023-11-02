#!/usr/bin/env bash

cd ../
forge script --rpc-url=http://localhost:8545 --broadcast --verify -vvvv script/L1LiskToken.s.sol:L1LiskTokenScript
forge script --rpc-url=http://localhost:8545 --broadcast --verify -vvvv script/L2LiskToken.s.sol:L2LiskTokenScript
forge script --rpc-url=http://localhost:8545 --broadcast --verify -vvvv script/L2Claim.s.sol:L2ClaimScript
forge script --rpc-url=http://localhost:8545 --broadcast --verify -vvvv script/TransferFunds.s.sol:TransferFundsScript
