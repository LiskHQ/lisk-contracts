# Lisk Smart Contracts <!-- omit in toc -->

This repository contains smart contracts for various services of the Lisk project. This includes, for instance, the contract for the LSK token or the contracts required to migrate the LSK token distribution from the Lisk L1 to the L2. In order to function as designed, certain smart contracts must be deployed on L1 (Ethereum's Layer 1), while others are deployed on L2.

Additionally, it also includes various deployment scripts that are integral for deploying on different networks. These scripts handle the deployment of smart contracts to both L1 and L2 private test networks, as well as to public `testnet` and `mainnet` networks. They also ensure seamless deployment across different environments and the efficient movement of tokens to the appropriate accounts as per the project's requirements.

## Table of Contents <!-- omit in toc -->

- [Contracts Overview](#contracts-overview)
  - [Contracts deployed to L1](#contracts-deployed-to-l1)
  - [Contracts deployed to L2](#contracts-deployed-to-l2)
- [Installation](#installation)
  - [Cloning the Lisk Smart Contracts Repository](#cloning-the-lisk-smart-contracts-repository)
- [Deployment on Private Test Network](#deployment-on-private-test-network)
- [Deployment on Public Test Network](#deployment-on-public-test-network)
- [Tips \& Tricks](#tips--tricks)
  - [Deployment Directory Folder](#deployment-directory-folder)
  - [Deployment of L2 Lisk Token](#deployment-of-l2-lisk-token)
  - [Transferring Lisk Tokens After Smart Contracts Deployment](#transferring-lisk-tokens-after-smart-contracts-deployment)
  - [Lisk L2 Staking](#lisk-l2-staking)
  - [Smart Contract Ownership](#smart-contract-ownership)
- [Contributing](#contributing)
- [Security](#security)
- [License](#license)

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

**NOTE**: To successfully deploy all smart contracts and execute the required transactions, the deployer (specified by `PRIVATE_KEY` in the `.env` file) must have funds available in its address on the respective networks. For a private test network, you can use a any private key from the list provided by `anvil` when the network is created, or choose another private key with sufficient funds on both forked networks.

Private L1 and L2 test networks are established using the `anvil` tool, and the smart contracts are deployed using the `forge script` tool. To run private networks and deploy the smart contracts, follow these steps:
1. Create `.env` file and set the vars `PRIVATE_KEY`, `NETWORK`, `L1_TOKEN_OWNER_ADDRESS`, `L2_CLAIM_OWNER_ADDRESS`, `DAO_ADDRESS`, `DETERMINISTIC_ADDRESS_SALT`, `L1_STANDARD_BRIDGE_ADDR`, `L1_RPC_URL`, `L2_RPC_URL`, `L1_FORK_RPC_URL`, `L2_FORK_RPC_URL` and `TEST_NETWORK_MNEMONIC`. You can copy and rename the `.env.example` file if the default values provided in `.env.example` are satisfactory. `L1_RPC_URL` should be set to `http://127.0.0.1:8545` and `L2_RPC_URL` should be set to `http://127.0.0.1:8546` if no changes are made in the `./runL1TestNetwork.sh` or `./runL2TestNetwork.sh` script files.
2. Navigate to the `script` directory.
3. Place the `accounts.json` and `merkle-root.json` files in the correct folder (`data/devnet`, `data/testnet`, or `data/mainnet`) corresponding to the previously set `NETWORK` environment variable. Example files for `accounts.json` and `merkle-root.json` may be found inside `data/devnet` directory.
4. To create and launch a private test L1 network, execute the script: `./runL1TestNetwork.sh`
5. To create and launch a private test L2 network, execute the script: `./runL2TestNetwork.sh`
6. To deploy all smart contracts, execute the script: `./deployContracts.sh`

## Deployment on Public Test Network

**NOTE**: To successfully deploy all smart contracts and execute the required transactions, the deployer (specified by `PRIVATE_KEY` in the `.env` file) must have funds available in its address. This implies that a private key with a sufficient balance on both public test networks is required.

To deploy smart contracts on both L1 and L2 public networks, you will need to provide for each network an URL for a public node from a RPC provider, such as Alchemy or Infura. Additionally, in order to verify smart contracts on Blockscout or Etherscan Block Explorers during the deployment process, it is necessary to provide verifier name along with additional information (URL and API key). Follow these steps to deploy the smart contracts:
1. Create `.env` file and set the vars `PRIVATE_KEY`, `NETWORK`, `L1_TOKEN_OWNER_ADDRESS`, `L2_CLAIM_OWNER_ADDRESS`, `DAO_ADDRESS`, `DETERMINISTIC_ADDRESS_SALT`, `L1_STANDARD_BRIDGE_ADDR`, `L1_RPC_URL`, `L2_RPC_URL` and `CONTRACT_VERIFIER`. You can copy and rename the `.env.example` file if the default values provided in `.env.example` are satisfactory. `CONTRACT_VERIFIER` may be empty to skip smart contracts verification process on Blockscout or Etherscan Block Explorers.
2. When `CONTRACT_VERIFIER` is configured as either `blockscout` or `etherscan`, there are specific additional variables that must be defined. For `blockscout`, it is necessary to set `L1_VERIFIER_URL` and `L2_VERIFIER_URL`. Conversely, for `etherscan`, it is necessary to set `L1_ETHERSCAN_API_KEY` and `L2_ETHERSCAN_API_KEY`.             
3. Navigate to the `script` directory.
4. Place the `accounts.json` and `merkle-root.json` files in the correct folder (`data/devnet`, `data/testnet`, or `data/mainnet`) corresponding to the previously set `NETWORK` environment variable. Example files for `accounts.json` and `merkle-root.json` may be found inside `data/devnet` directory.
5. To deploy all smart contracts, execute the script: `./deployContracts.sh`
   
## Tips & Tricks

**WARNING**: Foundry installs the latest versions of `openzeppelin-contracts` and `openzeppelin-contracts-upgradeable` initially, but subsequent `forge update` commands will use the `master` branch which is a development branch that should be avoided in favor of tagged releases. The release process involves security measures that the `master` branch does not guarantee.

### Deployment Directory Folder

The `NETWORK` environment variable can be set to determine the folder where files will be generated during the deployment of smart contracts. This includes files like `l1addresses.json` and `l2addresses.json`. The acceptable values for this variable are `mainnet`, `testnet` or `devnet`, which correspond to the specific network environments where the deployment is taking place. Setting this variable helps in organizing and managing the deployment process by ensuring that all related files are stored in the correct network specific folder.

### Deployment of L2 Lisk Token

L2 Lisk Token is deployed using `CREATE2` opcode to ensure deterministic smart contract address. The `salt` utilized for its creation is derived by hashing the concatenation of the `DETERMINISTIC_ADDRESS_SALT` environment variable, an underscore, and the name of the smart contract.

### Transferring Lisk Tokens After Smart Contracts Deployment

After the successful deployment of all smart contracts using the `deployContracts.sh` script, the distribution of newly minted Lisk tokens takes place in accordance with the instructions specified in the `accounts.json` file. This file contains a list of addresses and the respective amounts of tokens that need to be sent to various accounts on both the L1 and L2 networks.

The process ensures that each address specified in the `accounts.json` file receives the designated amount of tokens accurately. Any remaining Lisk Tokens, those not allocated to the addresses listed in the file, are then transferred to the [Claim smart contract](src/L2/L2Claim.sol). This systematic distribution is critical for ensuring that the tokens are correctly assigned to their intended recipients across the different network layers as part of the project's requirements.

### Lisk L2 Staking
Staking L2 tokens creates additional utility of L2 Lisk token by allowing user to stake an amount of token for a certain period of time allowing them to earn daily rewards and contribute to Governance.

Implementation of L2 staking functionality is separated into;
- `L2LockingPosition` contract represents staking positions as an implementation of ERC721 (NFT) interface.
- `L2Staking` contract manages interactions with `L2LockingPosition` contract. It restricts manipulation of staking positions represented by `LockingPostion` structure to the creator role.
- `L2Reward` contract exposes the public API to stakers, enabling them to lock funds, manipulate existing position they own and claim rewards.

### Smart Contract Ownership

Some of the smart contracts in this project are designed to be `ownable`, meaning they have an assigned owner. This ownership allows for certain privileges and actions. For instance, in the case of upgradable smart contracts like the [Claim smart contract](src/L2/L2Claim.sol), the owner has the ability to upgrade the contract. This feature is crucial for making improvements or fixes to the contract after deployment.

Additionally, in the case of specific contracts like the [L1 Lisk Token](src/L1/L1LiskToken.sol), the owner can assign special roles to certain Ethereum addresses. An example of such a role is the `burner` role, which grants the assigned address the capability to burn tokens. This ability to assign roles and upgrade contracts provides flexibility and control, ensuring that the contracts can be managed and updated effectively to suit evolving requirements or address any issues that may arise.

## Contributing

If you find any issues or have suggestions for improvements,
please [open an issue](https://github.com/LiskHQ/lisk-contracts/issues/new/choose) on the GitHub repository. You can also
submit [pull requests](https://github.com/LiskHQ/lisk-contracts/compare)
with [bug fixes](https://github.com/LiskHQ/lisk-contracts/issues/new?assignees=&labels=bug+report&projects=&template=bug-report.md&title=%5BBug%5D%3A+),
[new features](https://github.com/LiskHQ/lisk-contracts/issues/new?assignees=&labels=&projects=&template=feature-request.md),
or documentation enhancements.

## Security

We take the security of our project very seriously. If you have any concerns about security or wish to report a security vulnerability, please refer to our [Security Policy](SECURITY.md). This policy provides detailed information on how security issues are handled within our project and guides you through the process of reporting a security vulnerability.

## License

Copyright 2024 Onchain Foundation

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

```shell
    http://www.apache.org/licenses/LICENSE-2.0
```

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
