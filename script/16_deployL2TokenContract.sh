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

# Canonical CREATE2 deployer
FACTORY="0x4e59b44847b379578588920ca78fbf26c0b4956c"

# Address to use for initialize()
INIT_TARGET="0x4200000000000000000000000000000000000010"

# ==============================================

echo "📦 Deploying contract via CREATE2 to Base Sepolia..."
# Send transaction to CREATE2 factory with the init code as raw data
cast send $FACTORY "$LISK_LSK_INIT_CODE" \
    --private-key $PRIVATE_KEY \
    --rpc-url $L2_RPC_URL \
    -vvvv

echo "✅ Deployment transaction sent."

if [ "$(cast code $LISK_LSK_ADDRESS --rpc-url $L2_RPC_URL)" == "0x" ]; then
  echo "❌ Contract not deployed yet at $LISK_LSK_ADDRESS"
  exit 1
else
  echo "✅ Contract deployed at: $LISK_LSK_ADDRESS"
fi

echo "⏳ Waiting... Then calling initialize()..."
cast send $LISK_LSK_ADDRESS "initialize(address)" $INIT_TARGET \
    --private-key $PRIVATE_KEY \
    -vvvv \
    --rpc-url $L2_RPC_URL

echo "🎉 Done! Contract deployed at: $LISK_LSK_ADDRESS"
