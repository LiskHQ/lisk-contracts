// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { Test } from "forge-std/Test.sol";
import { L2MultiFeedAdapterWithoutRoundsMainDemo } from "src/L2/L2MultiFeedAdapterWithoutRoundsMainDemo.sol";

contract L2MultiFeedAdapterWithoutRoundsMainDemoV2Mock is L2MultiFeedAdapterWithoutRoundsMainDemo {
    string public testVersion;

    function initializeV2(string memory _version) public reinitializer(2) {
        testVersion = _version;
    }

    function onlyV2() public pure returns (string memory) {
        return "Hello from V2";
    }
}

contract L2MultiFeedAdapterWithoutRoundsMainDemoTest is Test {
    L2MultiFeedAdapterWithoutRoundsMainDemo public l2Adapter;
    L2MultiFeedAdapterWithoutRoundsMainDemo public l2AdapterImplementation;

    function setUp() public {
        // deploy L2MultiFeedAdapterWithoutRoundsMainDemo Implementation contract
        l2AdapterImplementation = new L2MultiFeedAdapterWithoutRoundsMainDemo();

        // deploy L2MultiFeedAdapterWithoutRoundsMainDemo contract via Proxy and initialize it at the same time
        l2Adapter = L2MultiFeedAdapterWithoutRoundsMainDemo(
            address(
                new ERC1967Proxy(
                    address(l2AdapterImplementation), abi.encodeWithSelector(l2Adapter.initialize.selector)
                )
            )
        );
        assertEq(l2Adapter.getUniqueSignersThreshold(), 1);
        assertEq(l2Adapter.getAuthorisedSignerIndex(0x0C39486f770B26F5527BBBf942726537986Cd7eb), 0);
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
        // deploy L2MultiFeedAdapterWithoutRoundsMainDemoV2Mock implementation contract
        L2MultiFeedAdapterWithoutRoundsMainDemoV2Mock l2AdapterV2Implementation =
            new L2MultiFeedAdapterWithoutRoundsMainDemoV2Mock();
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
        // deploy L2MultiFeedAdapterWithoutRoundsMainDemoV2Mock implementation contract
        L2MultiFeedAdapterWithoutRoundsMainDemoV2Mock l2AdapterV2Implementation =
            new L2MultiFeedAdapterWithoutRoundsMainDemoV2Mock();

        // upgrade contract, and also change some variables by reinitialize
        l2Adapter.upgradeToAndCall(
            address(l2AdapterV2Implementation),
            abi.encodeWithSelector(l2AdapterV2Implementation.initializeV2.selector, "v2.0.0")
        );

        // wrap L2MultiFeedAdapterWithoutRoundsMainDemo proxy with new contract
        L2MultiFeedAdapterWithoutRoundsMainDemoV2Mock l2AdapterV2 =
            L2MultiFeedAdapterWithoutRoundsMainDemoV2Mock(address(l2Adapter));

        // signer threshold and signer index should remain the same
        assertEq(l2AdapterV2.getUniqueSignersThreshold(), 1);
        assertEq(l2AdapterV2.getAuthorisedSignerIndex(0x0C39486f770B26F5527BBBf942726537986Cd7eb), 0);

        // version of L2MultiFeedAdapterWithoutRoundsMainDemo set to v2.0.0
        assertEq(l2AdapterV2.testVersion(), "v2.0.0");

        // new function introduced
        assertEq(l2AdapterV2.onlyV2(), "Hello from V2");

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2AdapterV2.initializeV2("v3.0.0");
    }
}
