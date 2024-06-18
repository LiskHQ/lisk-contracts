#!/usr/bin/env bash

echo "Instructing the shell to exit immediately if any command returns a non-zero exit status..."
set -e
echo "Done."

echo "Navigating to the root directory of the project..."
cd ../../
echo "Done."

if [ -z "$1" ]
then
    echo "Please provide the contract name as the first argument."$'\n'"Exaxmple: runEchidna.sh <contract_name>"
    exit 1
fi

echo "Starting Echidna tool..."
echidna test/fuzzing --workers 5 --contract $1 --corpus-dir test/fuzzing --format text --test-mode assertion --test-limit 5000000
echo "Done."
