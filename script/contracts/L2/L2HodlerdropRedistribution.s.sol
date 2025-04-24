// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { L2HodlerdropRedistribution } from "src/L2/L2HodlerdropRedistribution.sol";
import "script/contracts/Utils.sol";

/// @title L2AirdropScript - L2 Hodlerdrop Redistribution deployment script
/// @notice This contract is used to deploy L2 HodlerdropRedistribution contract.
contract L2AirdropScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2 HodlerdropRedistribution contract.
    function run() public {
        // Deployer's private key. Owner of the L2 HodlerdropRedistribution. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2 HodlerdropRedistribution contract...");

        // address, the ownership of L2 HodlerdropRedistribution contract is transferred to after deployment
        address newOwnerAddress = vm.envAddress("L2_HODLERDROP_REDISTRIBUTION_OWNER_ADDRESS");
        assert(newOwnerAddress != address(0));
        console2.log(
            "L2 HodlerdropRedistribution owner address: %s (after ownership will be accepted)", newOwnerAddress
        );

        // get L2 Ecosystem Fund wallet address where LSK tokens will be transferred after Hodlerdrop period is over
        address ecosystemFundWalletAddress = vm.envAddress("L2_ECOSYSTEM_FUND_WALLET_ADDRESS");
        assert(ecosystemFundWalletAddress != address(0));
        console2.log("L2 Ecosystem Fund wallet address: %s", ecosystemFundWalletAddress);

        // get L2LiskToken contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile(utils.getL2AddressesFilePath());
        assert(l2AddressesConfig.L2LiskToken != address(0));
        console2.log("L2 Lisk token address: %s", l2AddressesConfig.L2LiskToken);

        // get L2LockingPosition contract address
        assert(l2AddressesConfig.L2LockingPosition != address(0));
        console2.log("L2 Locking Position address: %s", l2AddressesConfig.L2LockingPosition);

        // get Merkle root
        Utils.MerkleRoot memory merkleRoot = utils.readMerkleRootFile("hodlerdrop-merkle-root.json");
        assert(merkleRoot.merkleRoot != bytes32(0));
        console2.log("Merkle root: %s", vm.toString(merkleRoot.merkleRoot));

        // deploy L2HodlerdropRedistribution contract, set Merkle root and transfer its ownership; new owner has to
        // accept ownership to become the owner of the contract
        vm.startBroadcast(deployerPrivateKey);
        L2HodlerdropRedistribution l2HodlerdropRedistribution = new L2HodlerdropRedistribution(
            l2AddressesConfig.L2LiskToken, l2AddressesConfig.L2LockingPosition, ecosystemFundWalletAddress
        );
        l2HodlerdropRedistribution.setMerkleRoot(merkleRoot.merkleRoot);
        l2HodlerdropRedistribution.transferOwnership(newOwnerAddress);
        vm.stopBroadcast();

        assert(address(l2HodlerdropRedistribution) != address(0));
        assert(l2HodlerdropRedistribution.l2LiskTokenAddress() == l2AddressesConfig.L2LiskToken);
        assert(l2HodlerdropRedistribution.l2LockingPositionAddress() == l2AddressesConfig.L2LockingPosition);
        assert(l2HodlerdropRedistribution.ecosystemFundAddress() == ecosystemFundWalletAddress);
        assert(l2HodlerdropRedistribution.merkleRoot() == merkleRoot.merkleRoot);
        assert(l2HodlerdropRedistribution.owner() == vm.addr(deployerPrivateKey));
        assert(l2HodlerdropRedistribution.pendingOwner() == newOwnerAddress);

        console2.log("L2 Hodlerdrop Redistribution successfully deployed!");
        console2.log("L2 Hodlerdrop Redistribution address: %s", address(l2HodlerdropRedistribution));

        // write L2HodlerdropRedistribution address to l2addresses.json
        l2AddressesConfig.L2HodlerdropRedistribution = address(l2HodlerdropRedistribution);
        utils.writeL2AddressesFile(l2AddressesConfig, utils.getL2AddressesFilePath());
    }
}
