// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Test, console2 } from "forge-std/Test.sol";
import { L1LiskToken, UUPSProxy } from "../src/L1/L1LiskToken.sol";

contract L1LiskTokenTest is Test {
    L1LiskToken public l1LiskToken;
    UUPSProxy public proxy;
    L1LiskToken public wrappedProxy;

    function setUp() public {
        l1LiskToken = new L1LiskToken();

        // deploy proxy contract and point it to the L1LiskToken contract
        proxy = new UUPSProxy(address(l1LiskToken), "");

        // wrap in ABI to support easier calls
        wrappedProxy = L1LiskToken(address(proxy));

        // initialize the proxy contract (calls the initialize function in L1LiskToken)
        wrappedProxy.initialize();
    }

    function test_Initialize() public {
        assertEq(wrappedProxy.name(), "Lisk");
        assertEq(wrappedProxy.symbol(), "LSK");
        assertEq(wrappedProxy.decimals(), 18);
        assertEq(wrappedProxy.totalSupply(), 200000000 * 10 ** 18);
        assertEq(wrappedProxy.balanceOf(address(this)), 200000000 * 10 ** 18);
        assertEq(wrappedProxy.owner(), address(this));
        assertEq(l1LiskToken.proxiableUUID(), 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc);
    }

    function test_Transfer() public {
        address alice = vm.addr(1);
        address bob = vm.addr(2);

        // send 1000 tokens to alice
        wrappedProxy.transfer(alice, 1000);
        assertEq(wrappedProxy.balanceOf(alice), 1000);

        // send 1000 tokens from alice to bob
        vm.prank(alice);
        wrappedProxy.transfer(bob, 1000);
        assertEq(wrappedProxy.balanceOf(alice), 0);
        assertEq(wrappedProxy.balanceOf(bob), 1000);

        // send 1000 tokens from bob to alice
        vm.prank(bob);
        wrappedProxy.transfer(alice, 1000);
        assertEq(wrappedProxy.balanceOf(alice), 1000);
        assertEq(wrappedProxy.balanceOf(bob), 0);
    }

    function test_Allowance() public {
        address alice = vm.addr(1);
        address bob = vm.addr(2);

        // send 1000 tokens to alice
        wrappedProxy.transfer(alice, 1000);
        assertEq(wrappedProxy.balanceOf(alice), 1000);

        // alice approves bob to spend 1000 tokens
        vm.prank(alice);
        wrappedProxy.approve(bob, 1000);
        assertEq(wrappedProxy.allowance(alice, bob), 1000);

        // test that bob can call transferFrom
        vm.prank(bob);
        wrappedProxy.transferFrom(alice, bob, 1000);
        // test alice balance
        assertEq(wrappedProxy.balanceOf(alice), 0);
        // test bob balance
        assertEq(wrappedProxy.balanceOf(bob), 1000);
    }

    function test_Upgrade() public {
        // deploy new version of L1LiskToken and upgrade the proxy to point to it
        L1LiskToken l1LiskToken_v2 = new L1LiskToken();
        wrappedProxy.upgradeToAndCall(address(l1LiskToken_v2), "");

        // re-wrap the proxy
        L1LiskToken wrappedProxy_v2 = L1LiskToken(address(proxy));

        assertEq(wrappedProxy_v2.name(), "Lisk");
        assertEq(wrappedProxy_v2.symbol(), "LSK");
        assertEq(wrappedProxy_v2.decimals(), 18);
        assertEq(wrappedProxy_v2.totalSupply(), 200000000 * 10 ** 18);
        assertEq(wrappedProxy_v2.balanceOf(address(this)), 200000000 * 10 ** 18);
        assertEq(wrappedProxy_v2.owner(), address(this));
        assertEq(l1LiskToken_v2.proxiableUUID(), 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc);
    }

    function test_UpgradeFail_NotOwner() public {
        L1LiskToken l1LiskToken_v2 = new L1LiskToken();

        // try to upgrade the proxy while not being the owner
        address alice = vm.addr(1);
        vm.prank(alice);
        vm.expectRevert();
        wrappedProxy.upgradeToAndCall(address(l1LiskToken_v2), "");
    }
}
