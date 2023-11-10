# Lisk Smart Contracts

This package contains the smart contracts for the Lisk L2 network. In order for the Lisk L2 network to function as designed, certain smart contracts must be deployed on L1 (Ethereum's Layer 1), while others are deployed on L2.

## Contracts Overview

### Contracts deployed to L1

| Name                                    | Description                                      |
| --------------------------------------- | ------------------------------------------------ |
| [`L1LiskToken`](src/L1/L1LiskToken.sol) | Lisk token (LSK) deployed on Ethereum L1 network |

### Contracts deployed to L2

| Name                                    | Description                                                         |
| --------------------------------------- | ------------------------------------------------------------------- |
| [`L2LiskToken`](src/L2/L2LiskToken.sol) | Bridged Lisk token (LSK) deployed on Lisk L2 network                |
| [`L2Claim`](src/L2/L2Claim.sol)         | Smart contract responsible for a claiming process of the LSK tokens |

## Installation

In order to build, test and deploy the smart contracts a [Foundry](https://github.com/foundry-rs/foundry) toolchain needs to be installed. The easiest way is to use `Foundryup` by below command:

```shell
curl -L https://foundry.paradigm.xyz | bash
```

This will install `Foundryup`, then simply follow the instructions on-screen, which will make the `foundryup` command available in your CLI. Running `foundryup` by itself will install the latest (nightly) precompiled binaries: `forge`, `cast`, `anvil`, and `chisel`.

### Cloning the Lisk Smart Contracts Repository
To download all the necessary project files and libraries, execute the following commands:
```shell
git clone https://github.com/LiskHQ/lisk-contracts.git
```
Inside newly created `lisk-contracts` directory:
```shell
git submodule update --init --recursive
```

## Deployment on Private Test Network

**NOTE**: On a private test network, the deployment of smart contracts is feasible on both L1 and L2 networks. However, the transfer of tokens between these networks is not possible as it requires the operation of the Sequencer.

**NOTE**: To successfully deploy all smart contracts and execute the required transactions, the deployer (specified by `PRIVATE_KEY` in the `.env` file) must have funds available in its address. For a private test network, you can use a any private key from the list provided by `anvil` when the network is created, or choose another private key with sufficient funds on a forked network.

Private L1 and L2 test networks are established using the `anvil` tool, and the smart contracts are deployed using the `forge script` tool. To run private networks and deploy the smart contracts, follow these steps:
1. Create `.env` file and set the vars `PRIVATE_KEY`, `L1_RPC_URL`, `L1_FORK_RPC_URL`, `L2_RPC_URL`, `L2_FORK_RPC_URL`, `L1_STANDARD_BRIDGE_ADDR` and `TEST_NETWORK_MNEMONIC`. You can copy and rename the `.env.example` file if the default values provided in `.env.example` are satisfactory. `L1_RPC_URL` should be set to `http://127.0.0.1:8545` and `L2_RPC_URL` should be set to `http://127.0.0.1:8546` if no changes are made in the `./runL1TestNetwork.sh` or `./runL2TestNetwork.sh` script files.
2. Navigate to the `script` directory.
3. To create and launch a private test L1 network, execute the script: `./runL1TestNetwork.sh`
4. To create and launch a private test L2 network, execute the script: `./runL2TestNetwork.sh`
5. To deploy all smart contracts, execute the script: `./deployContracts.sh`

## Deployment on Public Test Network

**NOTE**: To successfully deploy all smart contracts and execute the required transactions, the deployer (specified by `PRIVATE_KEY` in the `.env` file) must have funds available in its address. This implies that a private key with a sufficient balance on a public test network is required.

To deploy smart contracts on both L1 and L2 public networks, you will need to provide for each network an URL for a public node from a RPC provider, such as Alchemy or Infura. Additionally, in order to verify smart contracts during the deployment process, it is necessary to provide an Etherscan API key. Follow these steps to deploy the smart contracts:
1. Create `.env` file and set the vars `PRIVATE_KEY`, `L1_RPC_URL`, `L2_RPC_URL`, `L1_ETHERSCAN_API_KEY`, `L2_ETHERSCAN_API_KEY` and `L1_STANDARD_BRIDGE_ADDR`. You can copy and rename the `.env.example` file if the default values provided in `.env.example` are satisfactory. `L1_ETHERSCAN_API_KEY` and `L2_ETHERSCAN_API_KEY` may be empty to skip smart contracts verification process.
2. Navigate to the `script` directory.
3. To deploy all smart contracts, execute the script: `./deployContracts.sh`
   
## Tips & Tricks

**WARNING**: Foundry installs the latest versions of `openzeppelin-contracts` and `openzeppelin-contracts-upgradeable` initially, but subsequent `forge update` commands will use the `master` branch which is a development branch that should be avoided in favor of tagged releases. The release process involves security measures that the `master` branch does not guarantee.
