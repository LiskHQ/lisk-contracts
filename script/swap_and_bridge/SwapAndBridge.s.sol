// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { SwapAndBridge } from "src/L1/SwapAndBridge.sol";

/// @title SwapAndBridgeScript - SwapAndBridge deployment script
/// @notice This contract is used to deploy SwapAndBridge contract.
contract SwapAndBridgeScript is Script {
    /// @notice This function deploys the SwapAndBridge contract.
    function run() public {
        // Deployer's private key. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying SwapAndBirdge contract for Lido...");

        // deploy SwapAndBirdge contract for Lido
        vm.startBroadcast(deployerPrivateKey);
        SwapAndBridge swapAndBridgeLido = new SwapAndBridge(
            vm.envAddress("L1_LIDO_BRIDGE_ADDR"),
            vm.envAddress("L1_LIDO_TOKEN_ADDR"),
            vm.envAddress("L2_LIDO_TOKEN_ADDR")
        );
        vm.stopBroadcast();
        assert(address(swapAndBridgeLido) != address(0));
        console2.log("SwapAndBridge (Lido) successfully deployed!");
        console2.log("SwapAndBridge (Lido) address: %s", address(swapAndBridgeLido));
    }
}
