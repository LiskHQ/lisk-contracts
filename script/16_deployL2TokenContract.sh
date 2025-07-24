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

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is not installed."
    exit 1
fi

# Check if NETWORK is set
if [ -z "$NETWORK" ]; then
    echo "❌ Error: NETWORK variable inside .env file is not set. Please set NETWORK environment variable."
    exit 1
fi

# Set paths based on network
# For testnet, the deployment records are under "sepolia" instead of "testnet"
if [ "$NETWORK" == "testnet" ]; then
    L2_DEPLOYMENT_DIR="deployment/artifacts/records/sepolia/L2LiskToken.s.sol"
else
    L2_DEPLOYMENT_DIR="deployment/artifacts/records/$NETWORK/L2LiskToken.s.sol"
fi

# Check if L2 deployment directory exists
if [ ! -d "$L2_DEPLOYMENT_DIR" ]; then
    echo "❌ Error: L2 deployment directory not found at $L2_DEPLOYMENT_DIR"
    exit 1
fi

# Find the deployment record file (there should be only one)
DEPLOYMENT_RECORD=$(find "$L2_DEPLOYMENT_DIR" -name "run-*.json" -type f | head -n 1)
if [ -z "$DEPLOYMENT_RECORD" ]; then
    echo "❌ Error: No deployment record found in $L2_DEPLOYMENT_DIR"
    exit 1
fi

# Extract init code from deployment record
echo "Extracting init code from deployment record..."
LISK_LSK_INIT_CODE=$(jq -r '.transactions[0].transaction.input' "$DEPLOYMENT_RECORD")
if [ "$LISK_LSK_INIT_CODE" == "null" ] || [ -z "$LISK_LSK_INIT_CODE" ]; then
    echo "❌ Error: Could not extract init code from $DEPLOYMENT_RECORD"
    exit 1
fi
echo "Init code extracted (first 100 chars): ${LISK_LSK_INIT_CODE:0:100}..."

# Extract expected L2 address from deployment record
echo "Extracting expected L2 address from deployment record..."
LISK_LSK_ADDRESS=$(jq -r '.transactions[0].contractAddress' "$DEPLOYMENT_RECORD")
if [ "$LISK_LSK_ADDRESS" == "null" ] || [ -z "$LISK_LSK_ADDRESS" ]; then
    echo "❌ Error: Could not extract contract address from $DEPLOYMENT_RECORD"
    exit 1
fi
echo "Expected L2 LSK address: $LISK_LSK_ADDRESS"

# Canonical CREATE2 deployer
FACTORY="0x4e59b44847b379578588920ca78fbf26c0b4956c"

# Address to use for initialize()
INIT_TARGET="0x4200000000000000000000000000000000000010"

# ==============================================

echo "📦 Deploying contract via CREATE2..."
echo "   Network: $NETWORK"
echo "   RPC URL: $L2_RPC_URL"
echo "   Factory: $FACTORY"
echo "   Expected address: $LISK_LSK_ADDRESS"

echo "Sending deployment transaction..."
# Send transaction to CREATE2 factory with the init code as raw data
cast send $FACTORY "$LISK_LSK_INIT_CODE" \
    --private-key $PRIVATE_KEY \
    --rpc-url $L2_RPC_URL \
    -vvvv

echo "✅ Deployment transaction sent."

# Wait a moment for the transaction to be mined
echo "Waiting for 3 seconds..."
sleep 3

# Verify deployment
if [ "$(cast code $LISK_LSK_ADDRESS --rpc-url $L2_RPC_URL)" == "0x" ]; then
    echo "❌ Contract not deployed yet at $LISK_LSK_ADDRESS"
    exit 1
else
    echo "✅ Contract deployed at: $LISK_LSK_ADDRESS"
fi

echo "⏳ Calling initialize()..."
cast send $LISK_LSK_ADDRESS "initialize(address)" $INIT_TARGET \
    --private-key $PRIVATE_KEY \
    -vvvv \
    --rpc-url $L2_RPC_URL

echo "✅ Initialization complete."

echo "🎉 Done! L2 LSK Token contract at: $LISK_LSK_ADDRESS"