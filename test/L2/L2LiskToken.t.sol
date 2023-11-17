// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Test, console2 } from "forge-std/Test.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { L2LiskToken, IOptimismMintableERC20 } from "src/L2/L2LiskToken.sol";

contract L2LiskTokenTest is Test {
    L2LiskToken public l2LiskToken;
    address public remoteToken;
    address public bridge;

    function setUp() public {
        bridge = vm.addr(1);
        remoteToken = vm.addr(2);
        l2LiskToken = new L2LiskToken(bridge, remoteToken);
    }

    function test_Initialize() public {
        assertEq(l2LiskToken.name(), "Lisk");
        assertEq(l2LiskToken.symbol(), "LSK");
        assertEq(l2LiskToken.decimals(), 18);
        assertEq(l2LiskToken.totalSupply(), 0);
        assertEq(l2LiskToken.remoteToken(), remoteToken);
        assertEq(l2LiskToken.bridge(), bridge);

        // check that an IERC165 interface is supported
        assertEq(l2LiskToken.supportsInterface(type(IERC165).interfaceId), true);

        // check that an IOptimismMintableERC20 interface is supported
        assertEq(l2LiskToken.supportsInterface(type(IOptimismMintableERC20).interfaceId), true);
    }

    function test_GetBridge() public {
        assertEq(l2LiskToken.bridge(), bridge);
        assertEq(l2LiskToken.BRIDGE(), bridge);
    }

    function test_GetRemoteToken() public {
        assertEq(l2LiskToken.remoteToken(), remoteToken);
        assertEq(l2LiskToken.REMOTE_TOKEN(), remoteToken);
    }

    function test_Mint() public {
        address alice = vm.addr(3);
        address bob = vm.addr(4);

        vm.prank(bridge);
        l2LiskToken.mint(alice, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(bob), 0);
        assertEq(l2LiskToken.totalSupply(), 100 * 10 ** 18);

        vm.prank(bridge);
        l2LiskToken.mint(alice, 50 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 150 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(bob), 0);
        assertEq(l2LiskToken.totalSupply(), 150 * 10 ** 18);

        vm.prank(bridge);
        l2LiskToken.mint(bob, 30 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 150 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(bob), 30 * 10 ** 18);
        assertEq(l2LiskToken.totalSupply(), 180 * 10 ** 18);
    }

    function test_MintFail_NotBridge() public {
        address alice = vm.addr(3);
        address bob = vm.addr(4);

        // try to mint new tokens beeing alice and not the Standard Bridge
        vm.prank(alice);
        vm.expectRevert();
        l2LiskToken.mint(bob, 100 * 10 ** 18);
    }

    function test_Burn() public {
        address alice = vm.addr(3);
        address bob = vm.addr(4);

        vm.prank(bridge);
        l2LiskToken.mint(alice, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(bob), 0);
        assertEq(l2LiskToken.totalSupply(), 100 * 10 ** 18);

        vm.prank(bridge);
        l2LiskToken.mint(bob, 50 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(bob), 50 * 10 ** 18);
        assertEq(l2LiskToken.totalSupply(), 150 * 10 ** 18);

        vm.prank(bridge);
        l2LiskToken.burn(alice, 50 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 50 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(bob), 50 * 10 ** 18);
        assertEq(l2LiskToken.totalSupply(), 100 * 10 ** 18);

        vm.prank(bridge);
        l2LiskToken.burn(alice, 20 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 30 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(bob), 50 * 10 ** 18);
        assertEq(l2LiskToken.totalSupply(), 80 * 10 ** 18);

        vm.prank(bridge);
        l2LiskToken.burn(alice, 30 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(bob), 50 * 10 ** 18);
        assertEq(l2LiskToken.totalSupply(), 50 * 10 ** 18);

        vm.prank(bridge);
        l2LiskToken.burn(bob, 50 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(bob), 0);
        assertEq(l2LiskToken.totalSupply(), 0);
    }

    function test_BurnFail_NotBridge() public {
        address alice = vm.addr(3);
        address bob = vm.addr(4);

        vm.prank(bridge);
        l2LiskToken.mint(bob, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(bob), 100 * 10 ** 18);

        // try to burn tokens beeing alice and not the Standard Bridge
        vm.prank(alice);
        vm.expectRevert();
        l2LiskToken.burn(bob, 100 * 10 ** 18);
    }

    function testFuzz_Transfer(uint256 amount) public {
        address alice = vm.addr(3);
        address bob = vm.addr(4);

        // mint some tokens to alice
        vm.prank(bridge);
        l2LiskToken.mint(alice, amount);
        assertEq(l2LiskToken.balanceOf(alice), amount);

        // send some tokens from alice to bob
        vm.prank(alice);
        l2LiskToken.transfer(bob, amount);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(bob), amount);

        // send some tokens from bob to alice
        vm.prank(bob);
        l2LiskToken.transfer(alice, amount);
        assertEq(l2LiskToken.balanceOf(alice), amount);
        assertEq(l2LiskToken.balanceOf(bob), 0);
    }

    function testFuzz_Allowance(uint256 amount) public {
        address alice = vm.addr(3);
        address bob = vm.addr(4);

        // mint some tokens to alice
        vm.prank(bridge);
        l2LiskToken.mint(alice, amount);
        assertEq(l2LiskToken.balanceOf(alice), amount);

        // alice approves bob to spend some tokens
        vm.prank(alice);
        l2LiskToken.approve(bob, amount);
        assertEq(l2LiskToken.allowance(alice, bob), amount);

        // test that bob can call transferFrom
        vm.prank(bob);
        l2LiskToken.transferFrom(alice, bob, amount);
        // test alice balance
        assertEq(l2LiskToken.balanceOf(alice), 0);
        // test bob balance
        assertEq(l2LiskToken.balanceOf(bob), amount);
    }
}
