// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L1VestingWalletEmergencyWithdraw } from "src/L1/paused/L1VestingWalletEmergencyWithdraw.sol";
import "script/contracts/Utils.sol";

/// @title L1VestingWalletEmergencyWithdrawScript - L1VestingWalletEmergencyWithdraw contract deployment script
/// @notice This contract is used to deploy L1VestingWalletEmergencyWithdraw contract and write its address to JSON
/// file.
contract L1VestingWalletEmergencyWithdrawScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L1VestingWalletEmergencyWithdraw contract and writes its address to JSON file.
    function run() public {
        // Deployer's private key. This key is used to deploy the contract.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Validate L1VestingWalletEmergencyWithdraw contract if it is implemented correctly so that it may be used as
        // new
        // implementation for the proxy contract.
        Options memory opts;
        opts.referenceContract = "L1VestingWallet.sol";
        opts.unsafeAllow = "constructor";
        Upgrades.validateUpgrade("L1VestingWalletEmergencyWithdraw.sol", opts);

        console2.log("Deploying L1VestingWalletEmergencyWithdraw contract...");

        // deploy L1VestingWalletEmergencyWithdraw contract
        vm.startBroadcast(deployerPrivateKey);
        L1VestingWalletEmergencyWithdraw l1VestingWalletEmergencyWithdrawImplementation =
            new L1VestingWalletEmergencyWithdraw();
        vm.stopBroadcast();

        assert(address(l1VestingWalletEmergencyWithdrawImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l1VestingWalletEmergencyWithdrawImplementation.proxiableUUID()
                == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        console2.log("L1VestingWalletEmergencyWithdraw contract successfully deployed!");
        console2.log(
            "L1VestingWalletEmergencyWithdraw (Implementation) address: %s",
            address(l1VestingWalletEmergencyWithdrawImplementation)
        );

        // write L1VestingWalletEmergencyWithdraw address to l1addresses.json
        Utils.L1AddressesConfig memory l1AddressesConfig = utils.readL1AddressesFile(utils.getL1AddressesFilePath());
        l1AddressesConfig.L1VestingWalletEmergencyWithdraw = address(l1VestingWalletEmergencyWithdrawImplementation);
        utils.writeL1AddressesFile(l1AddressesConfig, utils.getL1AddressesFilePath());
    }
}
