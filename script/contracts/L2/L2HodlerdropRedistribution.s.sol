// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { L2AirdropV2 } from "src/L2/L2HodlerdropRedistribution.sol";
import "script/contracts/Utils.sol";

/// @title L2AirdropScript - L2 Airdrop deployment script
/// @notice This contract is used to deploy L2 Airdrop contract.
contract L2AirdropScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2 Airdrop contract.
    function run() public {
        // Deployer's private key. Owner of the L2 Airdrop. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2 Airdrop contract...");

        // address, the ownership of L2 Airdrop contract is transferred to after deployment
        address newOwnerAddress = vm.envAddress("L2_AIRDROP_OWNER_ADDRESS");
        assert(newOwnerAddress != address(0));
        console2.log("L2 Airdrop owner address: %s (after ownership will be accepted)", newOwnerAddress);

        // get L2 Airdrop wallet address where LSK tokens will be transferred after airdrop period is over
        address ecosystemFundWalletAddress = vm.envAddress("L2_ECOSYSTEM_FUND_WALLET_ADDRESS");
        assert(ecosystemFundWalletAddress != address(0));
        console2.log("L2 Airdrop wallet address: %s", ecosystemFundWalletAddress);

        // get L2LiskToken contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile(utils.getL2AddressesFilePath());
        assert(l2AddressesConfig.L2LiskToken != address(0));
        console2.log("L2 Lisk token address: %s", l2AddressesConfig.L2LiskToken);

        // get L2Claim contract address
        assert(l2AddressesConfig.L2ClaimContract != address(0));
        console2.log("L2 Claim address: %s", l2AddressesConfig.L2ClaimContract);

        // get L2LockingPosition contract address
        assert(l2AddressesConfig.L2LockingPosition != address(0));
        console2.log("L2 Locking Position address: %s", l2AddressesConfig.L2LockingPosition);

        // get L2VotingPower contract address
        assert(l2AddressesConfig.L2VotingPower != address(0));
        console2.log("L2 Voting Power address: %s", l2AddressesConfig.L2VotingPower);

        // get Merkle root
        Utils.MerkleRoot memory merkleRoot = utils.readMerkleRootFile("airdrop-merkle-root.json");
        assert(merkleRoot.merkleRoot != bytes32(0));
        console2.log("Merkle root: %s", vm.toString(merkleRoot.merkleRoot));

        // deploy L2AirdropV2 contract, set Merkle root and transfer its ownership; new owner has to accept ownership to
        // become the owner of the contract
        vm.startBroadcast(deployerPrivateKey);
        L2AirdropV2 l2AirdropV2 = new L2AirdropV2(
            l2AddressesConfig.L2LiskToken, l2AddressesConfig.L2LockingPosition, ecosystemFundWalletAddress
        );
        l2AirdropV2.setMerkleRoot(merkleRoot.merkleRoot);
        l2AirdropV2.transferOwnership(newOwnerAddress);
        vm.stopBroadcast();

        assert(address(l2AirdropV2) != address(0));
        assert(l2AirdropV2.l2LiskTokenAddress() == l2AddressesConfig.L2LiskToken);
        assert(l2AirdropV2.l2LockingPositionAddress() == l2AddressesConfig.L2LockingPosition);
        assert(l2AirdropV2.ecosystemFundAddress() == ecosystemFundWalletAddress);
        assert(l2AirdropV2.merkleRoot() == merkleRoot.merkleRoot);
        assert(l2AirdropV2.owner() == vm.addr(deployerPrivateKey));
        assert(l2AirdropV2.pendingOwner() == newOwnerAddress);

        console2.log("L2 Airdrop successfully deployed!");
        console2.log("L2 Airdrop address: %s", address(l2AirdropV2));

        // write L2AirdropV2 address to l2addresses.json
        l2AddressesConfig.L2AirdropV2 = address(l2AirdropV2);
        utils.writeL2AddressesFile(l2AddressesConfig, utils.getL2AddressesFilePath());
    }
}
