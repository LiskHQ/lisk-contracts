// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { Test } from "forge-std/Test.sol";
import { L2PriceFeedWithoutRoundsFactory } from "src/L2/L2PriceFeedWithoutRoundsFactory.sol";

contract L2PriceFeedWithoutRoundsFactoryV2Mock is L2PriceFeedWithoutRoundsFactory {
    string public testVersion;

    function initializeV2(string memory _version) public reinitializer(2) {
        testVersion = _version;
    }

    function onlyV2() public pure returns (string memory) {
        return "Hello from V2";
    }
}

contract L2PriceFeedWithoutRoundsFactoryTest is Test {
    L2PriceFeedWithoutRoundsFactory public l2PriceFeedFactory;
    L2PriceFeedWithoutRoundsFactory public l2PriceFeedFactoryImplementation;

    address public priceFeedAdapter = 0x19664179Ad4823C6A51035a63C9032ed27ccA441;

    function setUp() public {
        // deploy L2PriceFeedWithoutRoundsFactory Implementation contract
        l2PriceFeedFactoryImplementation = new L2PriceFeedWithoutRoundsFactory();

        // deploy L2PriceFeedWithoutRoundsFactory contract via Proxy and initialize it at the same time
        l2PriceFeedFactory = L2PriceFeedWithoutRoundsFactory(
            address(
                new ERC1967Proxy(
                    address(l2PriceFeedFactoryImplementation),
                    abi.encodeWithSelector(l2PriceFeedFactory.initialize.selector)
                )
            )
        );
    }

    function test_TransferOwnership() public {
        address newOwner = vm.addr(1);

        l2PriceFeedFactory.transferOwnership(newOwner);
        assertEq(l2PriceFeedFactory.owner(), address(this));

        vm.prank(newOwner);
        l2PriceFeedFactory.acceptOwnership();
        assertEq(l2PriceFeedFactory.owner(), newOwner);
    }

    function testFuzz_TransferOwnership_RevertWhenNotCalledByOwner(uint256 _addressSeed) public {
        _addressSeed = bound(_addressSeed, 1, type(uint160).max);
        address nobody = vm.addr(_addressSeed);
        address newOwner = vm.addr(1);

        if (nobody == address(this)) {
            return;
        }

        // owner is this contract
        assertEq(l2PriceFeedFactory.owner(), address(this));

        // address nobody is not the owner so it cannot call transferOwnership
        vm.startPrank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2PriceFeedFactory.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function testFuzz_TransferOwnership_RevertWhenNotCalledByPendingOwner(uint256 _addressSeed) public {
        address newOwner = vm.addr(1);

        l2PriceFeedFactory.transferOwnership(newOwner);
        assertEq(l2PriceFeedFactory.owner(), address(this));

        _addressSeed = bound(_addressSeed, 1, type(uint160).max);
        address nobody = vm.addr(_addressSeed);

        if (nobody == newOwner) {
            return;
        }
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2PriceFeedFactory.acceptOwnership();
    }

    function testFuzz_UpgradeToAndCall_RevertWhenNotOwner(uint256 _addressSeed) public {
        // deploy L2PriceFeedWithoutRoundsFactoryV2Mock implementation contract
        L2PriceFeedWithoutRoundsFactoryV2Mock l2PriceFeedFactoryV2Implementation =
            new L2PriceFeedWithoutRoundsFactoryV2Mock();
        _addressSeed = bound(_addressSeed, 1, type(uint160).max);
        address nobody = vm.addr(_addressSeed);

        if (nobody == address(this)) {
            return;
        }

        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2PriceFeedFactory.upgradeToAndCall(address(l2PriceFeedFactoryV2Implementation), "");
    }

    function test_UpgradeToAndCall_SuccessUpgrade() public {
        // deploy L2PriceFeedWithoutRoundsFactoryV2Mock implementation contract
        L2PriceFeedWithoutRoundsFactoryV2Mock l2PriceFeedFactoryV2Implementation =
            new L2PriceFeedWithoutRoundsFactoryV2Mock();

        // upgrade contract, and also change some variables by reinitialize
        l2PriceFeedFactory.upgradeToAndCall(
            address(l2PriceFeedFactoryV2Implementation),
            abi.encodeWithSelector(l2PriceFeedFactoryV2Implementation.initializeV2.selector, "v2.0.0")
        );

        // wrap L2PriceFeedWithoutRoundsFactory proxy with new contract
        L2PriceFeedWithoutRoundsFactoryV2Mock l2PriceFeedFactoryV2 =
            L2PriceFeedWithoutRoundsFactoryV2Mock(address(l2PriceFeedFactory));

        // version of L2PriceFeedWithoutRoundsFactory set to v2.0.0
        assertEq(l2PriceFeedFactoryV2.testVersion(), "v2.0.0");

        // new function introduced
        assertEq(l2PriceFeedFactoryV2.onlyV2(), "Hello from V2");

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2PriceFeedFactoryV2.initializeV2("v3.0.0");
    }
}
