#!/usr/bin/env bash

echo "Instructing the shell to exit immediately if any command returns a non-zero exit status..."
set -e
echo "Done."

echo "Navigating to the root directory of the project..."
cd ../../
echo "Done."

echo "Removing file slitherResults.md if it exists..."
if [ -f "slitherResults.md" ]
then
    rm slitherResults.md
fi
echo "Done."

echo "Starting Slither tool..."
slither . --exclude-dependencies --exclude-low --exclude-informational --filter-paths "Ed25519.sol" --checklist > slitherResults.md
echo "Done."
