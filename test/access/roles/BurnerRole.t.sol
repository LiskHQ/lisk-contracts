// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Test, console2 } from "forge-std/Test.sol";
import { BurnerRole } from "src/access/roles/BurnerRole.sol";

contract BurnerRoleMock is BurnerRole {
    uint8 private _value;

    function setValue(uint8 value_) public onlyBurner {
        _value = value_;
    }

    function getValue() public view returns (uint8) {
        return _value;
    }
}

contract BurnerRoleTest is Test {
    event BurnerAdded(address indexed account);
    event BurnerRemoved(address indexed account);

    BurnerRoleMock burnerRole;

    function setUp() public {
        burnerRole = new BurnerRoleMock();
    }

    function test_isBurner() public {
        assertFalse(burnerRole.isBurner(address(this)));

        burnerRole.addBurner(address(this));
        assertTrue(burnerRole.isBurner(address(this)));
    }

    function test_addAndRenounceBurner() public {
        address alice = address(0x1);

        vm.expectEmit(true, false, false, true, address(burnerRole));
        emit BurnerAdded(alice);
        burnerRole.addBurner(alice);

        assertTrue(burnerRole.isBurner(alice));

        vm.expectEmit(true, false, false, true, address(burnerRole));
        emit BurnerRemoved(alice);
        burnerRole.renounceBurner(alice);

        assertFalse(burnerRole.isBurner(alice));
    }

    function test_onlyBurner() public {
        address alice = address(0x1);

        vm.expectRevert(abi.encodeWithSelector(BurnerRole.UnauthorizedBurnerAccount.selector, address(this)));
        burnerRole.setValue(10);

        burnerRole.addBurner(alice);

        vm.prank(alice);
        burnerRole.setValue(10);
        assertEq(burnerRole.getValue(), 10);
    }
}
