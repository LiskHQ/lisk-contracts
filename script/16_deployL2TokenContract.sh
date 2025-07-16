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

echo "Creating $NETWORK directory inside deployment/artifacts/contracts directory..."
if [ -z "$NETWORK" ]
then
      echo "NETWORK variable inside .env file is not set. Please set NETWORK environment variable."
      exit 1
else
      if [ ! -f "deployment/artifacts/contracts/$NETWORK/l1addresses.json" ]
      then
        echo "deployment/artifacts/contracts/$NETWORK/l1addresses.json must exist with L1 token information."
        exit 1
      fi
fi
echo "Done."

echo "Deploying and if enabled verifying L2LiskToken smart contract..."
if [ -z "$CONTRACT_VERIFIER" ]
then
      forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/contracts/L2/L2LiskToken.s.sol:L2LiskTokenScript
else
      if [ $CONTRACT_VERIFIER = "blockscout" ]
      then
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L2_VERIFIER_URL -vvvv script/contracts/L2/L2LiskToken.s.sol:L2LiskTokenScript
      fi
      if [ $CONTRACT_VERIFIER = "etherscan" ]
      then
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier etherscan --verifier-url $L2_VERIFIER_URL --etherscan-api-key="$L2_ETHERSCAN_API_KEY" -vvvv script/contracts/L2/L2LiskToken.s.sol:L2LiskTokenScript
      fi
fi
echo "Done."
