// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Ownable } from "src/utils/ownership/Ownable.sol";
import { Unauthorized } from "src/utils/Errors.sol";
import { Test, console2 } from "forge-std/Test.sol";

contract OwnableMock is Ownable {
    uint256 private _value;

    function setValue(uint256 value_) public onlyOwner {
        _value = value_;
    }

    function getValue() public view returns (uint256) {
        return _value;
    }
}

contract OwnableTest is Test {
    OwnableMock ownable;

    function setUp() public {
        ownable = new OwnableMock();
    }

    function test_Initialize() public {
        assertEq(ownable.owner(), address(this));
    }

    function test_isOwner() public {
        assertTrue(ownable.isOwner());

        vm.prank(address(0x1));
        assertFalse(ownable.isOwner());
    }

    function test_onlyOwner() public {
        ownable.setValue(10);
        assertEq(ownable.getValue(), 10);

        vm.prank(address(0x1));
        vm.expectRevert(Unauthorized.selector);
        ownable.setValue(100);
    }
}
