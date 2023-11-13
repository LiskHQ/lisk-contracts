#!/usr/bin/env bash

source ../.env
anvil --mnemonic "$TEST_NETWORK_MNEMONIC" --port 8545 --fork-url "$L1_FORK_RPC_URL"
