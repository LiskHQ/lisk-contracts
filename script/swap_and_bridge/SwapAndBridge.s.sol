// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { SwapAndBridge } from "src/L1/SwapAndBridge.sol";
import { L2WdivETH } from "src/L2/L2WdivETH.sol";

/// @title WdivETHScript - WdivETH deployment script
/// @notice This contract is used to deploy WdivETH contract.
contract L2WdivETHScript is Script {
    /// @notice This function deploys the SwapAndBridge contract.
    function run() public {
        // Deployer's private key. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("L2_DEPLOYER_PRIVATE_KEY");

        console2.log("Deploying WdivETH contract on Lisk...");
        vm.startBroadcast(deployerPrivateKey);
        L2WdivETH wdivETH = new L2WdivETH(vm.envAddress("L1_DIVA_TOKEN_ADDR"));
        wdivETH.initialize(vm.envAddress("L2_DIVA_BRIDGE_ADDR"));
        console2.log("WdivETH successfully initialized");
        vm.stopBroadcast();
        console2.log("WdivETH successfully deployed at address: %s", address(wdivETH));
    }
}

/// @title SwapAndBridgeScript - SwapAndBridge deployment script
/// @notice This contract is used to deploy SwapAndBridge contract.
contract SwapAndBridgeScript is Script {
    /// @notice This function deploys the SwapAndBridge contract.
    function run() public {
        // Deployer's private key. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("L1_DEPLOYER_PRIVATE_KEY");

        // console2.log("Deploying SwapAndBridge contract for Lido...");
        // vm.startBroadcast(deployerPrivateKey);
        // SwapAndBridge swapAndBridgeLido = new SwapAndBridge(
        //     vm.envAddress("L1_LIDO_BRIDGE_ADDR"),
        //     vm.envAddress("L1_LIDO_TOKEN_ADDR"),
        //     vm.envAddress("L2_LIDO_TOKEN_ADDR")
        // );
        // vm.stopBroadcast();
        // assert(address(swapAndBridgeLido) != address(0));
        // console2.log("SwapAndBridge (Lido) successfully deployed at address: %s", address(swapAndBridgeLido));

        console2.log("Deploying SwapAndBridge contract for Diva...");
        vm.startBroadcast(deployerPrivateKey);
        SwapAndBridge swapAndBridgeDiva = new SwapAndBridge(
            vm.envAddress("L1_DIVA_BRIDGE_ADDR"),
            vm.envAddress("L1_DIVA_TOKEN_ADDR"),
            vm.envAddress("L2_DIVA_TOKEN_ADDR")
        );
        vm.stopBroadcast();
        assert(address(swapAndBridgeDiva) != address(0));
        console2.log("SwapAndBridge (Diva) successfully deployed at address: %s", address(swapAndBridgeDiva));
    }
}
