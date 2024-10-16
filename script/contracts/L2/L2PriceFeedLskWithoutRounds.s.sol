// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Script, console2 } from "forge-std/Script.sol";
import { L2PriceFeedLskWithoutRounds } from "src/L2/L2PriceFeedLskWithoutRounds.sol";
import "script/contracts/Utils.sol";

/// @title L2PriceFeedLskWithoutRoundsScript - L2PriceFeedLskWithoutRounds deployment script
/// @notice This contract is used to deploy L2PriceFeedLskWithoutRounds contract.
contract L2PriceFeedLskWithoutRoundsScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2PriceFeedLskWithoutRounds contract.
    function run() public {
        // Deployer's private key. Owner of the L2PriceFeedLskWithoutRounds. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2PriceFeedLskWithoutRounds contract...");

        // deploy L2PriceFeedLskWithoutRounds contract
        vm.startBroadcast(deployerPrivateKey);
        L2PriceFeedLskWithoutRounds l2PriceFeedLskWithoutRounds = new L2PriceFeedLskWithoutRounds();
        vm.stopBroadcast();

        assert(address(l2PriceFeedLskWithoutRounds) != address(0));
        //assert(l2PriceFeedLskWithoutRounds.l2LiskTokenAddress() == l2AddressesConfig.L2LiskToken);

        console2.log("L2PriceFeedLskWithoutRounds successfully deployed!");
        console2.log("L2PriceFeedLskWithoutRounds address: %s", address(l2PriceFeedLskWithoutRounds));

        // write L2PriceFeedLskWithoutRounds address to l2addresses.json
        //l2AddressesConfig.L2PriceFeedLskWithoutRounds = address(l2PriceFeedLskWithoutRounds);
        //utils.writeL2AddressesFile(l2AddressesConfig, utils.getL2AddressesFilePath());
    }
}
