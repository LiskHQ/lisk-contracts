// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2PriceFeedWithoutRoundsFactory } from "src/L2/L2PriceFeedWithoutRoundsFactory.sol";
import "script/contracts/Utils.sol";

/// @title L2PriceFeedWithoutRoundsFactoryScript - L2PriceFeedWithoutRoundsFactory deployment script
/// @notice This contract is used to deploy L2PriceFeedWithoutRoundsFactory contract.
contract L2PriceFeedWithoutRoundsFactoryScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2PriceFeedWithoutRoundsFactory contract.
    function run() public {
        // Deployer's private key. Owner of the L2PriceFeedWithoutRoundsFactory. PRIVATE_KEY is set in .env
        // file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2PriceFeedWithoutRoundsFactory contract...");

        // owner Address, the ownership of L2PriceFeedWithoutRoundsFactory proxy contract is transferred to
        // after deployment
        address ownerAddress = vm.envAddress("L2_ADAPTER_PRICEFEED_OWNER_ADDRESS");
        assert(ownerAddress != address(0));
        console2.log(
            "L2 PriceFeed Without Rounds Factory contract owner address: %s (after ownership will be accepted)",
            ownerAddress
        );

        // deploy L2PriceFeedWithoutRoundsFactory implementation contract
        vm.startBroadcast(deployerPrivateKey);
        L2PriceFeedWithoutRoundsFactory l2PriceFeedFactoryImplementation = new L2PriceFeedWithoutRoundsFactory();
        vm.stopBroadcast();

        assert(address(l2PriceFeedFactoryImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2PriceFeedFactoryImplementation.proxiableUUID()
                == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        // deploy L2PriceFeedWithoutRoundsFactory proxy contract and at the same time initialize the proxy contract
        // (calls the initialize function in L2PriceFeedWithoutRoundsFactory)
        vm.startBroadcast(deployerPrivateKey);
        ERC1967Proxy l2PriceFeedFactoryProxy = new ERC1967Proxy(
            address(l2PriceFeedFactoryImplementation),
            abi.encodeWithSelector(l2PriceFeedFactoryImplementation.initialize.selector)
        );
        vm.stopBroadcast();
        assert(address(l2PriceFeedFactoryProxy) != address(0));

        // wrap in ABI to support easier calls
        L2PriceFeedWithoutRoundsFactory l2PriceFeedFactory =
            L2PriceFeedWithoutRoundsFactory(address(l2PriceFeedFactoryProxy));

        // transfer ownership of L2PriceFeedWithoutRoundsFactory proxy; because of using Ownable2StepUpgradeable
        // contract, new owner has to accept ownership
        vm.startBroadcast(deployerPrivateKey);
        l2PriceFeedFactory.transferOwnership(ownerAddress);
        vm.stopBroadcast();
        assert(l2PriceFeedFactory.owner() == vm.addr(deployerPrivateKey)); // ownership is not yet accepted

        console2.log("L2 PriceFeed Without Rounds Factory contract successfully deployed!");
        console2.log(
            "L2 PriceFeed Without Rounds Factory (Implementation) address: %s",
            address(l2PriceFeedFactoryImplementation)
        );
        console2.log("L2 PriceFeed Without Rounds Factory (Proxy) address: %s", address(l2PriceFeedFactory));
        console2.log(
            "Owner of L2 PriceFeed Without Rounds Factory (Proxy) address: %s (after ownership will be accepted)",
            ownerAddress
        );

        // write L2PriceFeedWithoutRoundsFactory address to l2addresses.json
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile(utils.getL2AddressesFilePath());
        l2AddressesConfig.L2PriceFeedWithoutRoundsFactoryImplementation = address(l2PriceFeedFactoryImplementation);
        l2AddressesConfig.L2PriceFeedWithoutRoundsFactory = address(l2PriceFeedFactory);
        utils.writeL2AddressesFile(l2AddressesConfig, utils.getL2AddressesFilePath());
    }
}
