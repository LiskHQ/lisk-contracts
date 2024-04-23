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
        /// @notice L2 Reward contract (in Proxy), which users interact with.
        address L2Reward;
        /// @notice The current implementation of L2 Reward contract.
        address L2RewardImplementation;
        /// @notice L2 Staking contract (in Proxy), which users interact with.
        address L2Staking;
        /// @notice The current implementation of L2 Staking contract.
        address L2StakingImplementation;
        /// @notice L2 Timelock Controller address.
        address L2TimelockController;
        /// @notice The Current implementation of L2 Vesting Wallet.
        address L2VestingWalletImplementation;
        /// @notice L2 Voting Power contract (in Proxy), which users interact with.
        address L2VotingPower;
        /// @notice The Current implementation of L2 Voting Power Contract.
        address L2VotingPowerImplementation;
    }

    /// @notice This struct is used to read and write addresses related to swap-and-bridge feature to JSON file.
    struct SwapAndBridgeAddressesConfig {
        /// @notice L2WdivETH contract.
        address L2WdivETH;
        /// @notice The L1 swapAndBridge contract for Diva.
        address SwapAndBridgeDiva;
        /// @notice The L1 swapAndBridge contract for Lido.
        address SwapAndBridgeLido;
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

    /// @notice This struct is used to store a single Vesting Plan.
    struct VestingPlan {
        /// @notice Amount of LSK tokens to be vested.
        uint256 amount;
        /// @notice Identifier of beneficiary address, which would match the address in JSON file.
        string beneficiaryAddressTag;
        /// @notice Duration of the Vesting Plan in Days.
        uint64 durationDays;
        /// @notice Name of the Vesting Plan.
        string name;
        /// @notice Start timestamp of the Vesting Plan.
        uint64 startTimestamp;
    }

    /// @notice This struct is when storing deployed Vesting Wallet Contract to file.
    struct VestingWallet {
        /// @notice Name of the Vesting Plan.
        string name;
        /// @notice Contract address of the Vesting Wallet.
        address vestingWalletAddress;
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

        L1AddressesConfig memory l1AddressesConfig;

        try vm.parseJsonAddress(addressJson, ".L1LiskToken") returns (address l1LiskToken) {
            l1AddressesConfig.L1LiskToken = l1LiskToken;
        } catch { }

        return l1AddressesConfig;
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

        L2AddressesConfig memory l2AddressesConfig;

        try vm.parseJsonAddress(addressJson, ".L2ClaimContract") returns (address l2ClaimContract) {
            l2AddressesConfig.L2ClaimContract = l2ClaimContract;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".L2ClaimImplementation") returns (address l2ClaimImplementation) {
            l2AddressesConfig.L2ClaimImplementation = l2ClaimImplementation;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".L2Governor") returns (address l2Governor) {
            l2AddressesConfig.L2Governor = l2Governor;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".L2GovernorImplementation") returns (address l2GovernorImplementation) {
            l2AddressesConfig.L2GovernorImplementation = l2GovernorImplementation;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".L2LiskToken") returns (address l2LiskToken) {
            l2AddressesConfig.L2LiskToken = l2LiskToken;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".L2LockingPosition") returns (address l2LockingPosition) {
            l2AddressesConfig.L2LockingPosition = l2LockingPosition;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".L2LockingPositionImplementation") returns (
            address l2LockingPositionImplementation
        ) {
            l2AddressesConfig.L2LockingPositionImplementation = l2LockingPositionImplementation;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".L2RewardImplementation") returns (address l2RewardImplementation) {
            l2AddressesConfig.L2RewardImplementation = l2RewardImplementation;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".L2Reward") returns (address l2Reward) {
            l2AddressesConfig.L2Reward = l2Reward;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".L2Staking") returns (address l2Staking) {
            l2AddressesConfig.L2Staking = l2Staking;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".L2StakingImplementation") returns (address l2StakingImplementation) {
            l2AddressesConfig.L2StakingImplementation = l2StakingImplementation;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".L2TimelockController") returns (address l2TimelockController) {
            l2AddressesConfig.L2TimelockController = l2TimelockController;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".L2VestingWalletImplementation") returns (
            address l2VestingWalletImplementation
        ) {
            l2AddressesConfig.L2VestingWalletImplementation = l2VestingWalletImplementation;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".L2VotingPower") returns (address l2VotingPower) {
            l2AddressesConfig.L2VotingPower = l2VotingPower;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".L2VotingPowerImplementation") returns (
            address l2VotingPowerImplementation
        ) {
            l2AddressesConfig.L2VotingPowerImplementation = l2VotingPowerImplementation;
        } catch { }

        return l2AddressesConfig;
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
        vm.serializeAddress(json, "L2Reward", cfg.L2Reward);
        vm.serializeAddress(json, "L2RewardImplementation", cfg.L2RewardImplementation);
        vm.serializeAddress(json, "L2Staking", cfg.L2Staking);
        vm.serializeAddress(json, "L2StakingImplementation", cfg.L2StakingImplementation);
        vm.serializeAddress(json, "L2TimelockController", cfg.L2TimelockController);
        vm.serializeAddress(json, "L2VestingWalletImplementation", cfg.L2VestingWalletImplementation);
        vm.serializeAddress(json, "L2VotingPower", cfg.L2VotingPower);
        string memory finalJson =
            vm.serializeAddress(json, "L2VotingPowerImplementation", cfg.L2VotingPowerImplementation);

        finalJson.write(string.concat("deployment/", network, "/l2addresses.json"));
    }

    /// @notice This function writes Vesting Wallets to JSON file.
    /// @param vestingWallets Array of Vesting Wallets which will be written to JSON file.
    function writeVestingWalletsFile(VestingWallet[] memory vestingWallets) external {
        string memory network = getNetworkType();

        string memory json = "vestingWallets";
        string memory finalJson;
        for (uint256 i = 0; i < vestingWallets.length; i++) {
            VestingWallet memory vestingWallet = vestingWallets[i];
            finalJson = vm.serializeAddress(json, vestingWallet.name, vestingWallet.vestingWalletAddress);
        }
        finalJson.write(string.concat("deployment/", network, "/vestingWallets.json"));
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
    /// @param fileName Name of the file containing accounts.
    /// @return Accounts struct containing accounts.
    function readAccountsFile(string memory fileName) external view returns (Accounts memory) {
        string memory network = getNetworkType();
        string memory root = vm.projectRoot();
        string memory accountsPath = string.concat(root, "/script/data/", network, "/", fileName);
        string memory accountsJson = vm.readFile(accountsPath);
        bytes memory accountsRaw = vm.parseJson(accountsJson);
        return abi.decode(accountsRaw, (Accounts));
    }

    /// @notice This function returns vesting address from JSON file by providing vestingAddressTag
    /// @param vestingAddressTag Identifier of the Vesting Address
    /// @return Vesting Address corresponding to vestingAddressTag.
    function readVestingAddress(string memory vestingAddressTag) external view returns (address) {
        string memory network = getNetworkType();
        string memory root = vm.projectRoot();
        string memory vestingAddressesPath = string.concat(root, "/script/data/", network, "/vestingPlans.json");
        string memory vestingAddressesJson = vm.readFile(vestingAddressesPath);
        bytes memory vestingAddressRaw =
            vestingAddressesJson.parseRaw(string.concat(".vestingAddresses.", vestingAddressTag));
        return abi.decode(vestingAddressRaw, (address));
    }

    /// @notice This function reads Vesting Plans from JSON file.
    /// @return An array of Vesting Plans.
    function readVestingPlansFile() external view returns (VestingPlan[] memory) {
        string memory network = getNetworkType();
        string memory root = vm.projectRoot();
        string memory vestingPlansPath = string.concat(root, "/script/data/", network, "/vestingPlans.json");
        string memory vestingPlansJson = vm.readFile(vestingPlansPath);
        bytes memory vestingPlansRaw = vestingPlansJson.parseRaw(string.concat(".vestingPlans"));
        return abi.decode(vestingPlansRaw, (VestingPlan[]));
    }

    /// @notice This function reads Vesting Wallet Address from JSON file.
    /// @param vestingWalletName Name of the Vesting Wallet.
    /// @return Vesting Wallet Address.
    function readVestingWalletAddress(string memory vestingWalletName) external view returns (address) {
        string memory network = getNetworkType();
        string memory root = vm.projectRoot();
        string memory vestingWalletsPath = string.concat(root, "/deployment/", network, "/vestingWallets.json");
        string memory vestingWalletsJson = vm.readFile(vestingWalletsPath);
        return vm.parseJsonAddress(vestingWalletsJson, string.concat(".['", vestingWalletName, "']"));
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

    /// @notice This function reads swap and bridge addresses from JSON file.
    /// @return SwapAndBridgeAddressesConfig struct containing swap and bridge addresses.
    function readSwapAndBridgeAddressesFile() external view returns (SwapAndBridgeAddressesConfig memory) {
        string memory network = getNetworkType();
        string memory root = vm.projectRoot();
        string memory addressPath = string.concat(root, "/deployment/", network, "/swapAndBridgeAddresses.json");
        string memory addressJson = vm.readFile(addressPath);

        SwapAndBridgeAddressesConfig memory swapAndBridgeAddressesConfig;

        try vm.parseJsonAddress(addressJson, ".l2WdivETH") returns (address l2WdivETH) {
            swapAndBridgeAddressesConfig.L2WdivETH = l2WdivETH;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".swapAndBridgeDiva") returns (address swapAndBridgeDiva) {
            swapAndBridgeAddressesConfig.SwapAndBridgeDiva = swapAndBridgeDiva;
        } catch { }

        try vm.parseJsonAddress(addressJson, ".swapAndBridgeLido") returns (address swapAndBridgeLido) {
            swapAndBridgeAddressesConfig.SwapAndBridgeLido = swapAndBridgeLido;
        } catch { }

        return swapAndBridgeAddressesConfig;
    }

    /// @notice This function writes swap and bridge addresses to JSON file.
    /// @param cfg SwapAndBridgeAddressesConfig struct containing swap and bridge addresses which will be written to
    ///            JSON file.
    function writeSwapAndBridgeAddressesFile(SwapAndBridgeAddressesConfig memory cfg) external {
        string memory network = getNetworkType();
        string memory json = "";
        vm.serializeAddress(json, "l2WdivETH", cfg.L2WdivETH);
        vm.serializeAddress(json, "swapAndBridgeDiva", cfg.SwapAndBridgeDiva);
        string memory finalJson = vm.serializeAddress(json, "swapAndBridgeLido", cfg.SwapAndBridgeLido);
        finalJson.write(string.concat("deployment/", network, "/swapAndBridgeAddresses.json"));
    }
}
