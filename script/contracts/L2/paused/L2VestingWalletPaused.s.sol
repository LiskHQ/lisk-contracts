// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2VestingWalletEmergencyWithdraw } from "src/L2/paused/L2VestingWalletEmergencyWithdraw.sol";
import "script/contracts/Utils.sol";

/// @title L2VestingWalletEmergencyWithdrawScript - L2VestingWalletEmergencyWithdraw contract deployment script
/// @notice This contract is used to deploy L2VestingWalletEmergencyWithdraw contract and write its address to JSON
/// file.
contract L2VestingWalletEmergencyWithdrawScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2VestingWalletEmergencyWithdraw contract and writes its address to JSON file.
    function run() public {
        // Deployer's private key. This key is used to deploy the contract.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Validate L2VestingWalletEmergencyWithdraw contract if it is implemented correctly so that it may be used as
        // new
        // implementation for the proxy contract.
        Options memory opts;
        opts.referenceContract = "L2VestingWallet.sol";
        opts.unsafeAllow = "constructor";
        Upgrades.validateUpgrade("L2VestingWalletEmergencyWithdraw.sol", opts);

        console2.log("Deploying L2VestingWalletEmergencyWithdraw contract...");

        // deploy L2VestingWalletEmergencyWithdraw contract
        vm.startBroadcast(deployerPrivateKey);
        L2VestingWalletEmergencyWithdraw l2VestingWalletEmergencyWithdrawImplementation =
            new L2VestingWalletEmergencyWithdraw();
        vm.stopBroadcast();

        assert(address(l2VestingWalletEmergencyWithdrawImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2VestingWalletEmergencyWithdrawImplementation.proxiableUUID()
                == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        console2.log("L2VestingWalletEmergencyWithdraw contract successfully deployed!");
        console2.log(
            "L2VestingWalletEmergencyWithdraw (Implementation) address: %s",
            address(l2VestingWalletEmergencyWithdrawImplementation)
        );

        // write L2VestingWalletEmergencyWithdraw address to l2addresses.json
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile(utils.getL2AddressesFilePath());
        l2AddressesConfig.L2VestingWalletEmergencyWithdraw = address(l2VestingWalletEmergencyWithdrawImplementation);
        utils.writeL2AddressesFile(l2AddressesConfig, utils.getL2AddressesFilePath());
    }
}
