// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2StakingPaused } from "src/L2/paused/L2StakingPaused.sol";
import "script/contracts/Utils.sol";

/// @title L2StakingPausedScript - L2StakingPaused contract deployment script
/// @notice This contract is used to deploy L2StakingPaused contract and write its address to JSON file.
contract L2StakingPausedScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2StakingPaused contract and writes its address to JSON file.
    function run() public {
        // Deployer's private key. This key is used to deploy the contract.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Validate L2StakingPaused contract if it is implemented correctly so that it may be used as new
        // implementation for the proxy contract.
        Options memory opts;
        opts.referenceContract = "L2Staking.sol";
        opts.unsafeAllow = "constructor";
        Upgrades.validateUpgrade("L2StakingPaused.sol", opts);

        console2.log("Deploying L2 StakingPaused contract...");

        // deploy L2StakingPaused contract
        vm.startBroadcast(deployerPrivateKey);
        L2StakingPaused l2StakingPaused = new L2StakingPaused();
        vm.stopBroadcast();

        assert(address(l2StakingPaused) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(l2StakingPaused.proxiableUUID() == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));

        console2.log("L2 StakingPaused contract successfully deployed!");
        console2.log("L2 StakingPaused address: %s", address(l2StakingPaused));

        // write L2StakingPaused address to l2addresses.json
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        l2AddressesConfig.L2StakingPaused = address(l2StakingPaused);
        utils.writeL2AddressesFile(l2AddressesConfig);
    }
}
