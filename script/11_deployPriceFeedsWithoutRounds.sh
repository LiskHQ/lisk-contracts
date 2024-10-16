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
      if [ -d "deployment/artifacts/contracts/$NETWORK" ]
      then
            echo "Directory deployment/artifacts/contracts/$NETWORK already exists."
      else
            mkdir deployment/artifacts/contracts/$NETWORK
      fi
fi
echo "Done."

echo "Deploying and if enabled verifying L2PriceFeedUsdtWithoutRounds smart contract..."
if [ -z "$CONTRACT_VERIFIER" ]
then
      forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/contracts/L2/L2PriceFeedUsdtWithoutRounds.s.sol:L2PriceFeedUsdtWithoutRoundsScript
else
      if [ $CONTRACT_VERIFIER = "blockscout" ]
      then
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L2_VERIFIER_URL -vvvv script/contracts/L2/L2PriceFeedUsdtWithoutRounds.s.sol:L2PriceFeedUsdtWithoutRoundsScript
      fi
      if [ $CONTRACT_VERIFIER = "etherscan" ]
      then        
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier etherscan --etherscan-api-key="$L2_ETHERSCAN_API_KEY" -vvvv script/contracts/L2/L2PriceFeedUsdtWithoutRounds.s.sol:L2PriceFeedUsdtWithoutRoundsScript
      fi
fi
echo "Done."

echo "Deploying and if enabled verifying L2PriceFeedLskWithoutRounds smart contract..."
if [ -z "$CONTRACT_VERIFIER" ]
then
      forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/contracts/L2/L2PriceFeedLskWithoutRounds.s.sol:L2PriceFeedLskWithoutRoundsScript
else
      if [ $CONTRACT_VERIFIER = "blockscout" ]
      then
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L2_VERIFIER_URL -vvvv script/contracts/L2/L2PriceFeedLskWithoutRounds.s.sol:L2PriceFeedLskWithoutRoundsScript
      fi
      if [ $CONTRACT_VERIFIER = "etherscan" ]
      then        
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier etherscan --etherscan-api-key="$L2_ETHERSCAN_API_KEY" -vvvv script/contracts/L2/L2PriceFeedLskWithoutRounds.s.sol:L2PriceFeedLskWithoutRoundsScript
      fi
fi
echo "Done."
