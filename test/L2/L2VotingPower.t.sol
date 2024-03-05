// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test, console } from "forge-std/Test.sol";
import { LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";
import { Utils } from "script/Utils.sol";

contract L2VotingPowerV2 is L2VotingPower {
    uint256 public testNumber;

    function initializeV2(uint256 _testNumber) public reinitializer(2) {
        testNumber = _testNumber;
    }

    function onlyV2() public pure returns (string memory) {
        return "Only L2VotingPowerV2 have this function";
    }
}

contract L2VotingPowerHarness is L2VotingPower {
    function exposedVotingPower(LockingPosition memory position) external pure returns (uint256) {
        return votingPower(position);
    }
}

contract L2VotingPowerTest is Test {
    Utils public utils;
    L2VotingPower public l2VotingPowerImplementation;
    L2VotingPower public l2VotingPower;

    address lockingPositionContractAddress;

    function setUp() public {
        utils = new Utils();

        // set initial values
        lockingPositionContractAddress = address(0xdeadbeefdeadbeefdeadbeef);

        console.log("L2VotingPowerTest address is: %s", address(this));

        // deploy L2VotingPower Implementation contract
        l2VotingPowerImplementation = new L2VotingPower();

        // deploy L2VotingPower contract via proxy and initialize it at the same time
        l2VotingPower = L2VotingPower(
            address(
                new ERC1967Proxy(
                    address(l2VotingPowerImplementation),
                    abi.encodeWithSelector(l2VotingPower.initialize.selector, lockingPositionContractAddress)
                )
            )
        );

        assertEq(l2VotingPower.lockingPositionAddress(), lockingPositionContractAddress);
        assertEq(l2VotingPower.version(), "1.0.0");
        assertEq(l2VotingPower.name(), "Lisk Voting Power");
        assertEq(l2VotingPower.symbol(), "vpLSK");
    }

    function test_Initialize_ZerolockingPositionContractAddress() public {
        // deploy L2VotingPower Implementation contract
        l2VotingPowerImplementation = new L2VotingPower();

        // deploy L2VotingPower contract via proxy and initialize it with zero LockingPosition contract address
        vm.expectRevert("L2VotingPower: LockingPosition contract address cannot be 0");
        l2VotingPower = L2VotingPower(
            address(
                new ERC1967Proxy(
                    address(l2VotingPowerImplementation),
                    abi.encodeWithSelector(l2VotingPower.initialize.selector, address(0))
                )
            )
        );
    }

    function test_Initialize_EventlockingPositionContractAddressChangedEmitted() public {
        // deploy L2VotingPower Implementation contract
        l2VotingPowerImplementation = new L2VotingPower();

        // check that event for LockingPosition contract address change is emitted
        vm.expectEmit(true, true, true, true);
        emit L2VotingPower.LockingPositionContractAddressChanged(address(0), lockingPositionContractAddress);

        // deploy L2VotingPower contract via proxy and initialize it with new LockingPosition contract address
        l2VotingPower = L2VotingPower(
            address(
                new ERC1967Proxy(
                    address(l2VotingPowerImplementation),
                    abi.encodeWithSelector(l2VotingPower.initialize.selector, lockingPositionContractAddress)
                )
            )
        );
    }

    function test_Version() public {
        assertEq(l2VotingPower.version(), "1.0.0");
    }

    function test_VotingPower() public {
        L2VotingPowerHarness l2VotingPowerHarness = new L2VotingPowerHarness();

        LockingPosition memory position = LockingPosition(address(this), 50, 0, 0);
        assertEq(l2VotingPowerHarness.exposedVotingPower(position), 50);
    }

    function test_VotingPower_PausedLockingDurationHigherThanZero() public {
        L2VotingPowerHarness l2VotingPowerHarness = new L2VotingPowerHarness();

        LockingPosition memory position = LockingPosition(address(this), 100, 0, 50);
        assertEq(l2VotingPowerHarness.exposedVotingPower(position), 113);
    }

    function test_AdjustVotingPower_DiffLargerThanZero() public {
        // difference between positionBefore and positionAfter is larger than 0
        LockingPosition memory positionBefore = LockingPosition(address(this), 50, 0, 0);
        LockingPosition memory positionAfter = LockingPosition(address(this), 200, 0, 0);

        // check that event for mint is emitted
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), address(this), 150);

        // call it as LockingPosition contract
        vm.prank(lockingPositionContractAddress);
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);
    }

    function test_AdjustVotingPower_DiffLessThanZero() public {
        // mint some tokens that then can be burned
        LockingPosition memory positionBefore = LockingPosition(address(this), 0, 0, 0);
        LockingPosition memory positionAfter = LockingPosition(address(this), 500, 0, 0);
        vm.prank(lockingPositionContractAddress);
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);

        // difference between positionBefore and positionAfter is less than 0
        positionBefore = LockingPosition(address(this), 250, 0, 0);
        positionAfter = LockingPosition(address(this), 100, 0, 0);

        // check that event for burn is emitted
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(this), address(0), 150);

        // call it as LockingPosition contract
        vm.prank(lockingPositionContractAddress);
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);
    }

    function test_AdjustVotingPower_TooLittleVotingPower() public {
        // decrease more tokens than available
        LockingPosition memory positionBefore = LockingPosition(address(this), 110, 0, 0);
        LockingPosition memory positionAfter = LockingPosition(address(this), 100, 0, 0);

        // call it as LockingPosition contract
        vm.prank(lockingPositionContractAddress);
        // revert with insufficient balance
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, address(this), 0, 10));
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);
    }

    function test_AdjustVotingPower_NotLockingPositionContract() public {
        LockingPosition memory positionBefore = LockingPosition(address(this), 50, 50, 50);
        LockingPosition memory positionAfter = LockingPosition(address(this), 100, 100, 100);

        // call it as non-LockingPosition contract
        vm.expectRevert("L2VotingPower: only LockingPosition contract can call this function");
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);
    }

    function test_AdjustVotingPower_PositionBeforeIsNull() public {
        LockingPosition memory positionBefore = LockingPosition(address(this), 0, 0, 0);
        LockingPosition memory positionAfter = LockingPosition(address(this), 100, 0, 0);

        // check that event for mint is emitted
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), address(this), 100);

        // call it as LockingPosition contract
        vm.prank(lockingPositionContractAddress);
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);
    }

    function test_AdjustVotingPower_PositionAfterIsNull() public {
        // mint some tokens that then can be burned
        LockingPosition memory positionBefore = LockingPosition(address(this), 0, 0, 0);
        LockingPosition memory positionAfter = LockingPosition(address(this), 500, 0, 0);
        vm.prank(lockingPositionContractAddress);
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);

        // only positionBefore is set
        positionBefore = LockingPosition(address(this), 50, 0, 0);
        positionAfter = LockingPosition(address(this), 0, 0, 0);

        // check that event for burn is emitted
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(this), address(0), 50);

        // call it as LockingPosition contract
        vm.prank(lockingPositionContractAddress);
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);
    }

    function test_AdjustVotingPower_EventDelegateVotesChangedEmitted() public {
        address alice = vm.addr(1);
        address bob = vm.addr(2);

        // expect DelegateChanged event to be emitted when alice delegates to bob
        vm.expectEmit(true, true, true, true);
        emit IVotes.DelegateChanged(alice, address(0), bob);

        // call it as alice to delegate her votes to bob
        vm.prank(alice);
        l2VotingPower.delegate(bob);

        LockingPosition memory positionBefore = LockingPosition(address(this), 0, 0, 0);
        LockingPosition memory positionAfter = LockingPosition(address(this), 50, 0, 0);

        // expect event DelegateVotesChanged to be emitted
        vm.expectEmit(true, true, true, true);
        emit IVotes.DelegateVotesChanged(bob, 0, 50);

        // call it as LockingPosition contract
        vm.prank(lockingPositionContractAddress);
        l2VotingPower.adjustVotingPower(alice, positionBefore, positionAfter);

        // alice delegates some more votes to bob
        positionBefore = LockingPosition(address(this), 50, 0, 0);
        positionAfter = LockingPosition(address(this), 200, 0, 0);

        // expect event DelegateVotesChanged to be emitted
        vm.expectEmit(true, true, true, true);
        emit IVotes.DelegateVotesChanged(bob, 50, 200);

        // call it as LockingPosition contract
        vm.prank(lockingPositionContractAddress);
        l2VotingPower.adjustVotingPower(alice, positionBefore, positionAfter);
    }

    function test_AdjustVotingPower_GetPastVotes() public {
        address alice = vm.addr(1);
        address bob = vm.addr(2);

        // call it as alice to delegate her votes to bob
        vm.prank(alice);
        l2VotingPower.delegate(bob);

        LockingPosition memory positionBefore = LockingPosition(address(this), 0, 0, 0);
        LockingPosition memory positionAfter = LockingPosition(address(this), 50, 0, 0);

        // call it as LockingPosition contract
        vm.prank(lockingPositionContractAddress);
        l2VotingPower.adjustVotingPower(alice, positionBefore, positionAfter);

        // increase block timestamp
        uint256 blockTimestamp = vm.getBlockTimestamp();
        vm.warp(blockTimestamp + 10);

        // check past votes for bob for interval [blockTimestamp, blockTimestamp + 10)
        for (uint256 i = 0; i < 10; i++) {
            assertEq(l2VotingPower.getPastVotes(bob, blockTimestamp + i), 50);
        }

        // increase block timestamp
        vm.warp(blockTimestamp + 20);

        // decrease voting power of alice for 10
        positionBefore = LockingPosition(address(this), 50, 0, 0);
        positionAfter = LockingPosition(address(this), 40, 0, 0);

        // call it as LockingPosition contract
        vm.prank(lockingPositionContractAddress);
        l2VotingPower.adjustVotingPower(alice, positionBefore, positionAfter);

        // increase block timestamp
        vm.warp(blockTimestamp + 30);

        // check past votes for bob for interval [blockTimestamp + 20, blockTimestamp + 30)
        for (uint256 i = 20; i < 30; i++) {
            assertEq(l2VotingPower.getPastVotes(bob, blockTimestamp + i), 40);
        }

        // check that past votes for bob for interval [blockTimestamp, blockTimestamp + 20) still returns 50
        for (uint256 i = 0; i < 20; i++) {
            assertEq(l2VotingPower.getPastVotes(bob, blockTimestamp + i), 50);
        }
    }

    function test_Clock() public {
        uint256 blockTimestamp = vm.getBlockTimestamp();
        assertEq(l2VotingPower.clock(), blockTimestamp);

        // increase block timestamp
        vm.warp(blockTimestamp + 1);

        assertEq(l2VotingPower.clock(), blockTimestamp + 1);
    }

    function test_ClockMode() public {
        assertEq(l2VotingPower.CLOCK_MODE(), "mode=timestamp");
    }

    function test_ErrorEventsEmitted() public {
        // approve
        vm.expectRevert(abi.encodeWithSelector(L2VotingPower.ApproveDisabled.selector));
        l2VotingPower.approve(vm.addr(1), 100);

        // transfer
        vm.expectRevert(abi.encodeWithSelector(L2VotingPower.TransferDisabled.selector));
        l2VotingPower.transfer(vm.addr(1), 100);

        // transferFrom
        vm.expectRevert(abi.encodeWithSelector(L2VotingPower.TransferDisabled.selector));
        l2VotingPower.transferFrom(vm.addr(1), vm.addr(2), 100);
    }

    function test_TransferOwnership() public {
        address newOwner = vm.addr(1);

        l2VotingPower.transferOwnership(newOwner);
        assertEq(l2VotingPower.owner(), address(this));

        vm.prank(newOwner);
        l2VotingPower.acceptOwnership();
        assertEq(l2VotingPower.owner(), newOwner);
    }

    function test_TransferOwnership_RevertWhenNotCalledByOwner() public {
        address newOwner = vm.addr(1);
        address nobody = vm.addr(2);

        // owner is this contract
        assertEq(l2VotingPower.owner(), address(this));

        // address nobody is not the owner so it cannot call transferOwnership
        vm.startPrank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2VotingPower.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function test_TransferOwnership_RevertWhenNotCalledByPendingOwner() public {
        address newOwner = vm.addr(1);

        l2VotingPower.transferOwnership(newOwner);
        assertEq(l2VotingPower.owner(), address(this));

        address nobody = vm.addr(2);
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2VotingPower.acceptOwnership();
    }

    function test_UpgradeToAndCall_RevertWhenNotOwner() public {
        // deploy L2VotingPowerV2 implementation contract
        L2VotingPowerV2 l2VotingPowerV2Implementation = new L2VotingPowerV2();
        address nobody = vm.addr(1);

        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2VotingPower.upgradeToAndCall(address(l2VotingPowerV2Implementation), "");
    }

    function test_UpgradeToAndCall_SuccessUpgrade() public {
        // deploy L2VotingPowerV2 implementation contract
        L2VotingPowerV2 l2VotingPowerV2Implementation = new L2VotingPowerV2();

        uint256 testNumber = 123;

        // upgrade contract, and also change some variables by reinitialize
        l2VotingPower.upgradeToAndCall(
            address(l2VotingPowerV2Implementation),
            abi.encodeWithSelector(l2VotingPowerV2Implementation.initializeV2.selector, testNumber)
        );

        // wrap L2VotingPower proxy with new contract
        L2VotingPowerV2 l2VotingPowerV2 = L2VotingPowerV2(payable(address(l2VotingPower)));

        // new testNumber variable introduced
        assertEq(l2VotingPowerV2.testNumber(), testNumber);

        // new function introduced
        assertEq(l2VotingPowerV2.onlyV2(), "Only L2VotingPowerV2 have this function");

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2VotingPowerV2.initializeV2(testNumber + 1);
    }
}
