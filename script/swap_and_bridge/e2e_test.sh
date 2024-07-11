#!/usr/bin/env bash

echo "Instructing the shell to exit immediately if any command returns a non-zero exit status..."
set -e
echo "Done."

echo "Navigating to the root directory of the project..."
cd ../../
echo "Done."

echo "Setting environment variables..."
source .env
echo "Done."

if [ -z "$L1_TOKEN_ADDR_LIDO" ]
then
    echo "Please set L1_TOKEN_ADDR_LIDO in .env file"
    exit 1
fi

if [ -z "$L2_TOKEN_ADDR_LIDO" ]
then
    echo "Please set L2_TOKEN_ADDR_LIDO in .env file"
    # Unlike Diva, L2_TOKEN_ADDR_LIDO cannot be deployed as the bridge is setup to work only with a predefined L2 token.  
    exit 1
fi

echo "Running E2E tests for Lido contract..."
forge script -vv --rpc-url "http://localhost:8545" script/swap_and_bridge/SwapAndBridge_e2e_test.s.sol:TestE2EL1Script $L1_LIDO_BRIDGE_ADDR $L1_TOKEN_ADDR_LIDO $L2_LIDO_BRIDGE_ADDR $L2_TOKEN_ADDR_LIDO --sig 'runLido(address,address,address,address)'
forge script -vv --rpc-url "http://localhost:8546" script/swap_and_bridge/SwapAndBridge_e2e_test.s.sol:TestE2EL2Script $L2_TOKEN_ADDR_LIDO --sig 'run(address)'
echo "Done."


if [ -z "$L1_TOKEN_ADDR_DIVA" ]
then
    echo "Please set L1_TOKEN_ADDR_DIVA in .env file"
    exit 1
fi

if [ -z "$L2_TOKEN_ADDR_DIVA" ]
then
    echo "L2_TOKEN_ADDR_DIVA variable inside .env file is not set."
    echo "Deploying 'Wrapped Diva Ether Token' on L2..."
    # The following command will revert if the token has already been deployed with the same parameters because the deterministic address would clash
    DeploymentJSON=$(cast send --rpc-url "http://localhost:8546" "0x4200000000000000000000000000000000000012" "createOptimismMintableERC20WithDecimals(address,string,string,uint8)" $L1_TOKEN_ADDR_DIVA "Wrapped Diva Local Token" wdivETH 18 --private-key $PRIVATE_KEY)
    L2_TOKEN_ADDR_DIVA="0x$(echo $DeploymentJSON  | awk 'BEGIN{FS="topics:*"}{print $2}' | awk -F, '{print $3}' | awk 'BEGIN{FS="\]*"}{print $1}' | cut -d "\"" -f 2 | tail -c 41)"
    echo "L2_TOKEN_ADDR_DIVA deployed to" $L2_TOKEN_ADDR_DIVA
fi

echo "Running E2E tests for Diva contract..."
forge script -vv --rpc-url "http://localhost:8545" script/swap_and_bridge/SwapAndBridge_e2e_test.s.sol:TestE2EL1Script $L1_STANDARD_BRIDGE_ADDR $L1_TOKEN_ADDR_DIVA $L2_STANDARD_BRIDGE_ADDR $L2_TOKEN_ADDR_DIVA --sig 'runDiva(address,address,address,address)'
forge script -vv --rpc-url "http://localhost:8546" script/swap_and_bridge/SwapAndBridge_e2e_test.s.sol:TestE2EL2Script $L2_TOKEN_ADDR_DIVA --sig 'run(address)'
echo "Done."