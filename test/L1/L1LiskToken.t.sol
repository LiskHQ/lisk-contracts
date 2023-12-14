// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Test, console2 } from "forge-std/Test.sol";
import { L1LiskToken } from "src/L1/L1LiskToken.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract SigUtils {
    bytes32 internal DOMAIN_SEPARATOR;
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    function getPermitDataHash(Permit memory _permit) public view returns (bytes32) {
        bytes32 permitHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, _permit.owner, _permit.spender, _permit.value, _permit.nonce, _permit.deadline)
        );
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, permitHash));
    }
}

contract L1LiskTokenTest is Test {
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    event Transfer(address indexed from, address indexed to, uint256 value);

    string private constant NAME = "Lisk";
    string private constant SYMBOL = "LSK";
    uint256 private constant TOTAL_SUPPLY = 300_000_000 * 10 ** 18; //300 million LSK tokens
    bytes32 private defaultAdminRole = bytes32(0x00);

    L1LiskToken l1LiskToken;

    function setUp() public {
        l1LiskToken = new L1LiskToken();
    }

    function test_Initialize() public {
        assertEq(l1LiskToken.name(), NAME);
        assertEq(l1LiskToken.symbol(), SYMBOL);
        assertEq(l1LiskToken.totalSupply(), TOTAL_SUPPLY);
        assertEq(l1LiskToken.balanceOf(address(this)), TOTAL_SUPPLY);
    }

    function test_onlyOwnerAddsOrRenouncesBurner() public {
        address alice = address(0x1);

        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, defaultAdminRole)
        );
        l1LiskToken.addBurner(alice);

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, defaultAdminRole)
        );
        l1LiskToken.renounceBurner(alice);

        vm.stopPrank();

        vm.expectEmit(true, true, true, true, address(l1LiskToken));
        emit RoleGranted(l1LiskToken.getBurnerRole(), alice, address(this));
        l1LiskToken.addBurner(alice);
        assertTrue(l1LiskToken.isBurner(alice));

        vm.expectEmit(true, true, true, true, address(l1LiskToken));
        emit RoleRevoked(l1LiskToken.getBurnerRole(), alice, address(this));
        l1LiskToken.renounceBurner(alice);
        assertFalse(l1LiskToken.isBurner(alice));
    }

    function test_onlyBurnerWithSufficientBalanceBurnsToken() public {
        address alice = address(0x1);
        uint256 amountToBurn = 1000000;
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, l1LiskToken.getBurnerRole()
            )
        );
        l1LiskToken.burn(amountToBurn);
        vm.stopPrank();

        l1LiskToken.addBurner(alice);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, 0, amountToBurn));
        l1LiskToken.burn(amountToBurn);

        l1LiskToken.transfer(alice, amountToBurn * 2);
        vm.prank(alice);
        vm.expectEmit(true, true, false, true, address(l1LiskToken));
        emit Transfer(alice, address(0), amountToBurn);
        l1LiskToken.burn(amountToBurn);

        assertEq(l1LiskToken.balanceOf(alice), amountToBurn);
        assertEq(l1LiskToken.totalSupply(), TOTAL_SUPPLY - amountToBurn);
    }

    function test_onlyBurnerWithSufficientAllowanceBurnsTokensFromAnAccount() public {
        address alice = address(0x1);
        uint256 amountToBurn = 1000000;
        vm.startPrank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, alice, l1LiskToken.getBurnerRole()
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
        vm.prank(alice);
        l1LiskToken.burnFrom(address(this), amountToBurn);

        assertEq(l1LiskToken.allowance(address(this), alice), 0);
        assertEq(l1LiskToken.totalSupply(), TOTAL_SUPPLY - amountToBurn);
    }

    function test_permit() public {
        uint256 ownerPrivateKey = 0xB0B;
        uint256 spenderPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        address spender = vm.addr(spenderPrivateKey);
        SigUtils sigUtils = new SigUtils(l1LiskToken.DOMAIN_SEPARATOR());
        SigUtils.Permit memory permit =
            SigUtils.Permit({ owner: owner, spender: spender, value: 1000000, nonce: 0, deadline: 1 days });
        bytes32 digest = sigUtils.getPermitDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        l1LiskToken.transfer(permit.owner, 2000000);
        l1LiskToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        assertEq(l1LiskToken.allowance(owner, spender), permit.value);
    }

    function test_ownerIsAdminForOwnerAndBurnerRole() public {
        bytes32 roleAdmin = bytes32(uint256(uint160(address(this))));
        assertEq(roleAdmin, l1LiskToken.getRoleAdmin(defaultAdminRole));
        assertEq(roleAdmin, l1LiskToken.getRoleAdmin(l1LiskToken.getBurnerRole()));
    }
}
