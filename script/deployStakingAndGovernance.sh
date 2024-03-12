#!/usr/bin/env bash

echo "Instructing the shell to exit immediately if any command returns a non-zero exit status..."
set -e
echo "Done."

echo "Navigating to the root directory of the project..."
cd ../
echo "Done."

#echo "Removing files inside deployment directory if they exists..."
#rm -rf deployment/*
#echo "Done."

echo "Setting environment variables..."
source .env
echo "Done."

#echo "Creating $NETWORK directory inside deployment directory..."
#if [ -z "$NETWORK" ]
#then
#      echo "NETWORK variable inside .env file is not set. Please set NETWORK environment variable."
#      exit 1
#else
#      mkdir deployment/$NETWORK      
#fi
#echo "Done."

echo "Deploying and if enabled verifying L2Staking smart contract..."
if [ -z "$CONTRACT_VERIFIER" ]
then
      forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/L2Staking.s.sol:L2StakingScript
else
      if [ $CONTRACT_VERIFIER = "blockscout" ]
      then
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L2_VERIFIER_URL -vvvv script/L2Staking.s.sol:L2StakingScript
      fi
      if [ $CONTRACT_VERIFIER = "etherscan" ]
      then        
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier etherscan --etherscan-api-key="$L2_ETHERSCAN_API_KEY" -vvvv script/L2Staking.s.sol:L2StakingScript
      fi
fi
echo "Done."

echo "Deploying and if enabled verifying L2LockingPosition smart contract..."
if [ -z "$CONTRACT_VERIFIER" ]
then
      forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/L2LockingPosition.s.sol:L2LockingPositionScript
else
      if [ $CONTRACT_VERIFIER = "blockscout" ]
      then
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L2_VERIFIER_URL -vvvv script/L2LockingPosition.s.sol:L2LockingPositionScript
      fi
      if [ $CONTRACT_VERIFIER = "etherscan" ]
      then        
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier etherscan --etherscan-api-key="$L2_ETHERSCAN_API_KEY" -vvvv script/L2LockingPosition.s.sol:L2LockingPositionScript
      fi
fi
echo "Done."

echo "Deploying and if enabled verifying L2VotingPower smart contract..."
if [ -z "$CONTRACT_VERIFIER" ]
then
      forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/L2VotingPower.s.sol:L2VotingPowerScript
else
      if [ $CONTRACT_VERIFIER = "blockscout" ]
      then
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L2_VERIFIER_URL -vvvv script/L2VotingPower.s.sol:L2VotingPowerScript
      fi
      if [ $CONTRACT_VERIFIER = "etherscan" ]
      then        
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier etherscan --etherscan-api-key="$L2_ETHERSCAN_API_KEY" -vvvv script/L2VotingPower.s.sol:L2VotingPowerScript
      fi
fi
echo "Done."

echo "Deploying and if enabled verifying L2Governor smart contract..."
if [ -z "$CONTRACT_VERIFIER" ]
then
      forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/L2Governor.s.sol:L2GovernorScript
else
      if [ $CONTRACT_VERIFIER = "blockscout" ]
      then
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier blockscout --verifier-url $L2_VERIFIER_URL -vvvv script/L2Governor.s.sol:L2GovernorScript
      fi
      if [ $CONTRACT_VERIFIER = "etherscan" ]
      then        
            forge script --rpc-url="$L2_RPC_URL" --broadcast --verify --verifier etherscan --etherscan-api-key="$L2_ETHERSCAN_API_KEY" -vvvv script/L2Governor.s.sol:L2GovernorScript
      fi
fi
echo "Done."

echo "Transferring ownership of L2Staking and L2LockingPosition smart contracts to a new owner..."
forge script --rpc-url="$L2_RPC_URL" --broadcast -vvvv script/TransferStakingOwnership.s.sol:TransferStakingOwnershipScript
echo "Done."
