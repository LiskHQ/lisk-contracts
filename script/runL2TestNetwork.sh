#!/usr/bin/env bash

source ../.env
anvil --mnemonic "$TEST_NETWORK_MNEMONIC" --port 8546 --fork-url "$L2_FORK_RPC_URL"
