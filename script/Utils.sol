// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";

/// @title Utils
/// @notice This contract is used to read and write different L1 and L2 addresses of deployed contracts to JSON files.
contract Utils is Script {
    using stdJson for string;

    /// @notice This struct is used to read and write L1 addresses to JSON file.
    struct L1AddressesConfig {
        /// @notice L1 Lisk token address.
        address L1LiskToken;
    }

    /// @notice This struct is used to read and write L2 addresses to JSON file.
    struct L2AddressesConfig {
        /// @notice L2 Claim contract (in Proxy), which users interact with.
        address L2ClaimContract;
        /// @notice The Current implementation of L2 Claim Contract.
        address L2ClaimImplementation;
        /// @notice L2 Lisk token address.
        address L2LiskToken;
    }

    /// @notice This struct is used to read MerkleTree from JSON file.
    struct MerkleTree {
        bytes32 merkleRoot;
    }

    /// @notice This struct is used to read accounts from JSON file. These accounts are used to transfer L1 Lisk tokens
    ///         to them after all contracts are deployed.
    struct Accounts {
        /// @notice Array of L1 addresses and amounts of LSK tokens to be transferred to them.
        FundedAccount[] l1Addresses;
        /// @notice Array of L2 addresses and amounts of LSK tokens to be transferred to them.
        FundedAccount[] l2Addresses;
    }

    /// @notice This struct is used to read a single account from JSON file.
    struct FundedAccount {
        /// @notice Account address.
        address addr;
        /// @notice Amount of LSK tokens to be transferred to the account.
        uint256 amount;
    }

    /// @notice This function reads L1 addresses from JSON file.
    /// @return L1AddressesConfig struct containing L1 addresses.
    function readL1AddressesFile() external view returns (L1AddressesConfig memory) {
        string memory root = vm.projectRoot();
        string memory addressPath = string.concat(root, "/deployment/l1addresses.json");
        string memory addressJson = vm.readFile(addressPath);
        bytes memory addressRaw = vm.parseJson(addressJson);
        return abi.decode(addressRaw, (L1AddressesConfig));
    }

    /// @notice This function writes L1 addresses to JSON file.
    /// @param cfg L1AddressesConfig struct containing L1 addresses which will be written to JSON file.
    function writeL1AddressesFile(L1AddressesConfig memory cfg) external {
        string memory json = "";
        string memory finalJson = vm.serializeAddress(json, "L1LiskToken", cfg.L1LiskToken);
        finalJson.write(string.concat("deployment/l1addresses.json"));
    }

    /// @notice This function reads L2 addresses from JSON file.
    /// @return L2AddressesConfig struct containing L2 addresses.
    function readL2AddressesFile() external view returns (L2AddressesConfig memory) {
        string memory root = vm.projectRoot();
        string memory addressPath = string.concat(root, "/deployment/l2addresses.json");
        string memory addressJson = vm.readFile(addressPath);
        bytes memory addressRaw = vm.parseJson(addressJson);
        return abi.decode(addressRaw, (L2AddressesConfig));
    }

    /// @notice This function writes L2 addresses to JSON file.
    /// @param cfg L2AddressesConfig struct containing L2 addresses which will be written to JSON file.
    function writeL2AddressesFile(L2AddressesConfig memory cfg) external {
        string memory json = "";
        vm.serializeAddress(json, "L2ClaimContract", cfg.L2ClaimContract);
        vm.serializeAddress(json, "L2ClaimImplementation", cfg.L2ClaimImplementation);
        string memory finalJson = vm.serializeAddress(json, "L2LiskToken", cfg.L2LiskToken);
        finalJson.write(string.concat("deployment/l2addresses.json"));
    }

    /// @notice This function reads MerkleTree from JSON file.
    /// @return MerkleTree struct containing merkle root.
    function readMerkleTreeFile() external view returns (MerkleTree memory) {
        string memory root = vm.projectRoot();
        string memory merkleTreePath = string.concat(root, "/script/data/devnet/merkleTree.json");
        string memory merkleTreeJson = vm.readFile(merkleTreePath);
        bytes memory merkleTreeRaw = vm.parseJson(merkleTreeJson);
        return abi.decode(merkleTreeRaw, (MerkleTree));
    }

    /// @notice This function reads accounts from JSON file.
    /// @return Accounts struct containing accounts.
    function readAccountsFile() external view returns (Accounts memory) {
        string memory root = vm.projectRoot();
        string memory accountsPath = string.concat(root, "/script/data/devnet/accounts.json");
        string memory accountsJson = vm.readFile(accountsPath);
        bytes memory accountsRaw = vm.parseJson(accountsJson);
        return abi.decode(accountsRaw, (Accounts));
    }
}
