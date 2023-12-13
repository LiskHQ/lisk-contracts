// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Test, console2, StdCheats } from "forge-std/Test.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { L2LiskToken, IOptimismMintableERC20 } from "src/L2/L2LiskToken.sol";
import { SigUtils } from "test/SigUtils.sol";

contract L2LiskTokenTest is Test {
    L2LiskToken public l2LiskToken;
    address public remoteToken;
    address public bridge;
    SigUtils public sigUtils;

    // some accounts to test with
    uint256 public alicePrivateKey;
    uint256 public bobPrivateKey;
    address public alice;
    address public bob;

    function setUp() public {
        bridge = vm.addr(1);
        remoteToken = vm.addr(2);
        l2LiskToken = new L2LiskToken(bridge, remoteToken);
        sigUtils = new SigUtils(l2LiskToken.DOMAIN_SEPARATOR());

        (alice, alicePrivateKey) = makeAddrAndKey("alice");
        (bob, bobPrivateKey) = makeAddrAndKey("bob");
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
        // try to mint new tokens beeing alice and not the Standard Bridge
        vm.prank(alice);
        vm.expectRevert();
        l2LiskToken.mint(bob, 100 * 10 ** 18);
    }

    function test_Burn() public {
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
        vm.prank(bridge);
        l2LiskToken.mint(bob, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(bob), 100 * 10 ** 18);

        // try to burn tokens beeing alice and not the Standard Bridge
        vm.prank(alice);
        vm.expectRevert();
        l2LiskToken.burn(bob, 100 * 10 ** 18);
    }

    function testFuzz_Transfer(uint256 amount) public {
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

    function test_Permit() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 100 * 10 ** 18,
            nonce: l2LiskToken.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        l2LiskToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        assertEq(l2LiskToken.allowance(alice, bob), 100 * 10 ** 18);
        assertEq(l2LiskToken.nonces(alice), 1);
    }

    function test_PermitFail_ExpiredPermit() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 100 * 10 ** 18,
            nonce: l2LiskToken.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        vm.warp(1 days + 1 seconds); // fast forward one second past the deadline

        vm.expectRevert();
        l2LiskToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function test_PermitFail_InvalidSigner() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 100 * 10 ** 18,
            nonce: l2LiskToken.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest); // bob signs alice's approval

        vm.expectRevert();
        l2LiskToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function test_PermitFail_InvalidNonce() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 100 * 10 ** 18,
            nonce: 1, // alice nonce stored on-chain is 0
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        vm.expectRevert();
        l2LiskToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function test_PermitFail_SignatureReplay() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 100 * 10 ** 18,
            nonce: l2LiskToken.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        l2LiskToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.expectRevert();
        l2LiskToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function test_TransferFromLimitedPermit() public {
        vm.prank(bridge);
        l2LiskToken.mint(alice, 100 * 10 ** 18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 100 * 10 ** 18,
            nonce: l2LiskToken.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        l2LiskToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(bob);
        l2LiskToken.transferFrom(alice, bob, 100 * 10 ** 18);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(bob), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(alice, bob), 0);
    }

    function test_TransferFromMaxPermit() public {
        vm.prank(bridge);
        l2LiskToken.mint(alice, 100 * 10 ** 18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: type(uint256).max,
            nonce: l2LiskToken.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        l2LiskToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(bob);
        l2LiskToken.transferFrom(alice, bob, 100 * 10 ** 18);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(bob), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(alice, bob), type(uint256).max);
    }

    function test_TransferFromPermitFail_InvalidAllowance() public {
        vm.prank(bridge);
        l2LiskToken.mint(alice, 100 * 10 ** 18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 50 * 10 ** 18, // approve only 50 tokens
            nonce: l2LiskToken.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        l2LiskToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(bob);
        vm.expectRevert();
        l2LiskToken.transferFrom(alice, bob, 100 * 10 ** 18); // attempt to transfer 100 token (alice only approved 50)
    }

    function test_TransferFromPermitFail_InvalidBalance() public {
        vm.prank(bridge);
        l2LiskToken.mint(alice, 100 * 10 ** 18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 101 * 10 ** 18, // approve 101 tokens
            nonce: l2LiskToken.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        l2LiskToken.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(bob);
        vm.expectRevert();
        l2LiskToken.transferFrom(alice, bob, 101 * 10 ** 18); // attempt to transfer 101 tokens (alice only owns 100)
    }
}
