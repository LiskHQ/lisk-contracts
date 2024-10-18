// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2PriceFeedLskWithoutRounds } from "src/L2/L2PriceFeedLskWithoutRounds.sol";
import "script/contracts/Utils.sol";

/// @title L2PriceFeedLskWithoutRoundsScript - L2PriceFeedLskWithoutRounds deployment
///        script
/// @notice This contract is used to deploy L2PriceFeedLskWithoutRounds contract.
contract L2PriceFeedLskWithoutRoundsScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2PriceFeedLskWithoutRounds contract.
    function run() public {
        // Deployer's private key. Owner of the L2PriceFeedLskWithoutRounds. PRIVATE_KEY is set in .env
        // file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2PriceFeedLskWithoutRounds contract...");

        // owner Address, the ownership of L2PriceFeedLskWithoutRounds proxy contract is transferred to
        // after deployment
        address ownerAddress = vm.envAddress("L2_ADAPTER_PRICEFEED_OWNER_ADDRESS");
        assert(ownerAddress != address(0));
        console2.log(
            "L2 PriceFeed LSK Without Rounds contract owner address: %s (after ownership will be accepted)",
            ownerAddress
        );

        // get L2MultiFeedAdapterWithoutRoundsMainDemo contract address
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile(utils.getL2AddressesFilePath());
        assert(l2AddressesConfig.L2MultiFeedAdapterWithoutRoundsMainDemo != address(0));
        console2.log(
            "L2 MultiFeed Adapter Without Rounds MainDemo address: %s",
            l2AddressesConfig.L2MultiFeedAdapterWithoutRoundsMainDemo
        );

        // deploy L2PriceFeedLskWithoutRounds implementation contract
        vm.startBroadcast(deployerPrivateKey);
        L2PriceFeedLskWithoutRounds l2PriceFeedImplementation = new L2PriceFeedLskWithoutRounds();
        vm.stopBroadcast();

        assert(address(l2PriceFeedImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2PriceFeedImplementation.proxiableUUID() == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        // deploy L2PriceFeedLskWithoutRounds proxy contract and at the same time initialize the proxy
        // contract (calls the initialize function in L2PriceFeedLskWithoutRounds)
        vm.startBroadcast(deployerPrivateKey);
        ERC1967Proxy l2PriceFeedProxy = new ERC1967Proxy(
            address(l2PriceFeedImplementation), abi.encodeWithSelector(l2PriceFeedImplementation.initialize.selector)
        );
        vm.stopBroadcast();
        assert(address(l2PriceFeedProxy) != address(0));

        // wrap in ABI to support easier calls
        L2PriceFeedLskWithoutRounds l2PriceFeed = L2PriceFeedLskWithoutRounds(address(l2PriceFeedProxy));
        assert(l2PriceFeed.decimals() == 8);
        assert(keccak256(bytes(l2PriceFeed.description())) == keccak256(bytes("Redstone Price Feed")));
        assert(l2PriceFeed.getDataFeedId() == bytes32("LSK"));

        // set L2MultiFeedAdapterWithoutRoundsMainDemo contract address as a PriceFeedAdapter
        vm.startBroadcast(deployerPrivateKey);
        l2PriceFeed.setPriceFeedAdapter(l2AddressesConfig.L2MultiFeedAdapterWithoutRoundsMainDemo);
        vm.stopBroadcast();
        assert(address(l2PriceFeed.getPriceFeedAdapter()) == l2AddressesConfig.L2MultiFeedAdapterWithoutRoundsMainDemo);

        // transfer ownership of L2PriceFeedLskWithoutRounds proxy; because of using
        // Ownable2StepUpgradeable contract, new owner has to accept ownership
        vm.startBroadcast(deployerPrivateKey);
        l2PriceFeed.transferOwnership(ownerAddress);
        vm.stopBroadcast();
        assert(l2PriceFeed.owner() == vm.addr(deployerPrivateKey)); // ownership is not yet accepted

        console2.log("L2 PriceFeed LSK Without Rounds contract successfully deployed!");
        console2.log("L2 PriceFeed LSK Without Rounds (Implementation) address: %s", address(l2PriceFeedImplementation));
        console2.log("L2 PriceFeed LSK Without Rounds (Proxy) address: %s", address(l2PriceFeed));
        console2.log(
            "Owner of L2 PriceFeed LSK Without Rounds (Proxy) address: %s (after ownership will be accepted)",
            ownerAddress
        );

        // write L2PriceFeedLskWithoutRounds address to l2addresses.json
        l2AddressesConfig.L2PriceFeedLskWithoutRoundsImplementation = address(l2PriceFeedImplementation);
        l2AddressesConfig.L2PriceFeedLskWithoutRounds = address(l2PriceFeed);
        utils.writeL2AddressesFile(l2AddressesConfig, utils.getL2AddressesFilePath());
    }
}
