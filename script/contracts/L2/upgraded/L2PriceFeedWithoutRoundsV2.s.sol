// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2PriceFeedWithoutRoundsV2 } from "src/L2/upgraded/L2PriceFeedWithoutRoundsV2.sol";

/// @title L2PriceFeedWithoutRoundsV2Script - L2PriceFeedWithoutRoundsV2 contract deployment script
/// @notice This contract is used to deploy L2PriceFeedWithoutRoundsV2 contract which is upgraded version of
///         L2PriceFeedWithoutRounds contract.
contract L2PriceFeedWithoutRoundsV2Script is Script {
    function setUp() public { }

    /// @notice This function deploys L2PriceFeedWithoutRoundsV2 contract.
    function run() public {
        // Deployer's private key. This key is used to deploy the contract.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Validate L2PriceFeedWithoutRoundsV2 contract if it is implemented correctly so that it may be used as new
        // implementation for the proxy contract.
        Options memory opts;
        opts.referenceContract = "L2PriceFeedWithoutRounds.sol";
        opts.unsafeAllow = "constructor";
        Upgrades.validateUpgrade("L2PriceFeedWithoutRoundsV2.sol", opts);

        console2.log("Deploying L2 PriceFeedWithoutRoundsV2 contract...");

        // deploy L2PriceFeedWithoutRoundsV2 contract
        vm.startBroadcast(deployerPrivateKey);
        L2PriceFeedWithoutRoundsV2 l2PriceFeedWithoutRoundsV2 = new L2PriceFeedWithoutRoundsV2();
        vm.stopBroadcast();

        assert(address(l2PriceFeedWithoutRoundsV2) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2PriceFeedWithoutRoundsV2.proxiableUUID()
                == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        console2.log("L2 PriceFeedWithoutRoundsV2 contract successfully deployed!");
        console2.log("L2 PriceFeedWithoutRoundsV2 address: %s", address(l2PriceFeedWithoutRoundsV2));
    }
}
