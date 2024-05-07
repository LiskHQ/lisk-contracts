// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2, StdCheats } from "forge-std/Test.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { L2WdivETH, IOptimismMintableERC20 } from "src/L2/L2WdivETH.sol";
import { SigUtils } from "test/SigUtils.sol";

contract LL2WdivETHTest is Test {
    L2WdivETH public l2WdivETH;
    address public remoteToken;
    address public bridge;
    SigUtils public sigUtils;

    // some accounts to test with
    uint256 public alicePrivateKey;
    uint256 public bobPrivateKey;
    address public alice;
    address public bob;

    // salt for testing unified address
    bytes32 public salt;

    function setUp() public {
        bridge = vm.addr(uint256(bytes32("bridge")));
        remoteToken = vm.addr(uint256(bytes32("remoteToken")));

        // msg.sender and tx.origin needs to be the same for the contract to be able to call initialize()
        vm.prank(address(this), address(this));
        l2WdivETH = new L2WdivETH(remoteToken);
        l2WdivETH.initialize(bridge);
        vm.stopPrank();

        sigUtils = new SigUtils(l2WdivETH.DOMAIN_SEPARATOR());

        (alice, alicePrivateKey) = makeAddrAndKey("alice");
        (bob, bobPrivateKey) = makeAddrAndKey("bob");

        salt = keccak256(bytes("test_salt"));
    }

    function test_ConstructorFail_ZeroRemoteTokenAddress() public {
        vm.expectRevert("L2WdivETH: remoteTokenAddr can not be zero");
        new L2WdivETH(address(0));
    }

    function test_Initialize() public {
        assertEq(l2WdivETH.name(), "Wrapped Diva Ether");
        assertEq(l2WdivETH.symbol(), "wdivETH");
        assertEq(l2WdivETH.decimals(), 18);
        assertEq(l2WdivETH.totalSupply(), 0);
        assertEq(l2WdivETH.remoteToken(), remoteToken);
        assertEq(l2WdivETH.bridge(), bridge);

        // check that an IERC165 interface is supported
        assertEq(l2WdivETH.supportsInterface(type(IERC165).interfaceId), true);

        // check that an IOptimismMintableERC20 interface is supported
        assertEq(l2WdivETH.supportsInterface(type(IOptimismMintableERC20).interfaceId), true);
    }

    function test_Initialize_BridgeAddressChangedEmitted() public {
        address newRemoteToken = vm.addr(uint256(bytes32("newRemoteToken")));
        vm.prank(address(this), address(this));
        L2WdivETH l2WdivETHNew = new L2WdivETH{ salt: salt }(newRemoteToken);
        vm.stopPrank();

        // check that the BridgeAddressChanged event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2WdivETH.BridgeAddressChanged(address(0), bridge);

        vm.prank(address(this), address(this));
        l2WdivETHNew.initialize(bridge);
        vm.stopPrank();
    }

    function test_Initialize_ValidInitializer() public {
        // initialize the contract being alice
        vm.prank(alice, alice);
        L2WdivETH l2WdivETHNew = new L2WdivETH{ salt: salt }(remoteToken);

        // initialize the contract being alice and the initializer
        vm.prank(alice);
        l2WdivETHNew.initialize(bridge);

        // check that the contract is initialized
        assertEq(l2WdivETHNew.BRIDGE(), bridge);
    }

    function test_InitializeFail_NotInitializer() public {
        // initialize the contract being alice
        vm.prank(alice);
        L2WdivETH l2WdivETHNew = new L2WdivETH{ salt: salt }(remoteToken);

        // try to initialize the contract being bob and not the initializer
        vm.prank(bob);
        vm.expectRevert("L2WdivETH: only initializer can initialize this contract");
        l2WdivETHNew.initialize(bridge);
    }

    function test_InitializeFail_AlreadyInitialized() public {
        vm.expectRevert("L2WdivETH: already initialized");
        l2WdivETH.initialize(bridge);
    }

    function test_InitializeFail_ZeroBridgeAddress() public {
        // initialize the contract being alice
        vm.prank(alice, alice);
        L2WdivETH l2WdivETHNew = new L2WdivETH{ salt: salt }(remoteToken);

        // try to initialize the contract with zero bridge address
        vm.prank(alice);
        vm.expectRevert("L2WdivETH: bridgeAddr can not be zero");
        l2WdivETHNew.initialize(address(0));
    }

    function test_UnifiedTokenAddress() public {
        // calculate L2WdivETH contract address
        address l2WdivETHAddressCalculated =
            computeCreate2Address(salt, hashInitCode(type(L2WdivETH).creationCode, abi.encode(remoteToken)), alice);

        // use the same salt and the same deployer as in calculated address of L2WdivETH contract
        vm.prank(alice, alice);
        L2WdivETH l2WdivETHSalted = new L2WdivETH{ salt: salt }(remoteToken);
        vm.prank(alice);
        l2WdivETHSalted.initialize(bridge);

        // check that both token contracts and the calculated address have the same address
        assertEq(address(l2WdivETHSalted), l2WdivETHAddressCalculated);
    }

    function test_UnifiedTokenAddress_DifferentStandardBridgeAddress() public {
        // calculate L2WdivETH contract address
        address l2WdivETHAddressCalculated =
            computeCreate2Address(salt, hashInitCode(type(L2WdivETH).creationCode, abi.encode(remoteToken)), alice);

        // use the same salt and the same deployer as in calculated address of L2WdivETH contract
        vm.prank(alice, alice);
        L2WdivETH l2WdivETHSalted = new L2WdivETH{ salt: salt }(remoteToken);

        // use different Standard Bridge addresses
        vm.prank(alice);
        l2WdivETHSalted.initialize(vm.addr(uint256(bytes32("differentBridge"))));

        // check that both token contracts and the calculated address have the same address
        assertEq(address(l2WdivETHSalted), l2WdivETHAddressCalculated);
    }

    function test_UnifiedTokenAddressFail_DifferentDeployer() public {
        // calculate L2WdivETH contract address
        address l2WdivETHAddressCalculated =
            computeCreate2Address(salt, hashInitCode(type(L2WdivETH).creationCode, abi.encode(remoteToken)), alice);

        // use the same salt but different deployer as in calculated address of L2WdivETH contract
        vm.prank(bob, bob);
        L2WdivETH l2WdivETHSalted = new L2WdivETH{ salt: salt }(remoteToken);
        vm.prank(bob);
        l2WdivETHSalted.initialize(bridge);

        // check that token contracts and the calculated address have different addresses
        assertNotEq(address(l2WdivETHSalted), l2WdivETHAddressCalculated);
    }

    function test_UnifiedTokenAddressFail_DifferentSalt() public {
        // calculate L2WdivETH contract address
        address l2WdivETHAddressCalculated =
            computeCreate2Address(salt, hashInitCode(type(L2WdivETH).creationCode, abi.encode(remoteToken)), alice);

        // use different salt but the same deployer as in calculated address of L2WdivETH contract
        vm.prank(alice, alice);
        L2WdivETH l2WdivETHSalted = new L2WdivETH{ salt: keccak256(bytes("different_salt")) }(remoteToken);
        vm.prank(alice);
        l2WdivETHSalted.initialize(bridge);

        // check that token contracts and the calculated address have different addresses
        assertNotEq(address(l2WdivETHSalted), l2WdivETHAddressCalculated);
    }

    function test_GetBridge() public {
        assertEq(l2WdivETH.bridge(), bridge);
        assertEq(l2WdivETH.BRIDGE(), bridge);
    }

    function test_GetRemoteToken() public {
        assertEq(l2WdivETH.remoteToken(), remoteToken);
        assertEq(l2WdivETH.REMOTE_TOKEN(), remoteToken);
    }

    function test_Mint() public {
        vm.prank(bridge);
        l2WdivETH.mint(alice, 100 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(bob), 0);
        assertEq(l2WdivETH.totalSupply(), 100 * 10 ** 18);

        vm.prank(bridge);
        l2WdivETH.mint(alice, 50 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(alice), 150 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(bob), 0);
        assertEq(l2WdivETH.totalSupply(), 150 * 10 ** 18);

        vm.prank(bridge);
        l2WdivETH.mint(bob, 30 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(alice), 150 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(bob), 30 * 10 ** 18);
        assertEq(l2WdivETH.totalSupply(), 180 * 10 ** 18);
    }

    function test_MintFail_NotBridge() public {
        // try to mint new tokens being alice and not the Standard Bridge
        vm.prank(alice);
        vm.expectRevert("L2WdivETH: only bridge can mint or burn");
        l2WdivETH.mint(bob, 100 * 10 ** 18);
    }

    function test_Burn() public {
        vm.prank(bridge);
        l2WdivETH.mint(alice, 100 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(bob), 0);
        assertEq(l2WdivETH.totalSupply(), 100 * 10 ** 18);

        vm.prank(bridge);
        l2WdivETH.mint(bob, 50 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(bob), 50 * 10 ** 18);
        assertEq(l2WdivETH.totalSupply(), 150 * 10 ** 18);

        vm.prank(bridge);
        l2WdivETH.burn(alice, 50 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(alice), 50 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(bob), 50 * 10 ** 18);
        assertEq(l2WdivETH.totalSupply(), 100 * 10 ** 18);

        vm.prank(bridge);
        l2WdivETH.burn(alice, 20 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(alice), 30 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(bob), 50 * 10 ** 18);
        assertEq(l2WdivETH.totalSupply(), 80 * 10 ** 18);

        vm.prank(bridge);
        l2WdivETH.burn(alice, 30 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(alice), 0);
        assertEq(l2WdivETH.balanceOf(bob), 50 * 10 ** 18);
        assertEq(l2WdivETH.totalSupply(), 50 * 10 ** 18);

        vm.prank(bridge);
        l2WdivETH.burn(bob, 50 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(alice), 0);
        assertEq(l2WdivETH.balanceOf(bob), 0);
        assertEq(l2WdivETH.totalSupply(), 0);
    }

    function test_BurnFail_NotBridge() public {
        vm.prank(bridge);
        l2WdivETH.mint(bob, 100 * 10 ** 18);
        assertEq(l2WdivETH.balanceOf(bob), 100 * 10 ** 18);

        // try to burn tokens being alice and not the Standard Bridge
        vm.prank(alice);
        vm.expectRevert("L2WdivETH: only bridge can mint or burn");
        l2WdivETH.burn(bob, 100 * 10 ** 18);
    }

    function testFuzz_Transfer(uint256 amount) public {
        // mint some tokens to alice
        vm.prank(bridge);
        l2WdivETH.mint(alice, amount);
        assertEq(l2WdivETH.balanceOf(alice), amount);

        // send some tokens from alice to bob
        vm.prank(alice);
        l2WdivETH.transfer(bob, amount);
        assertEq(l2WdivETH.balanceOf(alice), 0);
        assertEq(l2WdivETH.balanceOf(bob), amount);

        // send some tokens from bob to alice
        vm.prank(bob);
        l2WdivETH.transfer(alice, amount);
        assertEq(l2WdivETH.balanceOf(alice), amount);
        assertEq(l2WdivETH.balanceOf(bob), 0);
    }

    function testFuzz_Allowance(uint256 amount) public {
        // mint some tokens to alice
        vm.prank(bridge);
        l2WdivETH.mint(alice, amount);
        assertEq(l2WdivETH.balanceOf(alice), amount);

        // alice approves bob to spend some tokens
        vm.prank(alice);
        l2WdivETH.approve(bob, amount);
        assertEq(l2WdivETH.allowance(alice, bob), amount);

        // test that bob can call transferFrom
        vm.prank(bob);
        l2WdivETH.transferFrom(alice, bob, amount);
        // test alice balance
        assertEq(l2WdivETH.balanceOf(alice), 0);
        // test bob balance
        assertEq(l2WdivETH.balanceOf(bob), amount);
    }

    function test_Permit() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 100 * 10 ** 18,
            nonce: l2WdivETH.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        l2WdivETH.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        assertEq(l2WdivETH.allowance(alice, bob), 100 * 10 ** 18);
        assertEq(l2WdivETH.nonces(alice), 1);
    }

    function test_PermitFail_ExpiredPermit() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 100 * 10 ** 18,
            nonce: l2WdivETH.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        vm.warp(1 days + 1 seconds); // fast forward one second past the deadline

        vm.expectRevert();
        l2WdivETH.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function test_PermitFail_InvalidSigner() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 100 * 10 ** 18,
            nonce: l2WdivETH.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, digest); // bob signs alice's approval

        vm.expectRevert();
        l2WdivETH.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function test_PermitFail_InvalidNonce() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 100 * 10 ** 18,
            nonce: l2WdivETH.nonces(alice) + 1, // alice nonce is 0, but we set it to 1
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        vm.expectRevert();
        l2WdivETH.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function test_PermitFail_SignatureReplay() public {
        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 100 * 10 ** 18,
            nonce: l2WdivETH.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        l2WdivETH.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.expectRevert();
        l2WdivETH.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);
    }

    function test_TransferFromLimitedPermit() public {
        vm.prank(bridge);
        l2WdivETH.mint(alice, 100 * 10 ** 18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 100 * 10 ** 18,
            nonce: l2WdivETH.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        l2WdivETH.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(bob);
        l2WdivETH.transferFrom(alice, bob, 100 * 10 ** 18);

        assertEq(l2WdivETH.balanceOf(alice), 0);
        assertEq(l2WdivETH.balanceOf(bob), 100 * 10 ** 18);
        assertEq(l2WdivETH.allowance(alice, bob), 0);
    }

    function test_TransferFromMaxPermit() public {
        vm.prank(bridge);
        l2WdivETH.mint(alice, 100 * 10 ** 18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: type(uint256).max,
            nonce: l2WdivETH.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        l2WdivETH.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(bob);
        l2WdivETH.transferFrom(alice, bob, 100 * 10 ** 18);

        assertEq(l2WdivETH.balanceOf(alice), 0);
        assertEq(l2WdivETH.balanceOf(bob), 100 * 10 ** 18);
        assertEq(l2WdivETH.allowance(alice, bob), type(uint256).max);
    }

    function test_TransferFromPermitFail_InvalidAllowance() public {
        vm.prank(bridge);
        l2WdivETH.mint(alice, 100 * 10 ** 18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 50 * 10 ** 18, // approve only 50 tokens
            nonce: l2WdivETH.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        l2WdivETH.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(bob);
        vm.expectRevert();
        l2WdivETH.transferFrom(alice, bob, 100 * 10 ** 18); // attempt to transfer 100 token (alice only approved 50)
    }

    function test_TransferFromPermitFail_InvalidBalance() public {
        vm.prank(bridge);
        l2WdivETH.mint(alice, 100 * 10 ** 18);

        SigUtils.Permit memory permit = SigUtils.Permit({
            owner: alice,
            spender: bob,
            value: 101 * 10 ** 18, // approve 101 tokens
            nonce: l2WdivETH.nonces(alice),
            deadline: 1 days
        });

        bytes32 digest = sigUtils.getTypedDataHash(permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        l2WdivETH.permit(permit.owner, permit.spender, permit.value, permit.deadline, v, r, s);

        vm.prank(bob);
        vm.expectRevert();
        l2WdivETH.transferFrom(alice, bob, 101 * 10 ** 18); // attempt to transfer 101 tokens (alice only owns 100)
    }
}
