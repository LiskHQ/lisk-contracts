// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2, StdCheats } from "forge-std/Test.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { USDT, IOptimismMintableERC20 } from "src/L2/USDT.sol";

contract USDTTest is Test {
    USDT public usdt;
    address public remoteToken;
    address public bridge;

    // some accounts to test with
    uint256 public alicePrivateKey;
    uint256 public bobPrivateKey;
    address public alice;
    address public bob;

    function setUp() public {
        bridge = vm.addr(uint256(bytes32("bridge")));
        remoteToken = vm.addr(uint256(bytes32("remoteToken")));

        vm.prank(address(this), address(this));
        usdt = new USDT(bridge,remoteToken, "Tether USD", "USDT", 18);
        vm.stopPrank();

        (alice, alicePrivateKey) = makeAddrAndKey("alice");
        (bob, bobPrivateKey) = makeAddrAndKey("bob");
    }   

    function test_ConstructorFail_ZeroBridgeAddress() public {
        vm.expectRevert("USDT: _bridge can not be zero");
        new USDT(address(0),remoteToken, "Tether USD", "USDT", 18);
    }

    function test_ConstructorFail_ZeroRemoteTokenAddress() public {
        vm.expectRevert("USDT: _remoteToken can not be zero");
        new USDT(bridge,address(0), "Tether USD", "USDT", 18);
    }

    function test_GetBridge() public {
        assertEq(usdt.bridge(), bridge);
        assertEq(usdt.BRIDGE(), bridge);
    }

    function test_GetRemoteToken() public {
        assertEq(usdt.remoteToken(), remoteToken);
        assertEq(usdt.REMOTE_TOKEN(), remoteToken);
    }

    function test_Mint() public {
        vm.prank(bridge);
        usdt.mint(alice, 100 * 10 ** 18);
        assertEq(usdt.balanceOf(alice), 100 * 10 ** 18);
        assertEq(usdt.balanceOf(bob), 0);
        assertEq(usdt.totalSupply(), 100 * 10 ** 18);

        vm.prank(bridge);
        usdt.mint(alice, 50 * 10 ** 18);
        assertEq(usdt.balanceOf(alice), 150 * 10 ** 18);
        assertEq(usdt.balanceOf(bob), 0);
        assertEq(usdt.totalSupply(), 150 * 10 ** 18);

        vm.prank(bridge);
        usdt.mint(bob, 30 * 10 ** 18);
        assertEq(usdt.balanceOf(alice), 150 * 10 ** 18);
        assertEq(usdt.balanceOf(bob), 30 * 10 ** 18);
        assertEq(usdt.totalSupply(), 180 * 10 ** 18);
    }

    function test_MintFail_NotBridge() public {
        // try to mint new tokens being alice and not the Standard Bridge
        vm.prank(alice);
        vm.expectRevert("USDT: only bridge can mint and burn");
        usdt.mint(bob, 100 * 10 ** 18);
    }

    function test_Burn() public {
        vm.prank(bridge);
        usdt.mint(alice, 100 * 10 ** 18);
        assertEq(usdt.balanceOf(alice), 100 * 10 ** 18);
        assertEq(usdt.balanceOf(bob), 0);
        assertEq(usdt.totalSupply(), 100 * 10 ** 18);

        vm.prank(bridge);
        usdt.mint(bob, 50 * 10 ** 18);
        assertEq(usdt.balanceOf(alice), 100 * 10 ** 18);
        assertEq(usdt.balanceOf(bob), 50 * 10 ** 18);
        assertEq(usdt.totalSupply(), 150 * 10 ** 18);

        vm.prank(bridge);
        usdt.burn(alice, 50 * 10 ** 18);
        assertEq(usdt.balanceOf(alice), 50 * 10 ** 18);
        assertEq(usdt.balanceOf(bob), 50 * 10 ** 18);
        assertEq(usdt.totalSupply(), 100 * 10 ** 18);

        vm.prank(bridge);
        usdt.burn(alice, 20 * 10 ** 18);
        assertEq(usdt.balanceOf(alice), 30 * 10 ** 18);
        assertEq(usdt.balanceOf(bob), 50 * 10 ** 18);
        assertEq(usdt.totalSupply(), 80 * 10 ** 18);

        vm.prank(bridge);
        usdt.burn(alice, 30 * 10 ** 18);
        assertEq(usdt.balanceOf(alice), 0);
        assertEq(usdt.balanceOf(bob), 50 * 10 ** 18);
        assertEq(usdt.totalSupply(), 50 * 10 ** 18);

        vm.prank(bridge);
        usdt.burn(bob, 50 * 10 ** 18);
        assertEq(usdt.balanceOf(alice), 0);
        assertEq(usdt.balanceOf(bob), 0);
        assertEq(usdt.totalSupply(), 0);
    }

    function test_BurnFail_NotBridge() public {
        vm.prank(bridge);
        usdt.mint(bob, 100 * 10 ** 18);
        assertEq(usdt.balanceOf(bob), 100 * 10 ** 18);

        // try to burn tokens being alice and not the Standard Bridge
        vm.prank(alice);
        vm.expectRevert("USDT: only bridge can mint and burn");
        usdt.burn(bob, 100 * 10 ** 18);
    }

    function testFuzz_Transfer(uint256 amount) public {
        // mint some tokens to alice
        vm.prank(bridge);
        usdt.mint(alice, amount);
        assertEq(usdt.balanceOf(alice), amount);

        // send some tokens from alice to bob
        vm.prank(alice);
        usdt.transfer(bob, amount);
        assertEq(usdt.balanceOf(alice), 0);
        assertEq(usdt.balanceOf(bob), amount);

        // send some tokens from bob to alice
        vm.prank(bob);
        usdt.transfer(alice, amount);
        assertEq(usdt.balanceOf(alice), amount);
        assertEq(usdt.balanceOf(bob), 0);
    }

    function testFuzz_Allowance(uint256 amount) public {
        // mint some tokens to alice
        vm.prank(bridge);
        usdt.mint(alice, amount);
        assertEq(usdt.balanceOf(alice), amount);

        // alice approves bob to spend some tokens
        vm.prank(alice);
        usdt.approve(bob, amount);
        assertEq(usdt.allowance(alice, bob), amount);

        // test that bob can call transferFrom
        vm.prank(bob);
        usdt.transferFrom(alice, bob, amount);
        // test alice balance
        assertEq(usdt.balanceOf(alice), 0);
        // test bob balance
        assertEq(usdt.balanceOf(bob), amount);
    }

   
}
