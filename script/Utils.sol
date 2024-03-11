// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

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
        /// @notice L2 Governor contract (in Proxy), which users interact with.
        address L2Governor;
        /// @notice The Current implementation of L2 Governor Contract.
        address L2GovernorImplementation;
        /// @notice L2 Lisk token address.
        address L2LiskToken;
        /// @notice L2 Locking Position contract (in Proxy), which users interact with.
        address L2LockingPosition;
        /// @notice The Current implementation of L2 Locking Position Contract.
        address L2LockingPositionImplementation;
        /// @notice L2 Staking contract (in proxy), which users interact with.
        address L2Staking;
        /// @notice The current implementation of L2 Staking contract.
        address L2StakingImplementation;
        /// @notice L2 Timelock Controller address.
        address L2TimelockController;
        /// @notice L2 Voting Power contract (in Proxy), which users interact with.
        address L2VotingPower;
        /// @notice The Current implementation of L2 Voting Power Contract.
        address L2VotingPowerImplementation;
    }

    /// @notice This struct is used to read MerkleRoot from JSON file.
    struct MerkleRoot {
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

    /// @notice This function gets network type from .env file. It should be either mainnet, testnet or devnet.
    /// @return string containing network type.
    function getNetworkType() public view returns (string memory) {
        string memory network = vm.envString("NETWORK");
        require(
            keccak256(bytes(network)) == keccak256(bytes("mainnet"))
                || keccak256(bytes(network)) == keccak256(bytes("testnet"))
                || keccak256(bytes(network)) == keccak256(bytes("devnet")),
            "Utils: Invalid network type"
        );
        return network;
    }

    /// @notice This function reads L1 addresses from JSON file.
    /// @return L1AddressesConfig struct containing L1 addresses.
    function readL1AddressesFile() external view returns (L1AddressesConfig memory) {
        string memory network = getNetworkType();
        string memory root = vm.projectRoot();
        string memory addressPath = string.concat(root, "/deployment/", network, "/l1addresses.json");
        string memory addressJson = vm.readFile(addressPath);
        bytes memory addressRaw = vm.parseJson(addressJson);
        return abi.decode(addressRaw, (L1AddressesConfig));
    }

    /// @notice This function writes L1 addresses to JSON file.
    /// @param cfg L1AddressesConfig struct containing L1 addresses which will be written to JSON file.
    function writeL1AddressesFile(L1AddressesConfig memory cfg) external {
        string memory network = getNetworkType();
        string memory json = "";
        string memory finalJson = vm.serializeAddress(json, "L1LiskToken", cfg.L1LiskToken);
        finalJson.write(string.concat("deployment/", network, "/l1addresses.json"));
    }

    /// @notice This function reads L2 addresses from JSON file.
    /// @return L2AddressesConfig struct containing L2 addresses.
    function readL2AddressesFile() external view returns (L2AddressesConfig memory) {
        string memory network = getNetworkType();
        string memory root = vm.projectRoot();
        string memory addressPath = string.concat(root, "/deployment/", network, "/l2addresses.json");
        string memory addressJson = vm.readFile(addressPath);
        bytes memory addressRaw = vm.parseJson(addressJson);
        return abi.decode(addressRaw, (L2AddressesConfig));
    }

    /// @notice This function writes L2 addresses to JSON file.
    /// @param cfg L2AddressesConfig struct containing L2 addresses which will be written to JSON file.
    function writeL2AddressesFile(L2AddressesConfig memory cfg) external {
        string memory network = getNetworkType();
        string memory json = "";
        vm.serializeAddress(json, "L2ClaimContract", cfg.L2ClaimContract);
        vm.serializeAddress(json, "L2ClaimImplementation", cfg.L2ClaimImplementation);
        vm.serializeAddress(json, "L2Governor", cfg.L2Governor);
        vm.serializeAddress(json, "L2GovernorImplementation", cfg.L2GovernorImplementation);
        vm.serializeAddress(json, "L2LiskToken", cfg.L2LiskToken);
        vm.serializeAddress(json, "L2LockingPosition", cfg.L2LockingPosition);
        vm.serializeAddress(json, "L2LockingPositionImplementation", cfg.L2LockingPositionImplementation);
        vm.serializeAddress(json, "L2Staking", cfg.L2Staking);
        vm.serializeAddress(json, "L2StakingImplementation", cfg.L2StakingImplementation);
        vm.serializeAddress(json, "L2TimelockController", cfg.L2TimelockController);
        vm.serializeAddress(json, "L2VotingPower", cfg.L2VotingPower);
        string memory finalJson =
            vm.serializeAddress(json, "L2VotingPowerImplementation", cfg.L2VotingPowerImplementation);
        finalJson.write(string.concat("deployment/", network, "/l2addresses.json"));
    }

    /// @notice This function reads MerkleRoot from JSON file.
    /// @return MerkleRoot struct containing merkle root only.
    function readMerkleRootFile() external view returns (MerkleRoot memory) {
        string memory network = getNetworkType();
        string memory root = vm.projectRoot();
        string memory merkleRootPath = string.concat(root, "/script/data/", network, "/merkle-root.json");
        string memory merkleRootJson = vm.readFile(merkleRootPath);
        bytes memory merkleRootRaw = vm.parseJson(merkleRootJson);
        return abi.decode(merkleRootRaw, (MerkleRoot));
    }

    /// @notice This function reads accounts from JSON file.
    /// @return Accounts struct containing accounts.
    function readAccountsFile() external view returns (Accounts memory) {
        string memory network = getNetworkType();
        string memory root = vm.projectRoot();
        string memory accountsPath = string.concat(root, "/script/data/", network, "/accounts.json");
        string memory accountsJson = vm.readFile(accountsPath);
        bytes memory accountsRaw = vm.parseJson(accountsJson);
        return abi.decode(accountsRaw, (Accounts));
    }

    /// @notice This function returns salt as a string. keccak256 of this string is used as salt for calculating
    ///         deterministic address of a contract.
    /// @dev This function may be used for logging purposes.
    /// @param contractName Name of the contract.
    /// @return string salt.
    function getPreHashedSalt(string memory contractName) public view returns (string memory) {
        return string.concat(vm.envString("DETERMINISTIC_ADDRESS_SALT"), "_", contractName);
    }

    /// @notice This function calculates and returns salt which is used to have a deterministic address for a contract.
    /// @param contractName Name of the contract.
    /// @return bytes32 salt.
    function getSalt(string memory contractName) public view returns (bytes32) {
        return keccak256(abi.encodePacked(getPreHashedSalt(contractName)));
    }
}
