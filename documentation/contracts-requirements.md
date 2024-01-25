# Requirements for Smart Contracts

This document contains a set of requirements for smart contracts inside this repository. It outlines the specific criteria and standards that need to be met in the implementation of these smart contracts. The document serves as a guideline to ensure that the smart contracts are designed and executed efficiently, securely, and in compliance with the necessary technical specifications. It is an essential reference for developers and stakeholders involved in the project.

## Requirements for L1 Lisk Token

- L1 Lisk token smart contract should not be upgradable smart contract.
- Total supply of L1 Lisk tokens should be set to 300,000,000 (300 millions).
- There should exist two roles inside a smart contract - admin and burner.
  - Admin can add or remove addresses to and from burner role.
  - Only burner role is able to burn L1 Lisk tokens.
  - There is no addresses associated to burner role when L1 Lisk token smart contract is deployed.
- L1 Lisk token smart contract should not support any new token minting.
- L1 Lisk token smart contract should support token burning. Only role which can burn tokens is burner.
- L1 Lisk token smart contract should support permit functionality allowing approvals to be made via signatures.
- The newly minted tokens for the Onchain Foundation are created on Ethereum L1 network and are not sent to the Claim contract.
- The newly minted tokens for the Onchain Foundation are not all minted to one addresses, but instead several amounts can be minted and send to multiple addresses on L1 or L2 networks.

## Requirements for L2 Lisk Token

- L2 Lisk token smart contract should be a bridged smart contract. Its counterpart is L1 Lisk token smart contract.
- There should initially be no tokens minted when the L2 Lisk token smart contract is deployed.
- Only the Standard Bridge has the authorization to mint and burn tokens during their deposit or withdrawal from and to the Ethereum L1 network.
- L2 Lisk token smart contract should support permit functionality allowing approvals to be made via signatures.
- L2 Lisk token smart contract should have the same address across different L2 networks. We might want to deploy L2 Lisk token smart contract also to some of the Superchain networks in the future.

## Requirements for Claim Smart Contract

- Claim smart contract should be deployed on Lisk L2 network.
- Claim smart contract should be upgradeable smart contract. Upgrades can only be performed by some authorized role (owner, admin, etc).
- Claim smart contract should contain a Merkle Root, derived from a merkle tree constructed using a snapshot data from the Lisk v4 network.
- Users should be able to claim their tokens from regular and multisig Lisk accounts.
- Each Lisk account should be eligible for only a single claim (no double claims for the same Lisk address).
- Claim smart contract should have an option that after a claims window of 2 years, the unclaimed tokens could be moved to the Lisk DAO treasury. This tokens movement could only be performed by some authorized role (owner, admin, etc).
