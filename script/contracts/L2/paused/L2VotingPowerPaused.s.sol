// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { Options } from "openzeppelin-foundry-upgrades/Options.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2VotingPowerPaused } from "src/L2/paused/L2VotingPowerPaused.sol";
import "script/contracts/Utils.sol";

/// @title L2VotingPowerPausedScript - L2VotingPowerPaused contract deployment script
/// @notice This contract is used to deploy L2VotingPowerPaused contract and write its address to JSON file.
contract L2VotingPowerPausedScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2VotingPowerPaused contract and writes its address to JSON file.
    function run() public {
        // Deployer's private key. This key is used to deploy the contract.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Validate L2VotingPowerPaused contract if it is implemented correctly so that it may be used as new
        // implementation for the proxy contract.
        Options memory opts;
        opts.referenceContract = "L2VotingPower.sol";
        opts.unsafeAllow = "constructor";
        Upgrades.validateUpgrade("L2VotingPowerPaused.sol", opts);

        console2.log("Deploying L2VotingPowerPaused contract...");

        // deploy L2VotingPowerPaused contract
        vm.startBroadcast(deployerPrivateKey);
        L2VotingPowerPaused l2VotingPowerPausedImplementation = new L2VotingPowerPaused();
        vm.stopBroadcast();

        assert(address(l2VotingPowerPausedImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2VotingPowerPausedImplementation.proxiableUUID()
                == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        console2.log("L2VotingPowerPaused contract successfully deployed!");
        console2.log("L2VotingPowerPaused (Implementation) address: %s", address(l2VotingPowerPausedImplementation));

        // write L2VotingPowerPaused address to l2addresses.json
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile(utils.getL2AddressesFilePath());
        l2AddressesConfig.L2VotingPowerPaused = address(l2VotingPowerPausedImplementation);
        utils.writeL2AddressesFile(l2AddressesConfig, utils.getL2AddressesFilePath());
    }
}
