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
        /// @notice L2 Lisk token address.
        address L2LiskToken;
    }

    /// @notice This struct is used to read and write addresses related to swap-and-bridge feature to JSON file.
    struct SwapAndBridgeAddressesConfig {
        /// @notice L2WdivETH contract.
        address l2WdivETH;
        /// @notice The L1 swapAndBridge contract for Diva.
        address swapAndBridgeDiva;
        /// @notice The L1 swapAndBridge contract for Lido.
        address swapAndBridgeLido;
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
        string memory finalJson = vm.serializeAddress(json, "L2LiskToken", cfg.L2LiskToken);
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

    /// @notice This function reads swap and bridge addresses from JSON file.
    /// @return SwapAndBridgeAddressesConfig struct containing swap and bridge addresses.
    function readSwapAndBridgeAddressesFile() external view returns (SwapAndBridgeAddressesConfig memory) {
        string memory network = getNetworkType();
        string memory root = vm.projectRoot();
        string memory addressPath = string.concat(root, "/deployment/", network, "/swapAndBridgeAddresses.json");
        string memory addressJson = vm.readFile(addressPath);
        // bytes memory addressRaw = vm.parseJson(addressJson);

        SwapAndBridgeAddressesConfig memory swapAndBridgeAddressesConfig;

        try vm.parseJsonAddress(addressJson, ".l2WdivETH") returns (address l2WdivETH) {
            swapAndBridgeAddressesConfig.l2WdivETH = l2WdivETH;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".swapAndBridgeDiva") returns (address swapAndBridgeDiva) {
            swapAndBridgeAddressesConfig.swapAndBridgeDiva = swapAndBridgeDiva;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".swapAndBridgeLido") returns (address swapAndBridgeLido) {
            swapAndBridgeAddressesConfig.swapAndBridgeLido = swapAndBridgeLido;
        } catch { }

        return swapAndBridgeAddressesConfig;

        // return abi.decode(addressRaw, (SwapAndBridgeAddressesConfig));
    }

    /// @notice This function writes swap and bridge addresses to JSON file.
    /// @param cfg SwapAndBridgeAddressesConfig struct containing swap and bridge addresses which will be written to
    /// JSON file.
    function writeSwapAndBridgeAddressesFile(SwapAndBridgeAddressesConfig memory cfg) external {
        string memory network = getNetworkType();
        string memory json = "";
        vm.serializeAddress(json, "l2WdivETH", cfg.l2WdivETH);
        vm.serializeAddress(json, "swapAndBridgeDiva", cfg.swapAndBridgeDiva);
        string memory finalJson = vm.serializeAddress(json, "swapAndBridgeLido", cfg.swapAndBridgeLido);
        finalJson.write(string.concat("deployment/", network, "/swapAndBridgeAddresses.json"));
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
