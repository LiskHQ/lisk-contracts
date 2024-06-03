// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { SwapAndBridge } from "src/L1/SwapAndBridge.sol";
import { OptimismMintableERC20 } from "@optimism/universal/OptimismMintableERC20.sol";
import "script/contracts/Utils.sol";

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
            swapAndBridgeAddressesConfig.L2WdivETH
        );
        vm.stopBroadcast();
        assert(address(swapAndBridgeDiva) != address(0));
        console2.log("SwapAndBridge (Diva) successfully deployed at address: %s", address(swapAndBridgeDiva));

        // write to json
        swapAndBridgeAddressesConfig.SwapAndBridgeDiva = address(swapAndBridgeDiva);
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
        swapAndBridgeAddressesConfig.SwapAndBridgeLido = address(swapAndBridgeLido);
        utils.writeSwapAndBridgeAddressesFile(swapAndBridgeAddressesConfig);
    }
}
