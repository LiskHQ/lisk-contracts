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

echo "Creating $NETWORK directory inside deployment directory..."
if [ -z "$NETWORK" ]
then
      echo "NETWORK variable inside .env file is not set. Please set NETWORK environment variable."
      exit 1
else
      if [ -d "deployment/$NETWORK" ]
      then
            echo "Directory deployment/$NETWORK already exists."
      else
            mkdir deployment/$NETWORK
      fi
fi
echo "Done."

echo "Deploying and if enabled verifying L2Claim smart contract..."
if [ -z "$CONTRACT_VERIFIER" ]
then
      forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/contracts/L2/L2Claim.s.sol:L2ClaimScript
else
      if [ $CONTRACT_VERIFIER = "blockscout" ]
      then
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L2_VERIFIER_URL -vvvv script/contracts/L2/L2Claim.s.sol:L2ClaimScript
      fi
      if [ $CONTRACT_VERIFIER = "etherscan" ]
      then        
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier etherscan --etherscan-api-key="$L2_ETHERSCAN_API_KEY" -vvvv script/contracts/L2/L2Claim.s.sol:L2ClaimScript
      fi
fi
echo "Done."

echo "Deploying and if enabled verifying L2Airdrop smart contract..."
if [ -z "$CONTRACT_VERIFIER" ]
then
      forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/contracts/L2/L2Airdrop.s.sol:L2AirdropScript
else
      if [ $CONTRACT_VERIFIER = "blockscout" ]
      then
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L2_VERIFIER_URL -vvvv script/contracts/L2/L2Airdrop.s.sol:L2AirdropScript
      fi
      if [ $CONTRACT_VERIFIER = "etherscan" ]
      then        
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier etherscan --etherscan-api-key="$L2_ETHERSCAN_API_KEY" -vvvv script/contracts/L2/L2Airdrop.s.sol:L2AirdropScript
      fi
fi
echo "Done."

echo "Fund the L2Reward smart contract..."
forge script --rpc-url="$L2_RPC_URL" --broadcast -g 100 -vvvv script/contracts/L2/L2FundRewardContract.s.sol:FundRewardContractScript
echo "Done."

echo "Transferring funds to L1 and L2 addresses and L2Claim smart contract..."
forge script --rpc-url="$L1_RPC_URL" --broadcast -vvvv script/contracts/TransferFunds2ndBatch.s.sol:TransferFunds2ndBatchScript
echo "Done."
