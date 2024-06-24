#!/usr/bin/env bash

echo "Instructing the shell to exit immediately if any command returns a non-zero exit status..."
set -e
echo "Done."

echo "Navigating to the root directory of the project..."
cd ../../
echo "Done."

echo "Removing directory mutation_campaign if it exists..."
if [ -d "mutation_campaign" ]
then
    rm -rf mutation_campaign
fi
echo "Done."

echo "Starting Slither Mutate Campaign..."
slither-mutate . --test-cmd='forge test' --test-dir='test' --ignore-dirs='script,lib,test,utils,cache,out,broadcast,deployment'
echo "Done."
