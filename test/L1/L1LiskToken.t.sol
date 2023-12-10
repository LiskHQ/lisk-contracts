// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Test, console2 } from "forge-std/Test.sol";
import { L1LiskToken } from "src/L1/L1LiskToken.sol";
import { Unauthorized } from "src/utils/Errors.sol";

contract L1LiskTokenTest is Test {
    event BurnerAdded(address indexed account);
    event BurnerRemoved(address indexed account);

    string private constant NAME = "Lisk";
    string private constant SYMBOL = "LSK";
    uint256 private constant TOTAL_SUPPLY = 200_000_000 * 10 ** 18; //200 million LSK tokens

    L1LiskToken l1LiskToken;

    function setUp() public {
        l1LiskToken = new L1LiskToken();
    }

    function test_Initialize() public {
        assertEq(l1LiskToken.name(), NAME);
        assertEq(l1LiskToken.symbol(), SYMBOL);
        assertEq(l1LiskToken.totalSupply(), TOTAL_SUPPLY);
        assertEq(l1LiskToken.balanceOf(address(this)), TOTAL_SUPPLY);
        assertEq(l1LiskToken.owner(), address(this));
    }

    function test_addAndRenounceBurner() public {
        address alice = address(0x1);

        vm.expectEmit(true, false, false, true, address(l1LiskToken));
        emit BurnerAdded(alice);
        l1LiskToken.addBurner(alice);
        assertTrue(l1LiskToken.isBurner(alice));

        vm.expectEmit(true, false, false, true, address(l1LiskToken));
        emit BurnerRemoved(alice);
        l1LiskToken.renounceBurner(alice);
        assertFalse(l1LiskToken.isBurner(alice));
    }

    function test_onlyOwnerAddsOrRenouncesBurner() public {
        address alice = address(0x1);

        vm.startPrank(alice);

        vm.expectRevert(Unauthorized.selector);
        l1LiskToken.addBurner(alice);

        vm.expectRevert(Unauthorized.selector);
        l1LiskToken.renounceBurner(alice);

        vm.stopPrank();

        l1LiskToken.addBurner(alice);
        assertTrue(l1LiskToken.isBurner(alice));

        l1LiskToken.renounceBurner(alice);
        assertFalse(l1LiskToken.isBurner(alice));
    }
}
