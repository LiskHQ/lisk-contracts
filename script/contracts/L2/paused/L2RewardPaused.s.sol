// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2RewardPaused } from "src/L2/paused/L2RewardPaused.sol";
import "script/contracts/Utils.sol";

/// @title L2RewardPausedScript - L2RewardPaused contract deployment script
/// @notice This contract is used to deploy L2RewardPaused contract and write its address to JSON file.
contract L2RewardPausedScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2RewardPaused contract and writes its address to JSON file.
    function run() public {
        // Deployer's private key. This key is used to deploy the contract.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Validate L2RewardPaused contract if it is implemented correctly so that it may be used as new
        // implementation for the proxy contract.
        Options memory opts;
        opts.referenceContract = "L2Reward.sol";
        opts.unsafeAllow = "constructor";
        Upgrades.validateUpgrade("L2RewardPaused.sol", opts);

        console2.log("Deploying L2 RewardPaused contract...");

        // deploy L2RewardPaused contract
        vm.startBroadcast(deployerPrivateKey);
        L2RewardPaused l2RewardPaused = new L2RewardPaused();
        vm.stopBroadcast();

        assert(address(l2RewardPaused) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(l2RewardPaused.proxiableUUID() == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));

        console2.log("L2 RewardPaused contract successfully deployed!");
        console2.log("L2 RewardPaused address: %s", address(l2RewardPaused));

        // write L2RewardPaused address to l2addresses.json
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile(utils.getL2AddressesFilePath());
        l2AddressesConfig.L2RewardPaused = address(l2RewardPaused);
        utils.writeL2AddressesFile(l2AddressesConfig, utils.getL2AddressesFilePath());
    }
}
