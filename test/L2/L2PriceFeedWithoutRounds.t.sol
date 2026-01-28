// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { Test, console } from "forge-std/Test.sol";
import { L2PriceFeedWithoutRoundsFactory } from "src/L2/L2PriceFeedWithoutRoundsFactory.sol";
import { L2PriceFeedWithoutRounds } from "src/L2/L2PriceFeedWithoutRounds.sol";
import { L2PriceFeedWithoutRoundsV2 } from "src/L2/upgraded/L2PriceFeedWithoutRoundsV2.sol";
import { L2PriceFeedWithoutRoundsV3 } from "src/L2/upgraded/L2PriceFeedWithoutRoundsV3.sol";
import { L2PriceFeedWithoutRoundsV4 } from "src/L2/upgraded/L2PriceFeedWithoutRoundsV4.sol";

contract L2PriceFeedWithoutRoundsTest is Test {
    L2PriceFeedWithoutRounds public l2PriceFeed;
    L2PriceFeedWithoutRounds public l2PriceFeedImplementation;

    address public priceFeedAdapter = vm.addr(uint256(bytes32("priceFeedAdapter")));
    address public newPriceFeedAdapter = vm.addr(uint256(bytes32("newPriceFeedAdapter")));

    function setUp() public {
        // deploy L2PriceFeedWithoutRoundsFactory Implementation contract
        L2PriceFeedWithoutRoundsFactory l2PriceFeedFactoryImplementation = new L2PriceFeedWithoutRoundsFactory();

        // deploy L2PriceFeedWithoutRoundsFactory contract via Proxy and initialize it at the same time
        L2PriceFeedWithoutRoundsFactory l2PriceFeedFactory;
        l2PriceFeedFactory = L2PriceFeedWithoutRoundsFactory(
            address(
                new ERC1967Proxy(
                    address(l2PriceFeedFactoryImplementation),
                    abi.encodeWithSelector(l2PriceFeedFactory.initialize.selector)
                )
            )
        );

        // create L2PriceFeedWithoutRounds contract
        l2PriceFeed =
            L2PriceFeedWithoutRounds(l2PriceFeedFactory.createL2PriceFeedWithoutRounds("LSK", priceFeedAdapter));
        assert(address(l2PriceFeed) != address(0));
        assertEq(l2PriceFeed.decimals(), 8);
        assertEq(keccak256(bytes(l2PriceFeed.description())), keccak256(bytes("Redstone Price Feed")));
        assertEq(l2PriceFeed.getDataFeedId(), bytes32("LSK"));
        assertEq(address(l2PriceFeed.getPriceFeedAdapter()), priceFeedAdapter);

        // accept ownership
        l2PriceFeed.acceptOwnership();

        // check L2PriceFeedWithoutRoundsFactory variables
        assertEq(l2PriceFeedFactory.l2PriceFeedWithoutRoundsContracts(0), address(l2PriceFeed));
        assertEq(l2PriceFeedFactory.l2PriceFeedWithoutRoundsDataFeedIds(address(l2PriceFeed), 0), "LSK");
    }

    function test_TransferOwnership() public {
        address newOwner = vm.addr(1);

        l2PriceFeed.transferOwnership(newOwner);
        assertEq(l2PriceFeed.owner(), address(this));

        vm.prank(newOwner);
        l2PriceFeed.acceptOwnership();
        assertEq(l2PriceFeed.owner(), newOwner);
    }

    function testFuzz_TransferOwnership_RevertWhenNotCalledByOwner(uint256 _addressSeed) public {
        _addressSeed = bound(_addressSeed, 1, type(uint160).max);
        address nobody = vm.addr(_addressSeed);
        address newOwner = vm.addr(1);

        if (nobody == address(this)) {
            return;
        }

        // owner is this contract
        assertEq(l2PriceFeed.owner(), address(this));

        // address nobody is not the owner so it cannot call transferOwnership
        vm.startPrank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2PriceFeed.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function testFuzz_TransferOwnership_RevertWhenNotCalledByPendingOwner(uint256 _addressSeed) public {
        address newOwner = vm.addr(1);

        l2PriceFeed.transferOwnership(newOwner);
        assertEq(l2PriceFeed.owner(), address(this));

        _addressSeed = bound(_addressSeed, 1, type(uint160).max);
        address nobody = vm.addr(_addressSeed);

        if (nobody == newOwner) {
            return;
        }
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2PriceFeed.acceptOwnership();
    }

    function testFuzz_UpgradeToAndCall_RevertWhenNotOwner(uint256 _addressSeed) public {
        // deploy L2PriceFeedWithoutRoundsV2 implementation contract
        L2PriceFeedWithoutRoundsV2 l2PriceFeedV2Implementation = new L2PriceFeedWithoutRoundsV2();
        _addressSeed = bound(_addressSeed, 1, type(uint160).max);
        address nobody = vm.addr(_addressSeed);

        if (nobody == address(this)) {
            return;
        }

        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2PriceFeed.upgradeToAndCall(address(l2PriceFeedV2Implementation), "");
    }

    function test_UpgradeToAndCall_ZeroAdapterAddress() public {
        // deploy L2PriceFeedWithoutRoundsV2 implementation contract
        L2PriceFeedWithoutRoundsV2 l2PriceFeedV2Implementation = new L2PriceFeedWithoutRoundsV2();

        // try to upgrade to L2PriceFeedWithoutRoundsV2 implementation contract with zero adapter address
        vm.expectRevert("L2PriceFeedWithoutRoundsV2: new adapter contract address can not be zero");
        l2PriceFeed.upgradeToAndCall(
            address(l2PriceFeedV2Implementation),
            abi.encodeWithSelector(l2PriceFeedV2Implementation.initializeV2.selector, 0x0)
        );
    }

    function test_UpgradeToAndCall_SuccessUpgrade() public {
        // deploy L2PriceFeedWithoutRoundsV2 implementation contract
        L2PriceFeedWithoutRoundsV2 l2PriceFeedV2Implementation = new L2PriceFeedWithoutRoundsV2();

        // upgrade contract, and also change priceFeedAdapter address
        l2PriceFeed.upgradeToAndCall(
            address(l2PriceFeedV2Implementation),
            abi.encodeWithSelector(l2PriceFeedV2Implementation.initializeV2.selector, newPriceFeedAdapter)
        );

        // wrap L2PriceFeedWithoutRounds proxy with new contract
        L2PriceFeedWithoutRoundsV2 l2PriceFeedV2 = L2PriceFeedWithoutRoundsV2(address(l2PriceFeed));

        // check if the upgrade was successful and the new priceFeedAdapter address is set
        assertEq(l2PriceFeedV2.decimals(), 8);
        assertEq(keccak256(bytes(l2PriceFeedV2.description())), keccak256(bytes("Redstone Price Feed")));
        assertEq(l2PriceFeedV2.getDataFeedId(), bytes32("LSK"));
        assertEq(address(l2PriceFeedV2.getPriceFeedAdapter()), newPriceFeedAdapter);

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2PriceFeedV2.initializeV2(newPriceFeedAdapter);
    }

    function testFuzz_UpgradeToV3AndCall_RevertWhenNotOwner(uint256 _addressSeed) public {
        // deploy L2PriceFeedWithoutRoundsV3 implementation contract
        L2PriceFeedWithoutRoundsV3 l2PriceFeedV3Implementation = new L2PriceFeedWithoutRoundsV3();
        _addressSeed = bound(_addressSeed, 1, type(uint160).max);
        address nobody = vm.addr(_addressSeed);

        if (nobody == address(this)) {
            return;
        }

        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2PriceFeed.upgradeToAndCall(address(l2PriceFeedV3Implementation), "");
    }

    function test_UpgradeToV3AndCall_EmptyFeedId() public {
        // deploy L2PriceFeedWithoutRoundsV3 implementation contract
        L2PriceFeedWithoutRoundsV3 l2PriceFeedV3Implementation = new L2PriceFeedWithoutRoundsV3();

        // try to upgrade to L2PriceFeedWithoutRoundsV3 implementation contract with empty feed ID
        vm.expectRevert("L2PriceFeedWithoutRoundsV3: data feed ID can not be empty");
        l2PriceFeed.upgradeToAndCall(
            address(l2PriceFeedV3Implementation),
            abi.encodeWithSelector(l2PriceFeedV3Implementation.initializeV3.selector, "")
        );
    }

    function test_UpgradeToV3AndCall_SuccessUpgrade() public {
        // deploy L2PriceFeedWithoutRoundsV3 implementation contract
        L2PriceFeedWithoutRoundsV3 l2PriceFeedV3Implementation = new L2PriceFeedWithoutRoundsV3();

        // upgrade contract and change dataFeedId from "LSK" to "BTC"
        l2PriceFeed.upgradeToAndCall(
            address(l2PriceFeedV3Implementation),
            abi.encodeWithSelector(l2PriceFeedV3Implementation.initializeV3.selector, "BTC")
        );

        // wrap L2PriceFeedWithoutRounds proxy with new contract
        L2PriceFeedWithoutRoundsV3 l2PriceFeedV3 = L2PriceFeedWithoutRoundsV3(address(l2PriceFeed));

        // check if the upgrade was successful and the new dataFeedId is set
        assertEq(l2PriceFeedV3.decimals(), 8);
        assertEq(keccak256(bytes(l2PriceFeedV3.description())), keccak256(bytes("Redstone Price Feed")));
        assertEq(l2PriceFeedV3.getDataFeedId(), bytes32("BTC"));
        assertEq(address(l2PriceFeedV3.getPriceFeedAdapter()), priceFeedAdapter);

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2PriceFeedV3.initializeV3("ETH");
    }

    function testFuzz_UpgradeToV4AndCall_RevertWhenNotOwner(uint256 _addressSeed) public {
        // deploy L2PriceFeedWithoutRoundsV4 implementation contract
        L2PriceFeedWithoutRoundsV4 l2PriceFeedV4Implementation = new L2PriceFeedWithoutRoundsV4();
        _addressSeed = bound(_addressSeed, 1, type(uint160).max);
        address nobody = vm.addr(_addressSeed);

        if (nobody == address(this)) {
            return;
        }

        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2PriceFeed.upgradeToAndCall(address(l2PriceFeedV4Implementation), "");
    }

    function test_UpgradeToV4AndCall_SuccessUpgrade() public {
        // deploy L2PriceFeedWithoutRoundsV4 implementation contract
        L2PriceFeedWithoutRoundsV4 l2PriceFeedV4Implementation = new L2PriceFeedWithoutRoundsV4();

        // upgrade contract
        l2PriceFeed.upgradeToAndCall(
            address(l2PriceFeedV4Implementation),
            abi.encodeWithSelector(l2PriceFeedV4Implementation.initializeV4.selector)
        );

        // wrap L2PriceFeedWithoutRounds proxy with new contract
        L2PriceFeedWithoutRoundsV4 l2PriceFeedV4 = L2PriceFeedWithoutRoundsV4(address(l2PriceFeed));

        // check if the upgrade was successful
        assertEq(l2PriceFeedV4.decimals(), 8);
        assertEq(keccak256(bytes(l2PriceFeedV4.description())), keccak256(bytes("Redstone Price Feed")));
        assertEq(l2PriceFeedV4.getDataFeedId(), bytes32("LSK"));
        assertEq(address(l2PriceFeedV4.getPriceFeedAdapter()), priceFeedAdapter);

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2PriceFeedV4.initializeV4();
    }

    function test_V4_LatestAnswer_ReturnsFixedValue() public {
        // deploy and upgrade to V4
        L2PriceFeedWithoutRoundsV4 l2PriceFeedV4Implementation = new L2PriceFeedWithoutRoundsV4();
        l2PriceFeed.upgradeToAndCall(
            address(l2PriceFeedV4Implementation),
            abi.encodeWithSelector(l2PriceFeedV4Implementation.initializeV4.selector)
        );
        L2PriceFeedWithoutRoundsV4 l2PriceFeedV4 = L2PriceFeedWithoutRoundsV4(address(l2PriceFeed));

        // check latestAnswer returns fixed value
        assertEq(l2PriceFeedV4.latestAnswer(), 100000000);
    }

    function test_V4_LatestRoundData_ReturnsFixedValue() public {
        // deploy and upgrade to V4
        L2PriceFeedWithoutRoundsV4 l2PriceFeedV4Implementation = new L2PriceFeedWithoutRoundsV4();
        l2PriceFeed.upgradeToAndCall(
            address(l2PriceFeedV4Implementation),
            abi.encodeWithSelector(l2PriceFeedV4Implementation.initializeV4.selector)
        );
        L2PriceFeedWithoutRoundsV4 l2PriceFeedV4 = L2PriceFeedWithoutRoundsV4(address(l2PriceFeed));

        // check latestRoundData returns correct values
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            l2PriceFeedV4.latestRoundData();

        assertEq(roundId, 1);
        assertEq(answer, 100000000);
        assertEq(startedAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 1);
    }

    function test_V4_GetRoundData_ReturnsFixedValue() public {
        // deploy and upgrade to V4
        L2PriceFeedWithoutRoundsV4 l2PriceFeedV4Implementation = new L2PriceFeedWithoutRoundsV4();
        l2PriceFeed.upgradeToAndCall(
            address(l2PriceFeedV4Implementation),
            abi.encodeWithSelector(l2PriceFeedV4Implementation.initializeV4.selector)
        );
        L2PriceFeedWithoutRoundsV4 l2PriceFeedV4 = L2PriceFeedWithoutRoundsV4(address(l2PriceFeed));

        // check getRoundData(1) returns correct values
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            l2PriceFeedV4.getRoundData(1);

        assertEq(roundId, 1);
        assertEq(answer, 100000000);
        assertEq(startedAt, block.timestamp);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 1);
    }

    function test_V4_GetRoundData_RevertsForInvalidRound() public {
        // deploy and upgrade to V4
        L2PriceFeedWithoutRoundsV4 l2PriceFeedV4Implementation = new L2PriceFeedWithoutRoundsV4();
        l2PriceFeed.upgradeToAndCall(
            address(l2PriceFeedV4Implementation),
            abi.encodeWithSelector(l2PriceFeedV4Implementation.initializeV4.selector)
        );
        L2PriceFeedWithoutRoundsV4 l2PriceFeedV4 = L2PriceFeedWithoutRoundsV4(address(l2PriceFeed));

        // check getRoundData(2) reverts
        vm.expectRevert();
        l2PriceFeedV4.getRoundData(2);
    }
}
