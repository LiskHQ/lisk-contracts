// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { L2MultiFeedAdapterWithoutRoundsPrimaryProd } from "src/L2/L2MultiFeedAdapterWithoutRoundsPrimaryProd.sol";
import "script/contracts/Utils.sol";

/// @title L2MultiFeedAdapterWithoutRoundsPrimaryProdScript - L2MultiFeedAdapterWithoutRoundsPrimaryProd deployment
///        script
/// @notice This contract is used to deploy L2MultiFeedAdapterWithoutRoundsPrimaryProd contract.
contract L2MultiFeedAdapterWithoutRoundsPrimaryProdScript is Script {
    /// @notice Utils contract which provides functions to read and write JSON files containing L2 addresses.
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    /// @notice This function deploys L2MultiFeedAdapterWithoutRoundsPrimaryProd contract.
    function run() public {
        // Deployer's private key. Owner of the L2MultiFeedAdapterWithoutRoundsPrimaryProd. PRIVATE_KEY is set in .env
        // file.
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L2MultiFeedAdapterWithoutRoundsPrimaryProd contract...");

        // owner Address, the ownership of L2MultiFeedAdapterWithoutRoundsPrimaryProd proxy contract is transferred to
        // after deployment
        address ownerAddress = vm.envAddress("L2_ADAPTER_PRICEFEED_OWNER_ADDRESS");
        assert(ownerAddress != address(0));
        console2.log(
            "L2 MultiFeed Adapter Without Rounds PrimaryProd contract owner address: %s (after ownership will be accepted)",
            ownerAddress
        );

        // deploy L2MultiFeedAdapterWithoutRoundsPrimaryProd implementation contract
        vm.startBroadcast(deployerPrivateKey);
        L2MultiFeedAdapterWithoutRoundsPrimaryProd l2AdapterImplementation =
            new L2MultiFeedAdapterWithoutRoundsPrimaryProd();
        vm.stopBroadcast();

        assert(address(l2AdapterImplementation) != address(0));

        // ERC1967Utils: keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
        assert(
            l2AdapterImplementation.proxiableUUID() == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
        );

        // deploy L2MultiFeedAdapterWithoutRoundsPrimaryProd proxy contract and at the same time initialize the proxy
        // contract (calls the initialize function in L2MultiFeedAdapterWithoutRoundsPrimaryProd)
        vm.startBroadcast(deployerPrivateKey);
        ERC1967Proxy l2AdapterProxy = new ERC1967Proxy(
            address(l2AdapterImplementation), abi.encodeWithSelector(l2AdapterImplementation.initialize.selector)
        );
        vm.stopBroadcast();
        assert(address(l2AdapterProxy) != address(0));

        // wrap in ABI to support easier calls
        L2MultiFeedAdapterWithoutRoundsPrimaryProd l2Adapter =
            L2MultiFeedAdapterWithoutRoundsPrimaryProd(address(l2AdapterProxy));
        assert(l2Adapter.getUniqueSignersThreshold() == 2);
        assert(l2Adapter.getAuthorisedSignerIndex(0x8BB8F32Df04c8b654987DAaeD53D6B6091e3B774) == 0);
        assert(l2Adapter.getAuthorisedSignerIndex(0xdEB22f54738d54976C4c0fe5ce6d408E40d88499) == 1);
        assert(l2Adapter.getAuthorisedSignerIndex(0x51Ce04Be4b3E32572C4Ec9135221d0691Ba7d202) == 2);
        assert(l2Adapter.getAuthorisedSignerIndex(0xDD682daEC5A90dD295d14DA4b0bec9281017b5bE) == 3);
        assert(l2Adapter.getAuthorisedSignerIndex(0x9c5AE89C4Af6aA32cE58588DBaF90d18a855B6de) == 4);

        // transfer ownership of L2MultiFeedAdapterWithoutRoundsPrimaryProd proxy; because of using
        // Ownable2StepUpgradeable contract, new owner has to accept ownership
        vm.startBroadcast(deployerPrivateKey);
        l2Adapter.transferOwnership(ownerAddress);
        vm.stopBroadcast();
        assert(l2Adapter.owner() == vm.addr(deployerPrivateKey)); // ownership is not yet accepted

        console2.log("L2 MultiFeed Adapter Without Rounds PrimaryProd contract successfully deployed!");
        console2.log("L2 MultiFeed Adapter (Implementation) address: %s", address(l2AdapterImplementation));
        console2.log("L2 MultiFeed Adapter (Proxy) address: %s", address(l2Adapter));
        console2.log(
            "Owner of L2 MultiFeed Adapter (Proxy) address: %s (after ownership will be accepted)", ownerAddress
        );

        // write L2MultiFeedAdapterWithoutRoundsPrimaryProd address to l2addresses.json
        Utils.L2AddressesConfig memory l2AddressesConfig = utils.readL2AddressesFile(utils.getL2AddressesFilePath());
        l2AddressesConfig.L2MultiFeedAdapterWithoutRoundsPrimaryProdImplementation = address(l2AdapterImplementation);
        l2AddressesConfig.L2MultiFeedAdapterWithoutRoundsPrimaryProd = address(l2Adapter);
        utils.writeL2AddressesFile(l2AddressesConfig, utils.getL2AddressesFilePath());
    }
}
