// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { Test } from "forge-std/Test.sol";
import { L2MultiFeedAdapterWithoutRoundsPrimaryProd } from "src/L2/L2MultiFeedAdapterWithoutRoundsPrimaryProd.sol";

contract L2MultiFeedAdapterWithoutRoundsPrimaryProdV2Mock is L2MultiFeedAdapterWithoutRoundsPrimaryProd {
    string public testVersion;

    function initializeV2(string memory _version) public reinitializer(2) {
        testVersion = _version;
    }

    function onlyV2() public pure returns (string memory) {
        return "Hello from V2";
    }
}

contract L2MultiFeedAdapterWithoutRoundsPrimaryProdTest is Test {
    L2MultiFeedAdapterWithoutRoundsPrimaryProd public l2Adapter;
    L2MultiFeedAdapterWithoutRoundsPrimaryProd public l2AdapterImplementation;

    function setUp() public {
        // deploy L2MultiFeedAdapterWithoutRoundsPrimaryProd Implementation contract
        l2AdapterImplementation = new L2MultiFeedAdapterWithoutRoundsPrimaryProd();

        // deploy L2MultiFeedAdapterWithoutRoundsPrimaryProd contract via Proxy and initialize it at the same time
        l2Adapter = L2MultiFeedAdapterWithoutRoundsPrimaryProd(
            address(
                new ERC1967Proxy(
                    address(l2AdapterImplementation), abi.encodeWithSelector(l2Adapter.initialize.selector)
                )
            )
        );
        assertEq(l2Adapter.getUniqueSignersThreshold(), 2);
        assertEq(l2Adapter.getAuthorisedSignerIndex(0x8BB8F32Df04c8b654987DAaeD53D6B6091e3B774), 0);
        assertEq(l2Adapter.getAuthorisedSignerIndex(0xdEB22f54738d54976C4c0fe5ce6d408E40d88499), 1);
        assertEq(l2Adapter.getAuthorisedSignerIndex(0x51Ce04Be4b3E32572C4Ec9135221d0691Ba7d202), 2);
        assertEq(l2Adapter.getAuthorisedSignerIndex(0xDD682daEC5A90dD295d14DA4b0bec9281017b5bE), 3);
        assertEq(l2Adapter.getAuthorisedSignerIndex(0x9c5AE89C4Af6aA32cE58588DBaF90d18a855B6de), 4);
    }

    function test_TransferOwnership() public {
        address newOwner = vm.addr(1);

        l2Adapter.transferOwnership(newOwner);
        assertEq(l2Adapter.owner(), address(this));

        vm.prank(newOwner);
        l2Adapter.acceptOwnership();
        assertEq(l2Adapter.owner(), newOwner);
    }

    function testFuzz_TransferOwnership_RevertWhenNotCalledByOwner(uint256 _addressSeed) public {
        _addressSeed = bound(_addressSeed, 1, type(uint160).max);
        address nobody = vm.addr(_addressSeed);
        address newOwner = vm.addr(1);

        if (nobody == address(this)) {
            return;
        }

        // owner is this contract
        assertEq(l2Adapter.owner(), address(this));

        // address nobody is not the owner so it cannot call transferOwnership
        vm.startPrank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2Adapter.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function testFuzz_TransferOwnership_RevertWhenNotCalledByPendingOwner(uint256 _addressSeed) public {
        address newOwner = vm.addr(1);

        l2Adapter.transferOwnership(newOwner);
        assertEq(l2Adapter.owner(), address(this));

        _addressSeed = bound(_addressSeed, 1, type(uint160).max);
        address nobody = vm.addr(_addressSeed);

        if (nobody == newOwner) {
            return;
        }
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2Adapter.acceptOwnership();
    }

    function testFuzz_UpgradeToAndCall_RevertWhenNotOwner(uint256 _addressSeed) public {
        // deploy L2MultiFeedAdapterWithoutRoundsPrimaryProdV2Mock implementation contract
        L2MultiFeedAdapterWithoutRoundsPrimaryProdV2Mock l2AdapterV2Implementation =
            new L2MultiFeedAdapterWithoutRoundsPrimaryProdV2Mock();
        _addressSeed = bound(_addressSeed, 1, type(uint160).max);
        address nobody = vm.addr(_addressSeed);

        if (nobody == address(this)) {
            return;
        }

        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2Adapter.upgradeToAndCall(address(l2AdapterV2Implementation), "");
    }

    function test_UpgradeToAndCall_SuccessUpgrade() public {
        // deploy L2MultiFeedAdapterWithoutRoundsPrimaryProdV2Mock implementation contract
        L2MultiFeedAdapterWithoutRoundsPrimaryProdV2Mock l2AdapterV2Implementation =
            new L2MultiFeedAdapterWithoutRoundsPrimaryProdV2Mock();

        // upgrade contract, and also change some variables by reinitialize
        l2Adapter.upgradeToAndCall(
            address(l2AdapterV2Implementation),
            abi.encodeWithSelector(l2AdapterV2Implementation.initializeV2.selector, "v2.0.0")
        );

        // wrap L2MultiFeedAdapterWithoutRoundsPrimaryProd proxy with new contract
        L2MultiFeedAdapterWithoutRoundsPrimaryProdV2Mock l2AdapterV2 =
            L2MultiFeedAdapterWithoutRoundsPrimaryProdV2Mock(address(l2Adapter));

        // signer threshold and signer index should remain the same
        assertEq(l2AdapterV2.getUniqueSignersThreshold(), 2);
        assertEq(l2AdapterV2.getAuthorisedSignerIndex(0x8BB8F32Df04c8b654987DAaeD53D6B6091e3B774), 0);
        assertEq(l2AdapterV2.getAuthorisedSignerIndex(0xdEB22f54738d54976C4c0fe5ce6d408E40d88499), 1);
        assertEq(l2AdapterV2.getAuthorisedSignerIndex(0x51Ce04Be4b3E32572C4Ec9135221d0691Ba7d202), 2);
        assertEq(l2AdapterV2.getAuthorisedSignerIndex(0xDD682daEC5A90dD295d14DA4b0bec9281017b5bE), 3);
        assertEq(l2AdapterV2.getAuthorisedSignerIndex(0x9c5AE89C4Af6aA32cE58588DBaF90d18a855B6de), 4);

        // version of L2MultiFeedAdapterWithoutRoundsPrimaryProd set to v2.0.0
        assertEq(l2AdapterV2.testVersion(), "v2.0.0");

        // new function introduced
        assertEq(l2AdapterV2.onlyV2(), "Hello from V2");

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2AdapterV2.initializeV2("v3.0.0");
    }
}
