# Testing Smart Contracts with Foundry and Other Frameworks

This repository utilizes the Foundry and other frameworks for testing smart contracts. Within the `test` directory, you will find multiple script files designed to be executed locally. These scripts are integral for different testing and analysis tools: `Slither`, `slither-mutate`, and `Echidna`. Below is an overview of each script and the respective tools they utilize.

## Overview of Scripts

1. **Slither Script**
    - **Script File:** `scripts/runSlither.sh`
    - **Purpose:** This script runs the `Slither` tool, which is used for static analysis of smart contracts.
    - **Details:** `Slither` helps in identifying potential vulnerabilities and issues in the smart contract code without executing it. It provides insights into security, correctness, and gas optimization.

2. **Slither-Mutate Script**
    - **Script File:** `scripts/runSlitherMutate.sh`
    - **Purpose:** This script executes the `slither-mutate` tool, which extends `Slither`’s capabilities by introducing mutation testing.
    - **Details:** `Slither-mutate` creates variations (mutants) of the smart contract code to check if the existing test cases can detect these mutations. It helps in assessing the effectiveness and coverage of the test suite.

3. **Echidna Script**
    - **Script File:** `scripts/runEchidna.sh`
    - **Purpose:** This script runs the `Echidna` tool, a property-based fuzzer.
    - **Details:** `Echidna`is used to find bugs by generating random inputs to test the smart contract properties. It helps in uncovering edge cases and ensuring that the contracts behave as expected under various conditions.

## Tools Overview

### Slither

`Slither` is a static analysis framework specifically designed for smart contracts. It analyzes the contract code without executing it, providing valuable insights into:
- Security vulnerabilities
- Code correctness
- Optimization opportunities
- Compliance with best practices

### Slither-Mutate

`Slither-mutate` leverages the static analysis power of `Slither` and combines it with mutation testing. By creating and testing mutated versions of the contract, it evaluates:
- The robustness of the existing test cases
- The overall test coverage
- The ability of the tests to detect potential issues

### Echidna

`Echidna` is a property-based testing tool (fuzzer) for smart contracts. It works by:
- Generating random inputs to interact with the smart contract
- Checking predefined properties and invariants
- Identifying unexpected behavior or bugs

To get familiar with `Echinida` tool, you can refer to the Secure Contracts website and follow [Echidna tutorial](https://secure-contracts.com/program-analysis/echidna/index.html).
