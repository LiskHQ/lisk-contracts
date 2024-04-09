// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { SwapAndBridge } from "src/L1/SwapAndBridge.sol";
import { L2WdivETH } from "src/L2/L2WdivETH.sol";
import "script/Utils.sol";

/// @title WdivETHScript - WdivETH deployment script
/// @notice This contract is used to deploy WdivETH contract.
contract L2WdivETHScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys the SwapAndBridge contract.
    function run() public {
        // Deployer's private key. L2_SWAP_AND_BRIDGE_DEPLOYER_PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("L2_SWAP_AND_BRIDGE_DEPLOYER_PRIVATE_KEY");
        assert(vm.envAddress("L1_DIVA_TOKEN_ADDR") != address(0));
        assert(vm.envAddress("L2_DIVA_BRIDGE_ADDR") != address(0));

        console2.log("Deploying WdivETH contract on Lisk...");
        vm.startBroadcast(deployerPrivateKey);
        L2WdivETH wdivETH = new L2WdivETH(vm.envAddress("L1_DIVA_TOKEN_ADDR"));
        wdivETH.initialize(vm.envAddress("L2_DIVA_BRIDGE_ADDR"));
        console2.log("WdivETH successfully initialized");
        vm.stopBroadcast();

        assert(address(wdivETH) != address(0));
        console2.log("WdivETH successfully deployed at address: %s", address(wdivETH));
        // read swap and bridge addresses from file
        try utils.readSwapAndBridgeAddressesFile() returns (
            Utils.SwapAndBridgeAddressesConfig memory swapAndBridgeAddressesConfig
        ) {
            swapAndBridgeAddressesConfig.l2WdivETH = address(wdivETH);
            utils.writeSwapAndBridgeAddressesFile(swapAndBridgeAddressesConfig);
        } catch {
            // Initialize SwapAndBridgeAddressesConfig with WdivETH address
            Utils.SwapAndBridgeAddressesConfig memory swapAndBridgeAddressesConfig = Utils.SwapAndBridgeAddressesConfig({
                l2WdivETH: address(wdivETH),
                swapAndBridgeDiva: address(0),
                swapAndBridgeLido: address(0)
            });
            utils.writeSwapAndBridgeAddressesFile(swapAndBridgeAddressesConfig);
        }
    }
}

/// @title SwapAndBridgeScript - SwapAndBridge deployment script
/// @notice This contract is used to deploy SwapAndBridge contract.
contract SwapAndBridgeDivaScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys the SwapAndBridge contract.
    function run() public {
        // Deployer's private key. L1_SWAP_AND_BRIDGE_DEPLOYER_PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("L1_SWAP_AND_BRIDGE_DEPLOYER_PRIVATE_KEY");

        // read swap and bridge addresses from file
        Utils.SwapAndBridgeAddressesConfig memory swapAndBridgeAddressesConfig = utils.readSwapAndBridgeAddressesFile();

        console2.log("Deploying SwapAndBridge contract for Diva...");
        vm.startBroadcast(deployerPrivateKey);
        SwapAndBridge swapAndBridgeDiva = new SwapAndBridge(
            vm.envAddress("L1_DIVA_BRIDGE_ADDR"),
            vm.envAddress("L1_DIVA_TOKEN_ADDR"),
            swapAndBridgeAddressesConfig.l2WdivETH
        );
        vm.stopBroadcast();
        assert(address(swapAndBridgeDiva) != address(0));
        console2.log("SwapAndBridge (Diva) successfully deployed at address: %s", address(swapAndBridgeDiva));

        // write to json
        swapAndBridgeAddressesConfig.swapAndBridgeDiva = address(swapAndBridgeDiva);
        utils.writeSwapAndBridgeAddressesFile(swapAndBridgeAddressesConfig);
    }
}

/// @title SwapAndBridgeScript - SwapAndBridge deployment script
/// @notice This contract is used to deploy SwapAndBridge contract.
contract SwapAndBridgeLidoScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }
    /// @notice This function deploys the SwapAndBridge contract.

    function run() public {
        // Deployer's private key. L1_SWAP_AND_BRIDGE_DEPLOYER_PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("L1_SWAP_AND_BRIDGE_DEPLOYER_PRIVATE_KEY");
        // read swap and bridge addresses from file
        Utils.SwapAndBridgeAddressesConfig memory swapAndBridgeAddressesConfig = utils.readSwapAndBridgeAddressesFile();

        console2.log("Deploying SwapAndBridge contract for Lido...");
        vm.startBroadcast(deployerPrivateKey);
        SwapAndBridge swapAndBridgeLido = new SwapAndBridge(
            vm.envAddress("L1_LIDO_BRIDGE_ADDR"),
            vm.envAddress("L1_LIDO_TOKEN_ADDR"),
            vm.envAddress("L2_LIDO_TOKEN_ADDR")
        );
        vm.stopBroadcast();
        assert(address(swapAndBridgeLido) != address(0));
        console2.log("SwapAndBridge (Lido) successfully deployed at address: %s", address(swapAndBridgeLido));

        // write to json
        swapAndBridgeAddressesConfig.swapAndBridgeLido = address(swapAndBridgeLido);
        utils.writeSwapAndBridgeAddressesFile(swapAndBridgeAddressesConfig);
    }
}
