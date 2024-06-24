// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { L1LiskToken } from "src/L1/L1LiskToken.sol";
import { SigUtils } from "test/SigUtils.sol";

contract L1LiskTokenTest is Test {
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    event Transfer(address indexed from, address indexed to, uint256 value);

    string private constant NAME = "Lisk";
    string private constant SYMBOL = "LSK";
    uint256 private constant TOTAL_SUPPLY = 400_000_000 * 10 ** 18; //400 million LSK tokens

    L1LiskToken l1LiskToken;

    function setUp() public {
        l1LiskToken = new L1LiskToken();
    }

    function test_Initialize() public view {
        assertEq(l1LiskToken.name(), NAME);
        assertEq(l1LiskToken.symbol(), SYMBOL);
        assertEq(l1LiskToken.totalSupply(), TOTAL_SUPPLY);
        assertEq(l1LiskToken.balanceOf(address(this)), TOTAL_SUPPLY);
        assertEq(l1LiskToken.decimals(), 18);
        assertFalse(l1LiskToken.hasRole(l1LiskToken.DEFAULT_ADMIN_ROLE(), address(this)));
        assertFalse(l1LiskToken.hasRole(l1LiskToken.BURNER_ROLE(), address(this)));
        assertEq(l1LiskToken.owner(), address(this));
        assertEq(l1LiskToken.pendingOwner(), address(0));
    }

    function test_OnlyOwnerAddsOrRenouncesBurner() public {
        address alice = address(0x1);

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        l1LiskToken.addBurner(alice);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        l1LiskToken.renounceBurner(alice);

        vm.stopPrank();

        vm.expectEmit(true, true, true, true, address(l1LiskToken));
        emit RoleGranted(l1LiskToken.BURNER_ROLE(), alice, address(this));
        l1LiskToken.addBurner(alice);
        assertTrue(l1LiskToken.isBurner(alice));

        vm.expectEmit(true, true, true, true, address(l1LiskToken));
        emit RoleRevoked(l1LiskToken.BURNER_ROLE(), alice, address(this));
        l1LiskToken.renounceBurner(alice);
        assertFalse(l1LiskToken.isBurner(alice));
    }

    function test_OwnerIsNotABurner() public {
        uint256 amountToBurn = 1000000;
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), l1LiskToken.BURNER_ROLE()
            )
        );
        l1LiskToken.burn(amountToBurn);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), l1LiskToken.BURNER_ROLE()
            )
        );
        l1LiskToken.burnFrom(address(0x1), amountToBurn);
    }

    function test_OnlyBurnerWithSufficientBalanceBurnsToken() public {
        address alice = address(0x1);
        uint256 amountToBurn = 1000000;
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, l1LiskToken.BURNER_ROLE()
            )
        );
        l1LiskToken.burn(amountToBurn);
        vm.stopPrank();

        l1LiskToken.addBurner(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, amountToBurn));
        l1LiskToken.burn(amountToBurn);

        l1LiskToken.transfer(alice, amountToBurn * 2);
        assertEq(l1LiskToken.balanceOf(alice), amountToBurn * 2);

        vm.prank(alice);
        vm.expectEmit(true, true, false, true, address(l1LiskToken));
        emit Transfer(alice, address(0), amountToBurn);
        l1LiskToken.burn(amountToBurn);

        assertEq(l1LiskToken.balanceOf(alice), amountToBurn);
        assertEq(l1LiskToken.totalSupply(), TOTAL_SUPPLY - amountToBurn);
    }

    function test_OnlyBurnerWithSufficientAllowanceBurnsTokensFromAnAccount() public {
        address alice = address(0x1);
        uint256 amountToBurn = 1000000;
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, l1LiskToken.BURNER_ROLE()
            )
        );
        l1LiskToken.burnFrom(address(this), amountToBurn);
        vm.stopPrank();

        l1LiskToken.addBurner(alice);
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, 0, amountToBurn)
        );
        l1LiskToken.burnFrom(address(this), amountToBurn);

        l1LiskToken.approve(alice, amountToBurn);
        assertEq(l1LiskToken.allowance(address(this), alice), amountToBurn);

        vm.prank(alice);
        l1LiskToken.burnFrom(address(this), amountToBurn);

        assertEq(l1LiskToken.allowance(address(this), alice), 0);
        assertEq(l1LiskToken.totalSupply(), TOTAL_SUPPLY - amountToBurn);
    }

    function test_Permit() public {
        uint256 ownerPrivateKey = 0xB0B;
        uint256 spenderPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        address spender = vm.addr(spenderPrivateKey);
        SigUtils sigUtils = new SigUtils(l1LiskToken.DOMAIN_SEPARATOR());
        SigUtils.Permit memory permit =
            SigUtils.Permit({ owner: owner, spender: spender, value: 1000000, nonce: 0, deadline: 1 days });
        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        l1LiskToken.transfer(permit.owner, 2000000);
        l1LiskToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        assertEq(l1LiskToken.allowance(owner, spender), permit.value);
    }

    function test_OnlyOwnerTransfersTheOwnership() public {
        address alice = address(0x1);
        address bob = address(0x2);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        l1LiskToken.transferOwnership(bob);
        vm.stopPrank();

        assertEq(l1LiskToken.owner(), address(this));
        assertEq(l1LiskToken.pendingOwner(), address(0));
        vm.expectEmit(true, true, true, true);
        emit Ownable2Step.OwnershipTransferStarted(address(this), alice);
        l1LiskToken.transferOwnership(alice);
        assertEq(l1LiskToken.owner(), address(this));
        assertEq(l1LiskToken.pendingOwner(), alice);

        vm.expectEmit(true, true, true, true);
        emit Ownable.OwnershipTransferred(address(this), alice);
        vm.prank(alice);
        l1LiskToken.acceptOwnership();

        assertEq(l1LiskToken.owner(), alice);
        assertEq(l1LiskToken.pendingOwner(), address(0));
    }

    function test_OnlyOwnerTransfersTheOwnership_AcceptNotCalledByPendingOwner() public {
        address alice = address(0x1);
        address bob = address(0x2);

        assertEq(l1LiskToken.owner(), address(this));
        assertEq(l1LiskToken.pendingOwner(), address(0));
        l1LiskToken.transferOwnership(alice);
        assertEq(l1LiskToken.owner(), address(this));
        assertEq(l1LiskToken.pendingOwner(), alice);

        // call acceptOwnership without being the pending owner
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
        l1LiskToken.acceptOwnership();

        assertEq(l1LiskToken.owner(), address(this));
        assertEq(l1LiskToken.pendingOwner(), alice);
    }

    function test_DefaultAdminRoleIsRoleAdminForBurnerRole() public view {
        assertEq(l1LiskToken.DEFAULT_ADMIN_ROLE(), l1LiskToken.getRoleAdmin(l1LiskToken.BURNER_ROLE()));
    }
}
