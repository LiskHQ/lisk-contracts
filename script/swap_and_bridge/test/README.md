# Test Scripts for SwapAndBridge

Tests in this folder are run as script as they require to be run in a Sepolia forked environment, since they depend on the contracts owned and deployed by Lido and Diva teams.

Before running them, start an L1 and L2 fork node using the shell scripts `runL1TestNetwork.sh` and `runL2TestNetwork.sh` inside [script](../..) folder respectively and make sure to run the tests from this folder.

Notice that these tests may fail fo reasons unrelated to the implementation of this feature, but rather because of problems with the target integration (for instance if the target LST contract does not mint new LSTs). If the `L2_TOKEN_ADDR_DIVA` value is not set in the `.env` file, the script will automatically deploy a test contract. Notice however that this deployment may fail if the very same test contract has already been deployed in your forked environment (which could be the case, for instance, if you run the scripts multiple times). In this case, just restart the fork nodes or modify the test contract name.

## E2E Tests

These tests simulate the user flow for transferring ETH on the L1 to either Lido or Diva LST on the Lisk L2 in a single transaction. Run them with `./e2e_test.sh`.

## Integration Tests

These tests run some checks on the interaction between the `SwapAndBridge` contract and the Lido and Diva LSTs. Run them with `./integration_test.sh`.
