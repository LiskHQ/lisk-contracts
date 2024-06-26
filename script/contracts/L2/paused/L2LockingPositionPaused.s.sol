// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2LockingPositionPaused } from "src/L2/paused/L2LockingPositionPaused.sol";
import "script/contracts/Utils.sol";

/// @title L2LockingPositionPausedScript - L2LockingPositionPaused contract deployment script
/// @notice This contract is used to deploy L2LockingPositionPaused contract and write its address to JSON file.
contract L2LockingPositionPausedScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2LockingPositionPaused contract and writes its address to JSON file.
    function run() public {
        // Deployer's private key. This key is used to deploy the contract.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Validate L2LockingPositionPaused contract if it is implemented correctly so that it may be used as new
        // implementation for the proxy contract.
        Options memory opts;
        opts.referenceContract = "L2LockingPosition.sol";
        opts.unsafeAllow = "constructor";
        Upgrades.validateUpgrade("L2LockingPositionPaused.sol", opts);

        console2.log("Deploying L2 LockingPositionPaused contract...");

        // deploy L2LockingPositionPaused contract
        vm.startBroadcast(deployerPrivateKey);
        L2LockingPositionPaused l2LockingPositionPaused = new L2LockingPositionPaused();
        vm.stopBroadcast();

        assert(address(l2LockingPositionPaused) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2LockingPositionPaused.proxiableUUID() == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        console2.log("L2 LockingPositionPaused contract successfully deployed!");
        console2.log("L2 LockingPositionPaused address: %s", address(l2LockingPositionPaused));

        // write L2LockingPositionPaused address to l2addresses.json
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile();
        l2AddressesConfig.L2LockingPositionPaused = address(l2LockingPositionPaused);
        utils.writeL2AddressesFile(l2AddressesConfig);
    }
}
