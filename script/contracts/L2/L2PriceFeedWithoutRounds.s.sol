// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2PriceFeedWithoutRoundsFactory } from "src/L2/L2PriceFeedWithoutRoundsFactory.sol";
import { L2PriceFeedWithoutRounds } from "src/L2/L2PriceFeedWithoutRounds.sol";
import "script/contracts/Utils.sol";

/// @title L2PriceFeedWithoutRoundsScript - L2PriceFeedWithoutRounds deployment script
/// @notice This contract is used to deploy L2PriceFeedWithoutRounds contract.
contract L2PriceFeedWithoutRoundsScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    /// @notice Constant for RedStone PrimaryProd data service type.
    string REDSTONE_SERVICE_TYPE_PRIMARY_PROD = "PrimaryProd";

    /// @notice Constant for RedStone MainDemo data service type.
    string REDSTONE_SERVICE_TYPE_MAIN_DEMO = "MainDemo";

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2PriceFeedWithoutRounds contract.
    function run(string memory feedId, string memory dataServiceType) public {
        // Deployer's private key. Owner of the L2PriceFeedWithoutRounds. PRIVATE_KEY is set in .env file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2PriceFeedWithoutRounds contract...");

        // owner Address, the ownership of L2PriceFeedWithoutRounds proxy contract is transferred to after deployment
        address ownerAddress = vm.envAddress("L2_ADAPTER_PRICEFEED_OWNER_ADDRESS");
        assert(ownerAddress != address(0));
        console2.log(
            "L2 PriceFeed %s Without Rounds contract owner address: %s (after ownership will be accepted)",
            feedId,
            ownerAddress
        );

        // get L2PriceFeedWithoutRoundsFactory contract address and its instance
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile(utils.getL2AddressesFilePath());
        assert(l2AddressesConfig.L2PriceFeedWithoutRoundsFactory != address(0));
        console2.log(
            "L2 PriceFeed Without Rounds Factory address: %s", l2AddressesConfig.L2PriceFeedWithoutRoundsFactory
        );
        L2PriceFeedWithoutRoundsFactory l2PriceFeedFactory =
            L2PriceFeedWithoutRoundsFactory(l2AddressesConfig.L2PriceFeedWithoutRoundsFactory);

        if (keccak256(bytes(dataServiceType)) == keccak256(bytes(REDSTONE_SERVICE_TYPE_PRIMARY_PROD))) {
            // get L2MultiFeedAdapterWithoutRoundsPrimaryProd contract address
            assert(l2AddressesConfig.L2MultiFeedAdapterWithoutRoundsPrimaryProd != address(0));
            console2.log(
                "L2 MultiFeed Adapter Without Rounds PrimaryProd address: %s",
                l2AddressesConfig.L2MultiFeedAdapterWithoutRoundsPrimaryProd
            );
        } else if (keccak256(bytes(dataServiceType)) == keccak256(bytes(REDSTONE_SERVICE_TYPE_MAIN_DEMO))) {
            // get L2MultiFeedAdapterWithoutRoundsMainDemo contract address
            assert(l2AddressesConfig.L2MultiFeedAdapterWithoutRoundsMainDemo != address(0));
            console2.log(
                "L2 MultiFeed Adapter Without Rounds MainDemo address: %s",
                l2AddressesConfig.L2MultiFeedAdapterWithoutRoundsMainDemo
            );
        } else {
            assert(false);
        }

        // create L2PriceFeedWithoutRounds contract
        vm.startBroadcast(deployerPrivateKey);
        L2PriceFeedWithoutRounds l2PriceFeed = L2PriceFeedWithoutRounds(
            l2PriceFeedFactory.createL2PriceFeedWithoutRounds(
                feedId,
                keccak256(bytes(dataServiceType)) == keccak256(bytes(REDSTONE_SERVICE_TYPE_PRIMARY_PROD))
                    ? l2AddressesConfig.L2MultiFeedAdapterWithoutRoundsPrimaryProd
                    : l2AddressesConfig.L2MultiFeedAdapterWithoutRoundsMainDemo
            )
        );
        vm.stopBroadcast();
        assert(address(l2PriceFeed) != address(0));
        assert(l2PriceFeed.decimals() == 8);
        assert(keccak256(bytes(l2PriceFeed.description())) == keccak256(bytes("Redstone Price Feed")));
        assert(l2PriceFeed.getDataFeedId() == bytes32(abi.encodePacked(feedId)));
        assert(
            address(l2PriceFeed.getPriceFeedAdapter())
                == (
                    keccak256(bytes(dataServiceType)) == keccak256(bytes(REDSTONE_SERVICE_TYPE_PRIMARY_PROD))
                        ? l2AddressesConfig.L2MultiFeedAdapterWithoutRoundsPrimaryProd
                        : l2AddressesConfig.L2MultiFeedAdapterWithoutRoundsMainDemo
                )
        );

        // accept ownership and transfer ownership of L2PriceFeedWithoutRounds proxy; because of using
        // Ownable2StepUpgradeable contract, new owner has to accept ownership
        vm.startBroadcast(deployerPrivateKey);
        l2PriceFeed.acceptOwnership();
        l2PriceFeed.transferOwnership(ownerAddress);
        vm.stopBroadcast();
        assert(l2PriceFeed.owner() == vm.addr(deployerPrivateKey)); // ownership is not yet accepted
        assert(l2PriceFeed.pendingOwner() == ownerAddress);

        console2.log("L2 PriceFeed %s Without Rounds contract successfully deployed!", feedId);
        console2.log("L2 PriceFeed %s Without Rounds (Proxy) address: %s", feedId, address(l2PriceFeed));
        console2.log(
            "Owner of L2 PriceFeed %s Without Rounds (Proxy) address: %s (after ownership will be accepted)",
            feedId,
            ownerAddress
        );
    }
}
