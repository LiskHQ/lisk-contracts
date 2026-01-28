// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2PriceFeedWithoutRoundsV3 } from "src/L2/upgraded/L2PriceFeedWithoutRoundsV3.sol";

/// @title L2PriceFeedWithoutRoundsV3Script - L2PriceFeedWithoutRoundsV3 contract deployment script
/// @notice This contract is used to deploy L2PriceFeedWithoutRoundsV3 contract which is upgraded version of
///         L2PriceFeedWithoutRounds contract, allowing for updates to the data feed ID.
contract L2PriceFeedWithoutRoundsV3Script is Script {
    function setUp() public { }

    /// @notice This function deploys L2PriceFeedWithoutRoundsV3 contract.
    function run() public {
        // Deployer's private key. This key is used to deploy the contract.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Validate L2PriceFeedWithoutRoundsV3 contract if it is implemented correctly so that it may be used as new
        // implementation for the proxy contract.
        Options memory opts;
        opts.referenceContract = "L2PriceFeedWithoutRounds.sol";
        opts.unsafeAllow = "constructor";
        Upgrades.validateUpgrade("L2PriceFeedWithoutRoundsV3.sol", opts);

        console2.log("Deploying L2 PriceFeedWithoutRoundsV3 contract...");

        // deploy L2PriceFeedWithoutRoundsV3 contract
        vm.startBroadcast(deployerPrivateKey);
        L2PriceFeedWithoutRoundsV3 l2PriceFeedWithoutRoundsV3 = new L2PriceFeedWithoutRoundsV3();
        vm.stopBroadcast();

        assert(address(l2PriceFeedWithoutRoundsV3) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2PriceFeedWithoutRoundsV3.proxiableUUID()
                == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        console2.log("L2 PriceFeedWithoutRoundsV3 contract successfully deployed!");
        console2.log("L2 PriceFeedWithoutRoundsV3 address: %s", address(l2PriceFeedWithoutRoundsV3));
    }
}
