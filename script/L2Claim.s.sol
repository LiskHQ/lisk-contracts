// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { L2Claim } from "src/L2/L2Claim.sol";
import { UUPSProxy } from "src/utils/UUPSProxy.sol";
import "script/Utils.sol";

/// @title L2ClaimScript - L2 Claim contract deployment script
/// @notice This contract is used to deploy L2 Claim contract and write its address to JSON file.
contract L2ClaimScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2 Claim contract and writes its address to JSON file.
    function run() public {
        // Deployer's private key. Owner of the Claim contract which can perform upgrades. PRIVATE_KEY is set in .env
        // file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Simulation: Deploying L2 Claim contract...");

        // get L2LiskToken contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        console2.log("Simulation: L2 Lisk token address: %s", l2AddressesConfig.L2LiskToken);

        // get MerkleTree details
        Utils.MerkleTree memory merkleTree = utils.readMerkleTreeFile();
        console2.log("MerkleTree Root: %s", vm.toString(merkleTree.merkleRoot));

        // deploy L2Claim Implementation Contract
        vm.startBroadcast(deployerPrivateKey);
        L2Claim l2ClaimImplementation = new L2Claim();
        vm.stopBroadcast();
        assert(address(l2ClaimImplementation) != address(0));
        assert(
            l2ClaimImplementation.proxiableUUID() == 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
        );

        // deploy L2Claim Proxy Contract
        vm.startBroadcast(deployerPrivateKey);
        UUPSProxy l2ClaimProxy = new UUPSProxy(address(l2ClaimImplementation), "");
        vm.stopBroadcast();
        assert(address(l2ClaimProxy) != address(0));

        // wrap in ABI to support easier calls
        vm.startBroadcast(deployerPrivateKey);
        L2Claim l2Claim = L2Claim(address(l2ClaimProxy));
        vm.stopBroadcast();

        // initialize the proxy contract (calls the initialize function in L2Claim)
        vm.startBroadcast(deployerPrivateKey);
        l2Claim.initialize(l2AddressesConfig.L2LiskToken, merkleTree.merkleRoot);
        vm.stopBroadcast();
        assert(address(l2Claim.l2LiskToken()) == l2AddressesConfig.L2LiskToken);
        assert(l2Claim.merkleRoot() == merkleTree.merkleRoot);

        console2.log("Simulation: L2 Claim contract successfully deployed!");
        console2.log("Simulation: L2 Claim (Implementation) address: %s", address(l2ClaimImplementation));
        console2.log("Simulation: L2 Claim (Proxy) address: %s", address(l2ClaimProxy));

        // write L2ClaimContract address to l2addresses.json
        l2AddressesConfig.L2ClaimImplementation = address(l2ClaimImplementation);
        l2AddressesConfig.L2ClaimContract = address(l2ClaimProxy);
        utils.writeL2AddressesFile(l2AddressesConfig);
    }
}
