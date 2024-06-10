// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { SwapAndBridge } from "src/L1/SwapAndBridge.sol";

/// @title SwapAndBridgeScript - SwapAndBridge deployment script
/// @notice This contract is used to deploy SwapAndBridge contract.
contract SwapAndBridgeScript is Script {
    /// @notice This function deploys the SwapAndBridge contract.
    function run(address bridgeAddress, address l1Token, address l2Token) public {
        // Deployer's private key. L1_SWAP_AND_BRIDGE_DEPLOYER_PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying SwapAndBridge contract...");
        vm.startBroadcast(deployerPrivateKey);
        SwapAndBridge swapAndBridge = new SwapAndBridge(bridgeAddress, l1Token, l2Token);
        vm.stopBroadcast();
        assert(address(swapAndBridge) != address(0));
        console2.log("SwapAndBridge successfully deployed at address: %s", address(swapAndBridge));
    }
}
