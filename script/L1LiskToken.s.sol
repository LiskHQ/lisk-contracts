// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { L1LiskToken, UUPSProxy } from "src/L1/L1LiskToken.sol";
import "script/Utils.sol";

contract L1LiskTokenScript is Script {
    Utils utils;

    function setUp() public {
        utils = new Utils();
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console2.log("Deploying L1 Lisk token...");

        // deploy L1LiskToken contract
        vm.startBroadcast(deployerPrivateKey);
        L1LiskToken l1LiskToken = new L1LiskToken();
        vm.stopBroadcast();

        assert(address(l1LiskToken) != address(0));
        assert(l1LiskToken.proxiableUUID() == 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc);

        // deploy proxy contract and point it to the L1LiskToken contract
        vm.startBroadcast(deployerPrivateKey);
        UUPSProxy proxy = new UUPSProxy(address(l1LiskToken), "");
        vm.stopBroadcast();

        // wrap in ABI to support easier calls
        vm.startBroadcast(deployerPrivateKey);
        L1LiskToken wrappedProxy = L1LiskToken(address(proxy));
        vm.stopBroadcast();

        // initialize the proxy contract (calls the initialize function in L1LiskToken)
        vm.startBroadcast(deployerPrivateKey);
        wrappedProxy.initialize();
        vm.stopBroadcast();

        assert(keccak256(bytes(wrappedProxy.name())) == keccak256(bytes("Lost Space Key")));
        assert(keccak256(bytes(wrappedProxy.symbol())) == keccak256(bytes("LSK")));
        assert(wrappedProxy.decimals() == 18);
        assert(wrappedProxy.totalSupply() == 200000000 * 10 ** 18);
        assert(wrappedProxy.balanceOf(vm.addr(deployerPrivateKey)) == 200000000 * 10 ** 18);
        assert(wrappedProxy.owner() == vm.addr(deployerPrivateKey));

        console2.log("L1 Lisk token successfully deployed!");
        console2.log("L1 Lisk token address: %s", address(wrappedProxy));

        // write L1LiskToken address to l1addresses.json
        Utils.L1AddressesConfig memory l1AddressesConfig;
        l1AddressesConfig.L1LiskToken = address(wrappedProxy);
        utils.writeL1AddressesFile(l1AddressesConfig);
    }
}
