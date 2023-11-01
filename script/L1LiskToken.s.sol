// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Script, console2 } from "forge-std/Script.sol";
import { L1LiskToken, UUPSProxy } from "src/L1/L1LiskToken.sol";

contract L1LiskTokenScript is Script {
    function setUp() public { }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

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

        assert(keccak256(bytes(wrappedProxy.name())) == keccak256(bytes("Lisk")));
        assert(keccak256(bytes(wrappedProxy.symbol())) == keccak256(bytes("LSK")));
        assert(wrappedProxy.decimals() == 18);
        assert(wrappedProxy.totalSupply() == 200000000 * 10 ** 18);
        assert(wrappedProxy.balanceOf(vm.addr(deployerPrivateKey)) == 200000000 * 10 ** 18);
        assert(wrappedProxy.owner() == vm.addr(deployerPrivateKey));
    }
}
