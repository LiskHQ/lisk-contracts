# Lisk Smart Contracts

This package contains the smart contracts for the Lisk L2 network. In order for the Lisk L2 network to function as designed, certain smart contracts must be deployed on L1 (Ethereum's Layer 1), while others are deployed on L2.

## Contracts Overview

### Contracts deployed to L1

| Name                                    | Description                                      |
| --------------------------------------- | ------------------------------------------------ |
| [`L1LiskToken`](src/L1/L1LiskToken.sol) | Lisk token (LSK) deployed on Ethereum L1 network |

### Contracts deployed to L2

| Name | Description |
| ---- | ----------- |

## Installation

In order to build, test and deploy the smart contracts a [Foundry](https://github.com/foundry-rs/foundry) toolchain needs to be installed. The easiest way is to use `Foundryup` by below command:

```shell
curl -L https://foundry.paradigm.xyz | bash
```

This will install `Foundryup`, then simply follow the instructions on-screen, which will make the `foundryup` command available in your CLI. Running `foundryup` by itself will install the latest (nightly) precompiled binaries: `forge`, `cast`, `anvil`, and `chisel`.

## Deployment on Private Test Network

A private test network is established using the `anvil` tool, and the smart contracts are deployed using the `forge script` tool. To run a private network and deploy the smart contracts, follow these steps:
1. Create `.env` file and set the vars `PRIVATE_KEY` and `TEST_NETWORK_MNEMONIC`. You can copy and rename the `.env.example` file if the default values provided in `.env.example` are satisfactory.
2. Navigate to the `script` directory.
3. To create and launch a private test network, execute the script: `./runTestNetwork.sh`
4. To deploy all smart contracts, execute the script: `./deployContracts.sh`

## Tips & Tricks

**WARNING**: Foundry installs the latest versions of `openzeppelin-contracts` and `openzeppelin-contracts-upgradeable` initially, but subsequent `forge update` commands will use the `master` branch which is a development branch that should be avoided in favor of tagged releases. The release process involves security measures that the `master` branch does not guarantee.
