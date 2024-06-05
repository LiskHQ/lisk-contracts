# Deploy factory
source ../.env.factory.testnet
echo "Deploying OptimismMintableERC20 smart contract..."
# Use flag --nonce to specify suitable nonce in case of nonce mismatch
cast send --rpc-url $L2_RPC_URL $FACTORY_CONTRACT_ADDRESS "createOptimismMintableERC20WithDecimals(address,string,string,uint8)" $REMOTE_TOKEN_ADDR $TOKEN_NAME $TOKEN_SYMBOL $DECIMALS -i