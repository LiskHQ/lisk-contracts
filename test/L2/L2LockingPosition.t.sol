// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test, console2 } from "forge-std/Test.sol";
import { L2LockingPosition, LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2Staking } from "src/L2/L2Staking.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";

contract L2LockingPositionHarness is L2LockingPosition {
    function exposedIsLockingPositionNull(LockingPosition memory position) public view returns (bool) {
        return isLockingPositionNull(position);
    }
}

contract L2LockingPositionTest is Test {
    L2Staking public l2Staking;
    L2Staking public l2StakingImplementation;
    L2VotingPower public l2VotingPower;
    L2VotingPower public l2VotingPowerImplementation;
    L2LockingPosition public l2LockingPosition;
    L2LockingPosition public l2LockingPositionImplementation;

    function setUp() public {
        // deploy L2Staking implementation contract
        l2StakingImplementation = new L2Staking();

        // deploy L2Staking contract via proxy
        l2Staking = L2Staking(address(new ERC1967Proxy(address(l2StakingImplementation), "")));

        assert(address(l2Staking) != address(0x0));

        // deploy L2VotingPower implementation contract
        l2VotingPowerImplementation = new L2VotingPower();

        // deploy L2VotingPower contract via proxy
        l2VotingPower = L2VotingPower(address(new ERC1967Proxy(address(l2VotingPowerImplementation), "")));

        assert(address(l2VotingPower) != address(0x0));

        // deploy L2LockingPosition implementation contract
        l2LockingPositionImplementation = new L2LockingPosition();

        // deploy L2LockingPosition contract via proxy
        l2LockingPosition = L2LockingPosition(address(new ERC1967Proxy(address(l2LockingPositionImplementation), "")));

        // initialize L2Staking contract
        l2Staking.initialize(address(0), address(l2LockingPosition), address(0));

        // initialize L2VotingPower contract
        l2VotingPower.initialize(address(l2LockingPosition));

        assertEq(l2VotingPower.lockingPositionAddress(), address(l2LockingPosition));

        // initialize L2LockingPosition contract
        l2LockingPosition.initialize(address(l2Staking), address(l2VotingPower));

        assertEq(l2LockingPosition.name(), "Lisk Locking Position");
        assertEq(l2LockingPosition.symbol(), "LLP");
        assertEq(l2LockingPosition.owner(), address(this));
        assertEq(l2LockingPosition.stakingContract(), address(l2Staking));
        assertEq(l2LockingPosition.powerVotingContract(), address(l2VotingPower));
        assertEq(l2LockingPosition.totalSupply(), 0);
    }

    function test_Initialize_ZeroStakingContractAddress() public {
        // deploy L2LockingPosition implementation contract
        l2LockingPositionImplementation = new L2LockingPosition();

        // deploy L2LockingPosition contract via proxy and initialize it at the same time
        vm.expectRevert("L2LockingPosition: Staking contract address is required");
        l2LockingPosition = L2LockingPosition(
            address(
                new ERC1967Proxy(
                    address(l2LockingPositionImplementation),
                    abi.encodeWithSelector(l2LockingPosition.initialize.selector, address(0x0), address(l2VotingPower))
                )
            )
        );
    }

    function test_Initialize_ZeroPowerVotingContractAddress() public {
        // deploy L2LockingPosition implementation contract
        l2LockingPositionImplementation = new L2LockingPosition();

        // deploy L2LockingPosition contract via proxy and initialize it at the same time
        vm.expectRevert("L2LockingPosition: Power Voting contract address is required");
        l2LockingPosition = L2LockingPosition(
            address(
                new ERC1967Proxy(
                    address(l2LockingPositionImplementation),
                    abi.encodeWithSelector(l2LockingPosition.initialize.selector, address(l2Staking), address(0x0))
                )
            )
        );
    }

    function test_IsLockingPositionNull() public {
        L2LockingPositionHarness l2LockingPositionHarness = new L2LockingPositionHarness();

        LockingPosition memory position;
        assert(l2LockingPositionHarness.exposedIsLockingPositionNull(position));

        position.creator = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);
        position.amount = 0;
        position.expDate = 0;
        position.pausedLockingDuration = 0;
        assert(!l2LockingPositionHarness.exposedIsLockingPositionNull(position));

        position.creator = address(0);
        position.amount = 100 * 10 ** 18;
        position.expDate = 0;
        position.pausedLockingDuration = 0;
        assert(!l2LockingPositionHarness.exposedIsLockingPositionNull(position));

        position.creator = address(0);
        position.amount = 0;
        position.expDate = 365;
        position.pausedLockingDuration = 0;
        assert(!l2LockingPositionHarness.exposedIsLockingPositionNull(position));

        position.creator = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);
        position.amount = 0;
        position.expDate = 0;
        position.pausedLockingDuration = 50;
        assert(!l2LockingPositionHarness.exposedIsLockingPositionNull(position));

        position.creator = address(0);
        position.amount = 0;
        position.expDate = 365;
        position.pausedLockingDuration = 50;
        assert(!l2LockingPositionHarness.exposedIsLockingPositionNull(position));

        position.creator = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);
        position.amount = 100 * 10 ** 18;
        position.expDate = 0;
        position.pausedLockingDuration = 50;
        assert(!l2LockingPositionHarness.exposedIsLockingPositionNull(position));

        position.creator = address(0);
        position.amount = 100 * 10 ** 18;
        position.expDate = 365;
        position.pausedLockingDuration = 0;
        assert(!l2LockingPositionHarness.exposedIsLockingPositionNull(position));

        position.creator = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);
        position.amount = 100 * 10 ** 18;
        position.expDate = 365;
        position.pausedLockingDuration = 50;
        assert(!l2LockingPositionHarness.exposedIsLockingPositionNull(position));
    }

    function test_CreateLockingPosition() public {
        address alice = address(0x1);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);

        vm.prank(address(l2Staking));
        uint256 positionId = l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        assertEq(positionId, 1);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        // create another locking position for alice

        vm.prank(address(l2Staking));
        positionId = l2LockingPosition.createLockingPosition(address(l2Staking), alice, 200 * 10 ** 18, 730);

        assertEq(positionId, 2);
        assertEq(l2LockingPosition.totalSupply(), 2);
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2LockingPosition.getLockingPosition(2).amount, 200 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(2).expDate, 730);
        assertEq(l2LockingPosition.getLockingPosition(2).pausedLockingDuration, 0);
    }

    function test_CreateLockingPosition_OwnerIsZero() public {
        address alice = address(0x0);
        vm.prank(address(l2Staking));
        vm.expectRevert("L2LockingPosition: owner address is required");
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);
    }

    function test_CreateLockingPosition_AmountIsZero() public {
        address alice = address(0x1);
        vm.prank(address(l2Staking));
        vm.expectRevert("L2LockingPosition: amount should be greater than 0");
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 0, 365);
    }

    function test_CreateLockingPosition_LockingDurationIsZero() public {
        address alice = address(0x1);
        vm.prank(address(l2Staking));
        vm.expectRevert("L2LockingPosition: locking duration should be greater than 0");
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 0);
    }

    function test_CreateLockingPosition_OnlyStakingCanCall() public {
        address alice = address(0x1);

        vm.prank(alice);
        vm.expectRevert("L2LockingPosition: only Staking contract can call this function");
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);
    }

    function test_ModifyLockingPosition() public {
        address alice = address(0x1);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        vm.prank(address(l2Staking));
        l2LockingPosition.modifyLockingPosition(1, 200 * 10 ** 18, 730, 50);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 200 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 730);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 50);
    }

    function test_ModifyLockingPosition_PositionDoesNotExist() public {
        vm.prank(address(l2Staking));
        vm.expectRevert("L2LockingPosition: locking position does not exist");
        l2LockingPosition.modifyLockingPosition(1, 200 * 10 ** 18, 730, 50);
    }

    function test_ModifyLockingPosition_OnlyStakingCanCall() public {
        address alice = address(0x1);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        vm.prank(alice);
        vm.expectRevert("L2LockingPosition: only Staking contract can call this function");
        l2LockingPosition.modifyLockingPosition(1, 200 * 10 ** 18, 730, 50);
    }

    function test_RemoveLockingPosition() public {
        address alice = address(0x1);
        address bob = address(0x2);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        vm.startPrank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 200 * 10 ** 18, 365);
        l2LockingPosition.createLockingPosition(address(l2Staking), bob, 300 * 10 ** 18, 365);
        l2LockingPosition.createLockingPosition(address(l2Staking), bob, 400 * 10 ** 18, 365);
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 500 * 10 ** 18, 365);
        vm.stopPrank();

        assertEq(l2LockingPosition.totalSupply(), 5);
        assertEq(l2LockingPosition.balanceOf(alice), 3);
        assertEq(l2LockingPosition.balanceOf(bob), 2);

        // remove the second locking position of alice; index = 1
        uint256 positionId = l2LockingPosition.tokenOfOwnerByIndex(alice, 1);
        vm.prank(address(l2Staking));
        l2LockingPosition.removeLockingPosition(positionId);

        assertEq(l2LockingPosition.totalSupply(), 4);
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2LockingPosition.balanceOf(bob), 2);

        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(alice, 0)).amount, 100 * 10 ** 18
        );
        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(alice, 1)).amount, 500 * 10 ** 18
        );
        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 0)).amount, 300 * 10 ** 18
        );
        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 1)).amount, 400 * 10 ** 18
        );
    }

    function test_RemoveLockingPosition_PositionDoesNotExist() public {
        vm.prank(address(l2Staking));
        vm.expectRevert("L2LockingPosition: locking position does not exist");
        l2LockingPosition.removeLockingPosition(1);
    }

    function test_RemoveLockingPosition_OnlyStakingCanCall() public {
        address alice = address(0x1);
        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        uint256 positionId = l2LockingPosition.tokenOfOwnerByIndex(alice, 0);
        vm.prank(alice);
        vm.expectRevert("L2LockingPosition: only Staking contract can call this function");
        l2LockingPosition.removeLockingPosition(positionId);
    }

    function test_GetLockingPosition_PositionDoesNotExist() public {
        LockingPosition memory position = l2LockingPosition.getLockingPosition(1);
        assertEq(position.creator, address(0));
        assertEq(position.amount, 0);
        assertEq(position.expDate, 0);
        assertEq(position.pausedLockingDuration, 0);
    }

    function test_TransferFrom() public {
        address alice = address(0x1);
        address bob = address(0x2);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        // transfer the first locking position of alice to bob
        uint256 positionId = l2LockingPosition.tokenOfOwnerByIndex(alice, 0);
        vm.prank(alice);
        l2LockingPosition.transferFrom(alice, bob, positionId);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 1);

        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 0)).amount, 100 * 10 ** 18
        );
        assertEq(l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 0)).expDate, 365);
        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 0)).pausedLockingDuration, 0
        );
    }

    function test_TransferFrom_Alowance() public {
        address alice = address(0x1);
        address bob = address(0x2);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        // approve bob to spend the first locking position of alice
        uint256 positionId = l2LockingPosition.tokenOfOwnerByIndex(alice, 0);
        vm.prank(alice);
        l2LockingPosition.approve(bob, positionId);

        // transfer the first locking position of alice to bob as bob
        vm.prank(bob);
        l2LockingPosition.transferFrom(alice, bob, positionId);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 1);

        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 0)).amount, 100 * 10 ** 18
        );
        assertEq(l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 0)).expDate, 365);
        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 0)).pausedLockingDuration, 0
        );
    }

    function test_TransferFrom_PositionDoesNotExist() public {
        address alice = address(0x1);
        address bob = address(0x2);
        vm.prank(alice);
        vm.expectRevert("L2LockingPosition: locking position does not exist");
        l2LockingPosition.transferFrom(alice, bob, 1);
    }

    function test_SafeTransferFrom() public {
        address alice = address(0x1);
        address bob = address(0x2);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        // transfer the first locking position of alice to bob
        uint256 positionId = l2LockingPosition.tokenOfOwnerByIndex(alice, 0);
        vm.prank(alice);
        l2LockingPosition.safeTransferFrom(alice, bob, positionId, "");

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 1);

        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 0)).amount, 100 * 10 ** 18
        );
        assertEq(l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 0)).expDate, 365);
        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 0)).pausedLockingDuration, 0
        );
    }

    function test_SafeTransferFrom_Alowance() public {
        address alice = address(0x1);
        address bob = address(0x2);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        // approve bob to spend the first locking position of alice
        uint256 positionId = l2LockingPosition.tokenOfOwnerByIndex(alice, 0);
        vm.prank(alice);
        l2LockingPosition.approve(bob, positionId);

        // transfer the first locking position of alice to bob as bob
        vm.prank(bob);
        l2LockingPosition.safeTransferFrom(alice, bob, positionId, "");

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 1);

        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 0)).amount, 100 * 10 ** 18
        );
        assertEq(l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 0)).expDate, 365);
        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 0)).pausedLockingDuration, 0
        );
    }

    function test_SafeTransferFrom_PositionDoesNotExist() public {
        address alice = address(0x1);
        address bob = address(0x2);
        vm.prank(alice);
        vm.expectRevert("L2LockingPosition: locking position does not exist");
        l2LockingPosition.safeTransferFrom(alice, bob, 1, "");
    }
}
