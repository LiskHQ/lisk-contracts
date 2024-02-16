// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test, console } from "forge-std/Test.sol";
import { L2VotingPower, LockingPosition } from "src/L2/L2VotingPower.sol";
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

    address stakingContractAddress;
    LockingPosition[] public positionBefore;
    LockingPosition[] public positionAfter;

    function setUp() public {
        utils = new Utils();

        // set initial values
        stakingContractAddress = address(0xdeadbeefdeadbeefdeadbeef);

        console.log("L2VotingPowerTest address is: %s", address(this));

        // deploy L2VotingPower Implementation contract
        l2VotingPowerImplementation = new L2VotingPower();

        // deploy L2VotingPower contract via proxy and initialize it at the same time
        l2VotingPower = L2VotingPower(
            address(
                new ERC1967Proxy(
                    address(l2VotingPowerImplementation),
                    abi.encodeWithSelector(l2VotingPower.initialize.selector, stakingContractAddress)
                )
            )
        );

        assertEq(l2VotingPower.stakingContractAddress(), stakingContractAddress);
        assertEq(l2VotingPower.version(), "1.0.0");
        assertEq(l2VotingPower.name(), "Lisk Voting Power");
        assertEq(l2VotingPower.symbol(), "vpLSK");
    }

    function test_Version() public {
        assertEq(l2VotingPower.version(), "1.0.0");
    }

    function test_VotingPower() public {
        L2VotingPowerHarness l2VotingPowerHarness = new L2VotingPowerHarness();

        LockingPosition memory position = LockingPosition(50, 50, 50);
        assertEq(l2VotingPowerHarness.exposedVotingPower(position), 2500);
    }

    function test_VotingPower_ZeroExpDate() public {
        L2VotingPowerHarness l2VotingPowerHarness = new L2VotingPowerHarness();

        LockingPosition memory position = LockingPosition(50, 50, 0);
        assertEq(l2VotingPowerHarness.exposedVotingPower(position), 10000);
    }

    function test_AdjustVotingPower_EventsAreEmitted() public {
        positionBefore.push(LockingPosition(50, 50, 50));
        positionAfter.push(LockingPosition(100, 100, 100));

        // check that events for mint and burn are emitted
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), address(this), 6250);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(this), address(0), 2500);

        // call it as staking contract
        vm.prank(stakingContractAddress);
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);
    }

    function test_AdjustVotingPower_NotStakingContract() public {
        positionBefore.push(LockingPosition(50, 50, 50));
        positionAfter.push(LockingPosition(100, 100, 100));

        // call it as non-staking contract
        vm.expectRevert("L2VotingPower: only staking contract can call this function");
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);
    }

    function test_AdjustVotingPower_PositionBeforeLength() public {
        positionBefore.push(LockingPosition(50, 50, 50));
        positionBefore.push(LockingPosition(50, 50, 50));
        positionAfter.push(LockingPosition(100, 100, 100));

        // call it as staking contract
        vm.prank(stakingContractAddress);
        vm.expectRevert("L2VotingPower: invalid positionBefore length");
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);
    }

    function test_AdjustVotingPower_PositionAfterLength() public {
        positionBefore.push(LockingPosition(50, 50, 50));
        positionAfter.push(LockingPosition(100, 100, 100));
        positionAfter.push(LockingPosition(100, 100, 100));

        // call it as staking contract
        vm.prank(stakingContractAddress);
        vm.expectRevert("L2VotingPower: invalid positionAfter length");
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);
    }

    function test_AdjustVotingPower_PositionBeforeIsNull() public {
        positionAfter.push(LockingPosition(100, 100, 100));

        // check that event for mint is emitted
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), address(this), 6250);

        // call it as staking contract
        vm.prank(stakingContractAddress);
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);
    }

    function test_AdjustVotingPower_PositionAfterIsNull() public {
        // mint some tokens that then can be burned
        positionAfter.push(LockingPosition(500, 500, 500));
        vm.prank(stakingContractAddress);
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);

        // clear positionAfter array
        positionAfter.pop();
        assertEq(positionAfter.length, 0);
        assertEq(positionBefore.length, 0);

        // only positionBefore is set
        positionBefore.push(LockingPosition(50, 50, 50));

        // check that event for burn is emitted
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(this), address(0), 2500);

        // call it as staking contract
        vm.prank(stakingContractAddress);
        l2VotingPower.adjustVotingPower(address(this), positionBefore, positionAfter);
    }

    function test_Clock() public {
        assertEq(l2VotingPower.clock(), vm.getBlockNumber());

        // increase block number
        uint256 blockNumber = vm.getBlockNumber();
        vm.roll(blockNumber);
        assertEq(l2VotingPower.clock(), blockNumber);
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
