// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC721Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Test, console2 } from "forge-std/Test.sol";
import { L2LockingPosition, LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2Staking } from "src/L2/L2Staking.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";

contract L2LockingPositionV2 is L2VotingPower {
    uint256 public testNumber;

    function initializeV2(uint256 _testNumber) public reinitializer(2) {
        testNumber = _testNumber;
    }

    function onlyV2() public pure returns (string memory) {
        return "Only L2LockingPositionV2 have this function";
    }
}

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

        // deploy L2Staking contract via proxy and initialize it at the same time
        l2Staking = L2Staking(
            address(
                new ERC1967Proxy(
                    address(l2StakingImplementation),
                    abi.encodeWithSelector(
                        l2Staking.initialize.selector, address(0xbABEBABEBabeBAbEBaBeBabeBABEBabEBAbeBAbe)
                    )
                )
            )
        );
        assert(address(l2Staking) != address(0x0));

        // deploy L2LockingPosition implementation contract
        l2LockingPositionImplementation = new L2LockingPosition();

        // check that the StakingContractAddressChanged event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2LockingPosition.StakingContractAddressChanged(address(0), address(l2Staking));

        // deploy L2LockingPosition contract via proxy and initialize it at the same time
        l2LockingPosition = L2LockingPosition(
            address(
                new ERC1967Proxy(
                    address(l2LockingPositionImplementation),
                    abi.encodeWithSelector(l2LockingPosition.initialize.selector, address(l2Staking))
                )
            )
        );
        assert(address(l2LockingPosition) != address(0x0));

        // deploy L2VotingPower implementation contract
        l2VotingPowerImplementation = new L2VotingPower();

        // deploy L2VotingPower contract via proxy and initialize it at the same time
        l2VotingPower = L2VotingPower(
            address(
                new ERC1967Proxy(
                    address(l2VotingPowerImplementation),
                    abi.encodeWithSelector(l2VotingPower.initialize.selector, address(l2LockingPosition))
                )
            )
        );
        assert(address(l2VotingPower) != address(0x0));
        assert(l2VotingPower.lockingPositionAddress() == address(l2LockingPosition));

        // initialize LockingPosition contract inside L2Staking contract
        l2Staking.initializeLockingPosition(address(l2LockingPosition));
        assert(l2Staking.lockingPositionContract() == address(l2LockingPosition));

        // initialize Lisk DAO Treasury contract inside L2Staking contract
        l2Staking.initializeDaoTreasury(address(0xbABEBABEBabeBAbEBaBeBabeBABEBabEBAbeBAbe));
        assert(l2Staking.daoTreasury() == address(0xbABEBABEBabeBAbEBaBeBabeBABEBabEBAbeBAbe));

        // initialize VotingPower contract inside L2LockingPosition contract
        l2LockingPosition.initializeVotingPower(address(l2VotingPower));
        assert(l2LockingPosition.votingPowerContract() == address(l2VotingPower));

        assertEq(l2LockingPosition.name(), "Lisk Locking Position");
        assertEq(l2LockingPosition.symbol(), "LLP");
        assertEq(l2LockingPosition.owner(), address(this));
        assertEq(l2LockingPosition.stakingContract(), address(l2Staking));
        assertEq(l2LockingPosition.votingPowerContract(), address(l2VotingPower));
        assertEq(l2LockingPosition.totalSupply(), 0);
    }

    function test_Initialize_ZeroStakingContractAddress() public {
        // deploy L2LockingPosition implementation contract
        l2LockingPositionImplementation = new L2LockingPosition();

        // deploy L2LockingPosition contract via proxy and initialize it at the same time
        vm.expectRevert("L2LockingPosition: Staking contract address cannot be zero");
        l2LockingPosition = L2LockingPosition(
            address(
                new ERC1967Proxy(
                    address(l2LockingPositionImplementation),
                    abi.encodeWithSelector(l2LockingPosition.initialize.selector, address(0x0))
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

        position.creator = address(0);
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

    function test_InitializeVotingPower_VotingPowerContractAlreadyInitialized() public {
        vm.expectRevert("L2LockingPosition: Voting Power contract is already initialized");
        l2LockingPosition.initializeVotingPower(address(l2VotingPower));
    }

    function test_InitializeVotingPower_ZeroVotingPowerContractAddress() public {
        // deploy L2LockingPosition implementation contract
        l2LockingPositionImplementation = new L2LockingPosition();

        // deploy L2LockingPosition contract via proxy and initialize it at the same time
        l2LockingPosition = L2LockingPosition(
            address(
                new ERC1967Proxy(
                    address(l2LockingPositionImplementation),
                    abi.encodeWithSelector(l2LockingPosition.initialize.selector, address(l2Staking))
                )
            )
        );

        vm.expectRevert("L2LockingPosition: Voting Power contract address can not be zero");
        l2LockingPosition.initializeVotingPower(address(0x0));
    }

    function test_InitializeVotingPower_OnlyOwnerCanCall() public {
        address nobody = vm.addr(100);
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2LockingPosition.initializeVotingPower(address(l2VotingPower));
    }

    function test_CreateLockingPosition() public {
        address alice = address(0x1);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2VotingPower.totalSupply(), 0);
        assertEq(l2VotingPower.balanceOf(alice), 0);

        vm.prank(address(l2Staking));
        uint256 positionId = l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        assertEq(positionId, 1);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // create another locking position for alice

        vm.prank(address(l2Staking));
        positionId = l2LockingPosition.createLockingPosition(address(l2Staking), alice, 200 * 10 ** 18, 730);

        assertEq(positionId, 2);
        assertEq(l2LockingPosition.totalSupply(), 2);
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2LockingPosition.getLockingPosition(2).amount, 200 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(2).expDate, 730);
        assertEq(l2LockingPosition.getLockingPosition(2).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 300 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 300 * 10 ** 18);
    }

    function test_CreateLockingPosition_OwnerIsZero() public {
        address alice = address(0x0);
        vm.prank(address(l2Staking));
        vm.expectRevert("L2LockingPosition: lockOwner address is required");
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

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        vm.prank(address(l2Staking));
        l2LockingPosition.modifyLockingPosition(1, 200 * 10 ** 18, 730, 50);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 200 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 730);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 50);

        assertEq(l2VotingPower.totalSupply(), 227397260273972602739);
        assertEq(l2VotingPower.balanceOf(alice), 227397260273972602739);
    }

    function test_ModifyLockingPosition_AmountIsZero() public {
        address alice = address(0x1);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);

        vm.prank(address(l2Staking));
        vm.expectRevert("L2LockingPosition: amount should be greater than 0");
        l2LockingPosition.modifyLockingPosition(1, 0, 730, 50);
    }

    function test_ModifyLockingPosition_ExpDateShouldBeGreaterThanCurrentDate() public {
        address alice = address(0x1);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 100);
        assertEq(l2LockingPosition.balanceOf(alice), 1);

        // advance block time by 50 days
        vm.warp(50 days);

        // expDate is less than current date (49 days) and pausedLockingDuration is 0
        vm.prank(address(l2Staking));
        vm.expectRevert(
            "L2LockingPosition: expDate should be greater than or equal to today or pausedLockingDuration > 0"
        );
        l2LockingPosition.modifyLockingPosition(1, 200 * 10 ** 18, 49, 0);
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
        assertEq(l2VotingPower.totalSupply(), 0);
        assertEq(l2VotingPower.balanceOf(alice), 0);
        assertEq(l2VotingPower.balanceOf(bob), 0);

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

        assertEq(l2VotingPower.totalSupply(), 1500 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 800 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(bob), 700 * 10 ** 18);

        // remove the second locking position of alice; index = 1
        uint256 positionId = l2LockingPosition.tokenOfOwnerByIndex(alice, 1);
        vm.prank(address(l2Staking));
        l2LockingPosition.removeLockingPosition(positionId);

        assertEq(l2LockingPosition.totalSupply(), 4);
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2LockingPosition.balanceOf(bob), 2);

        assertEq(l2VotingPower.totalSupply(), 1300 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 600 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(bob), 700 * 10 ** 18);

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

    function test_GetAllLockingPositionsByOwner() public {
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

        LockingPosition[] memory positions = l2LockingPosition.getAllLockingPositionsByOwner(alice);
        assertEq(positions.length, 3);
        assertEq(positions[0].amount, 100 * 10 ** 18);
        assertEq(positions[1].amount, 200 * 10 ** 18);
        assertEq(positions[2].amount, 500 * 10 ** 18);

        positions = l2LockingPosition.getAllLockingPositionsByOwner(bob);
        assertEq(positions.length, 2);
        assertEq(positions[0].amount, 300 * 10 ** 18);
        assertEq(positions[1].amount, 400 * 10 ** 18);
    }

    function test_GetAllLockingPositionsByOwner_NoLockingPositions() public {
        address alice = address(0x1);
        address bob = address(0x2);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        vm.startPrank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), bob, 100 * 10 ** 18, 365);
        l2LockingPosition.createLockingPosition(address(l2Staking), bob, 200 * 10 ** 18, 365);
        l2LockingPosition.createLockingPosition(address(l2Staking), bob, 300 * 10 ** 18, 365);
        l2LockingPosition.createLockingPosition(address(l2Staking), bob, 400 * 10 ** 18, 365);
        l2LockingPosition.createLockingPosition(address(l2Staking), bob, 500 * 10 ** 18, 365);
        vm.stopPrank();

        LockingPosition[] memory positions = l2LockingPosition.getAllLockingPositionsByOwner(alice);
        assertEq(positions.length, 0);

        positions = l2LockingPosition.getAllLockingPositionsByOwner(bob);
        assertEq(positions.length, 5);
    }

    function test_TransferFrom() public {
        address alice = address(0x1);
        address bob = address(0x2);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 0);
        assertEq(l2VotingPower.totalSupply(), 0);
        assertEq(l2VotingPower.balanceOf(alice), 0);
        assertEq(l2VotingPower.balanceOf(bob), 0);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(bob), 0);

        // transfer the first locking position of alice to bob
        uint256 positionId = l2LockingPosition.tokenOfOwnerByIndex(alice, 0);
        vm.prank(alice);
        l2LockingPosition.transferFrom(alice, bob, positionId);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 1);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 0);
        assertEq(l2VotingPower.balanceOf(bob), 100 * 10 ** 18);

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
        assertEq(l2VotingPower.totalSupply(), 0);
        assertEq(l2VotingPower.balanceOf(alice), 0);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(bob), 0);

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

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 0);
        assertEq(l2VotingPower.balanceOf(bob), 100 * 10 ** 18);

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

    function test_TransferFrom_NotOwnerOfPosition() public {
        address alice = address(0x1);
        address bob = address(0x2);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 0);
        assertEq(l2VotingPower.totalSupply(), 0);
        assertEq(l2VotingPower.balanceOf(alice), 0);
        assertEq(l2VotingPower.balanceOf(bob), 0);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(bob), 0);

        // bob would like to transfer the locking position of alice to himself but he is not the owner of the position
        uint256 positionId = l2LockingPosition.tokenOfOwnerByIndex(alice, 0);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, bob, 1));
        l2LockingPosition.transferFrom(alice, bob, positionId);
    }

    function test_SafeTransferFrom() public {
        address alice = address(0x1);
        address bob = address(0x2);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 0);
        assertEq(l2VotingPower.totalSupply(), 0);
        assertEq(l2VotingPower.balanceOf(alice), 0);
        assertEq(l2VotingPower.balanceOf(bob), 0);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(bob), 0);

        // transfer the first locking position of alice to bob
        uint256 positionId = l2LockingPosition.tokenOfOwnerByIndex(alice, 0);
        vm.prank(alice);
        l2LockingPosition.safeTransferFrom(alice, bob, positionId, "");

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 1);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 0);
        assertEq(l2VotingPower.balanceOf(bob), 100 * 10 ** 18);

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
        assertEq(l2VotingPower.totalSupply(), 0);
        assertEq(l2VotingPower.balanceOf(alice), 0);
        assertEq(l2VotingPower.balanceOf(bob), 0);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(bob), 0);

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

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 0);
        assertEq(l2VotingPower.balanceOf(bob), 100 * 10 ** 18);

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

    function test_SafeTransferFrom_NotOwnerOfPosition() public {
        address alice = address(0x1);
        address bob = address(0x2);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 0);
        assertEq(l2VotingPower.totalSupply(), 0);
        assertEq(l2VotingPower.balanceOf(alice), 0);
        assertEq(l2VotingPower.balanceOf(bob), 0);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(address(l2Staking), alice, 100 * 10 ** 18, 365);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(bob), 0);

        // bob would like to transfer the locking position of alice to himself but he is not the owner of the position
        uint256 positionId = l2LockingPosition.tokenOfOwnerByIndex(alice, 0);
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InsufficientApproval.selector, bob, 1));
        l2LockingPosition.safeTransferFrom(alice, bob, positionId);
    }

    function test_TransferOwnership() public {
        address newOwner = vm.addr(100);

        l2LockingPosition.transferOwnership(newOwner);
        assertEq(l2LockingPosition.owner(), address(this));

        vm.prank(newOwner);
        l2LockingPosition.acceptOwnership();
        assertEq(l2LockingPosition.owner(), newOwner);
    }

    function test_TransferOwnership_RevertWhenNotCalledByPendingOwner() public {
        address newOwner = vm.addr(100);

        l2LockingPosition.transferOwnership(newOwner);
        assertEq(l2LockingPosition.owner(), address(this));

        address nobody = vm.addr(200);
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2LockingPosition.acceptOwnership();
    }

    function test_UpgradeToAndCall_RevertWhenNotOwner() public {
        // deploy L2LockingPositionV2 implementation contract
        L2LockingPositionV2 l2LockingPositionV2Implementation = new L2LockingPositionV2();
        address nobody = vm.addr(1);

        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2LockingPosition.upgradeToAndCall(address(l2LockingPositionV2Implementation), "");
    }

    function test_UpgradeToAndCall_SuccessUpgrade() public {
        // deploy L2LockingPositionV2 implementation contract
        L2LockingPositionV2 l2LockingPositionV2Implementation = new L2LockingPositionV2();

        uint256 testNumber = 123;

        // upgrade contract, and also change some variables by reinitialize
        l2LockingPosition.upgradeToAndCall(
            address(l2LockingPositionV2Implementation),
            abi.encodeWithSelector(l2LockingPositionV2Implementation.initializeV2.selector, testNumber)
        );

        // wrap L2LockingPositionV2 proxy with new contract
        L2LockingPositionV2 l2LockingPositionV2 = L2LockingPositionV2(payable(address(l2LockingPosition)));

        // new testNumber variable introduced
        assertEq(l2LockingPositionV2.testNumber(), testNumber);

        // new function introduced
        assertEq(l2LockingPositionV2.onlyV2(), "Only L2LockingPositionV2 have this function");

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2LockingPositionV2.initializeV2(testNumber + 1);
    }
}
