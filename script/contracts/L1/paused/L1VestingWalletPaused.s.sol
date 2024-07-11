// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L1VestingWalletPaused } from "src/L1/paused/L1VestingWalletPaused.sol";
import "script/contracts/Utils.sol";

/// @title L1VestingWalletPausedScript - L1VestingWalletPaused contract deployment script
/// @notice This contract is used to deploy L1VestingWalletPaused contract and write its address to JSON file.
contract L1VestingWalletPausedScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L1VestingWalletPaused contract and writes its address to JSON file.
    function run() public {
        // Deployer's private key. This key is used to deploy the contract.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Validate L1VestingWalletPaused contract if it is implemented correctly so that it may be used as new
        // implementation for the proxy contract.
        Options memory opts;
        opts.referenceContract = "L1VestingWallet.sol";
        opts.unsafeAllow = "constructor";
        Upgrades.validateUpgrade("L1VestingWalletPaused.sol", opts);

        console2.log("Deploying L1VestingWalletPaused contract...");

        // deploy L1VestingWalletPaused contract
        vm.startBroadcast(deployerPrivateKey);
        L1VestingWalletPaused l1VestingWalletPausedImplementation = new L1VestingWalletPaused();
        vm.stopBroadcast();

        assert(address(l1VestingWalletPausedImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l1VestingWalletPausedImplementation.proxiableUUID()
                == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        console2.log("L1VestingWalletPaused contract successfully deployed!");
        console2.log("L1VestingWalletPaused (Implementation) address: %s", address(l1VestingWalletPausedImplementation));

        // write L1VestingWalletPaused address to l1addresses.json
        Utils.L1AddressesConfig memory l1AddressesConfig = utils.readL1AddressesFile(utils.getL1AddressesFilePath());
        l1AddressesConfig.L1VestingWalletPaused = address(l1VestingWalletPausedImplementation);
        utils.writeL1AddressesFile(l1AddressesConfig, utils.getL1AddressesFilePath());
    }
}
