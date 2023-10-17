#!/usr/bin/env bash

cd ../
forge script --rpc-url=http://localhost:8545 --broadcast --verify -vvvv script/L1LiskToken.s.sol:L1LiskTokencript
