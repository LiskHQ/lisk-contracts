// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2VestingWalletPaused } from "src/L2/paused/L2VestingWalletPaused.sol";
import "script/contracts/Utils.sol";

/// @title L2VestingWalletPausedScript - L2VestingWalletPaused contract deployment script
/// @notice This contract is used to deploy L2VestingWalletPaused contract and write its address to JSON file.
contract L2VestingWalletPausedScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    /// @notice Stating the network layer of this script
    string public constant layer = "L2";

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2VestingWalletPaused contract and writes its address to JSON file.
    function run() public {
        // Deployer's private key. This key is used to deploy the contract.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Validate L2VestingWalletPaused contract if it is implemented correctly so that it may be used as new
        // implementation for the proxy contract.
        Options memory opts;
        opts.referenceContract = "L2VestingWallet.sol";
        opts.unsafeAllow = "constructor";
        Upgrades.validateUpgrade("L2VestingWalletPaused.sol", opts);

        console2.log("Deploying L2VestingWalletPaused contract...");

        // deploy L2VestingWalletPaused contract
        vm.startBroadcast(deployerPrivateKey);
        L2VestingWalletPaused l2VestingWalletPausedImplementation = new L2VestingWalletPaused();
        vm.stopBroadcast();

        assert(address(l2VestingWalletPausedImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2VestingWalletPausedImplementation.proxiableUUID()
                == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        console2.log("L2VestingWalletPaused contract successfully deployed!");
        console2.log("L2VestingWalletPaused (Implementation) address: %s", address(l2VestingWalletPausedImplementation));

        // write L2VestingWalletPaused address to l2addresses.json
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile(utils.getL2AddressesFilePath());
        l2AddressesConfig.L2VestingWalletPaused = address(l2VestingWalletPausedImplementation);
        utils.writeL2AddressesFile(l2AddressesConfig, utils.getL2AddressesFilePath());
    }
}
