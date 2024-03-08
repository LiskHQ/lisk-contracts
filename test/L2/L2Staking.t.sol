// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Test, console2 } from "forge-std/Test.sol";
import { L2LockingPosition, LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { L2Staking } from "src/L2/L2Staking.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";

contract L2StakingHarness is L2Staking {
    function exposedCalculatePenalty(uint256 amount, uint256 expDate) public view returns (uint256) {
        return calculatePenalty(amount, expDate);
    }
}

contract L2StakingTest is Test {
    L2LiskToken public l2LiskToken;
    address public remoteToken;
    address public bridge;
    L2Staking public l2Staking;
    L2Staking public l2StakingImplementation;
    L2VotingPower public l2VotingPower;
    L2VotingPower public l2VotingPowerImplementation;
    L2LockingPosition public l2LockingPosition;
    L2LockingPosition public l2LockingPositionImplementation;

    address daoContractAddress;

    address rewardsContract;
    address alice;

    function setUp() public {
        daoContractAddress = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);

        rewardsContract = address(0x1);
        alice = address(0x2);

        bridge = vm.addr(uint256(bytes32("bridge")));
        remoteToken = vm.addr(uint256(bytes32("remoteToken")));

        // deploy L2LiskToken contract
        // msg.sender and tx.origin needs to be the same for the contract to be able to call initialize()
        vm.prank(address(this), address(this));
        l2LiskToken = new L2LiskToken(remoteToken);
        l2LiskToken.initialize(bridge);
        vm.stopPrank();

        assert(address(l2LiskToken) != address(0x0));

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

        assert(address(l2LockingPosition) != address(0x0));

        // initialize L2Staking contract
        l2Staking.initialize(address(l2LiskToken), address(l2LockingPosition), daoContractAddress);

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

        // add rewardsContract to the creator list
        l2Staking.addCreator(rewardsContract);
        assert(l2Staking.allowedCreators(rewardsContract));

        // fund alice with 100 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(alice, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);

        // approve L2Staking to spend alice's 100 L2LiskToken
        vm.prank(alice);
        l2LiskToken.approve(address(l2Staking), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(alice, address(l2Staking)), 100 * 10 ** 18);
    }

    function test_CalculatePenalty() public {
        L2StakingHarness l2StakingHarness = new L2StakingHarness();

        // penalty in the first day
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, 365), 25000000000000000000);

        // advance block time by 50 days
        vm.warp(50 days);
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, 365), 21575342465753424657);

        // advance block time by another 50 days
        vm.warp(100 days);
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, 365), 18150684931506849315);

        // advance block time by another 50 days
        vm.warp(150 days);
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, 365), 14726027397260273972);

        // advance block time by another 50 days
        vm.warp(200 days);
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, 365), 11301369863013698630);

        // advance block time by another 50 days
        vm.warp(250 days);
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, 365), 7876712328767123287);

        // advance block time by another 50 days
        vm.warp(300 days);
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, 365), 4452054794520547945);

        // advance block time by another 50 days
        vm.warp(350 days);
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, 365), 1027397260273972602);

        // advance block time to exactly one day before the expiration date
        vm.warp(364 days);
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, 365), 68493150684931506);

        // advance block time to exactly the expiration date
        vm.warp(365 days);
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, 365), 0);

        // advance block time to exactly one day after the expiration date
        vm.warp(366 days);
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, 365), 0);
    }

    function test_AddCreator() public {
        l2Staking.addCreator(alice);
        assert(l2Staking.allowedCreators(alice));
    }

    function test_AddCreator_OnlyOwnerCanCall() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        l2Staking.addCreator(alice);
    }

    function test_RemoveCreator() public {
        l2Staking.addCreator(alice);
        assert(l2Staking.allowedCreators(alice));
        l2Staking.removeCreator(alice);
        assert(!l2Staking.allowedCreators(alice));
    }

    function test_RemoveCreator_OnlyOwnerCanCall() public {
        l2Staking.addCreator(alice);
        assert(l2Staking.allowedCreators(alice));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        l2Staking.removeCreator(alice);
    }

    function test_LockAmount() public {
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2VotingPower.totalSupply(), 0);

        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);
    }

    function test_LockAmount_CreatorNotStakingContract() public {
        // execute the lockAmount function from a contract that is not the staking contract but is in the
        // allowedCreators list
        vm.prank(rewardsContract);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);

        assertEq(l2LockingPosition.getLockingPosition(1).creator, rewardsContract);
    }

    function test_LockAmount_DurationIsLessThanMinDuration() public {
        uint256 invalidDuration = l2Staking.MIN_LOCKING_DURATION() - 1;
        vm.prank(alice);
        vm.expectRevert("L2Staking: lockingDuration should be at least MIN_LOCKING_DURATION");
        l2Staking.lockAmount(alice, 100 * 10 ** 18, invalidDuration);
    }

    function test_LockAmount_DurationIsMoreThanMaxDuration() public {
        uint256 invalidDuration = l2Staking.MAX_LOCKING_DURATION() + 1;
        vm.prank(alice);
        vm.expectRevert("L2Staking: lockingDuration can not be greater than MAX_LOCKING_DURATION");
        l2Staking.lockAmount(alice, 100 * 10 ** 18, invalidDuration);
    }

    function test_LockAmount_InsufficientUserBalance() public {
        uint256 aliceBalance = l2LiskToken.balanceOf(alice);
        uint256 invalidAmount = aliceBalance + 1;
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(l2Staking), aliceBalance, invalidAmount
            )
        );
        l2Staking.lockAmount(alice, invalidAmount, 365);
    }

    function test_Unlock() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 365 days
        vm.warp(365 days);

        vm.prank(alice);
        l2Staking.unlock(1);

        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 0);

        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);

        assertEq(l2VotingPower.totalSupply(), 0);
        assertEq(l2VotingPower.balanceOf(alice), 0);
    }

    function test_Unlock_StakeDidNotExpire() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 364 days
        vm.warp(364 days);

        vm.prank(alice);
        vm.expectRevert("L2Staking: locking duration active, can not unlock");
        l2Staking.unlock(1);
    }

    function test_Unlock_InvalidLockingPositionId() public {
        vm.prank(alice);
        vm.expectRevert("L2Staking: locking position does not exist");
        l2Staking.unlock(1);
    }

    function test_Unlock_NotCreator() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));

        // address is inside the allowedCreators list but is not the creator of the locking position
        vm.prank(rewardsContract);
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.unlock(1);

        // address is not inside the allowedCreators list and is not the creator of the locking position
        vm.prank(address(0x3));
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.unlock(1);
    }

    function test_FastUnlock() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(daoContractAddress), 0);
        assertEq(l2LiskToken.balanceOf(rewardsContract), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(alice);
        l2Staking.fastUnlock(1);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        // penalty is sent to the DAO contract
        assertEq(l2LiskToken.balanceOf(daoContractAddress), 18150684931506849315);
        assertEq(l2LiskToken.balanceOf(rewardsContract), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18 - 18150684931506849315);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18 - 18150684931506849315); // 100 LSK
            // tokens - penalty
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 103); // 100 + 3 days
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 81849315068493150685);
        assertEq(l2VotingPower.balanceOf(alice), 81849315068493150685);
    }

    function test_FastUnlock_CreatorNotStakingContract() public {
        vm.prank(rewardsContract);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(daoContractAddress), 0);
        assertEq(l2LiskToken.balanceOf(rewardsContract), 0);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, rewardsContract);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(rewardsContract);
        l2Staking.fastUnlock(1);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(daoContractAddress), 0);
        // penalty is sent to the Rewards contract
        assertEq(l2LiskToken.balanceOf(address(rewardsContract)), 18150684931506849315);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18 - 18150684931506849315);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18 - 18150684931506849315); // 100 LSK
            // tokens - penalty
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 103); // 100 + 3 days
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 81849315068493150685);
        assertEq(l2VotingPower.balanceOf(alice), 81849315068493150685);
    }

    function test_FastUnlock_InvalidLockingPositionId() public {
        vm.prank(alice);
        vm.expectRevert("L2Staking: locking position does not exist");
        l2Staking.fastUnlock(1);
    }

    function test_FastUnlock_NotCreator() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));

        // address is inside the allowedCreators list but is not the creator of the locking position
        vm.prank(rewardsContract);
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.fastUnlock(1);

        // address is not inside the allowedCreators list and is not the creator of the locking position
        vm.prank(address(0x3));
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.fastUnlock(1);
    }

    function test_IncreaseLockingAmount() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // fund alice with additional 100 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(alice, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);

        // approve L2Staking to spend alice's additional 100 L2LiskToken
        vm.prank(alice);
        l2LiskToken.approve(address(l2Staking), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(alice, address(l2Staking)), 100 * 10 ** 18);

        vm.prank(alice);
        l2Staking.increaseLockingAmount(1, 100 * 10 ** 18);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 200 * 10 ** 18);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 200 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 200 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 200 * 10 ** 18);
    }

    function test_IncreaseLockingAmount_PausedLockingDurationNotZero() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(alice);
        l2Staking.pauseRemainingLockingDuration(1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265);

        // fund alice with additional 100 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(alice, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);

        // approve L2Staking to spend alice's additional 100 L2LiskToken
        vm.prank(alice);
        l2LiskToken.approve(address(l2Staking), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(alice, address(l2Staking)), 100 * 10 ** 18);

        vm.prank(alice);
        l2Staking.increaseLockingAmount(1, 100 * 10 ** 18);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 200 * 10 ** 18);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 200 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265);

        assertEq(l2VotingPower.totalSupply(), 345205479452054794520);
        assertEq(l2VotingPower.balanceOf(alice), 345205479452054794520);
    }

    function test_IncreaseLockingAmount_InvalidLockingPositionId() public {
        vm.prank(alice);
        vm.expectRevert("L2Staking: locking position does not exist");
        l2Staking.increaseLockingAmount(1, 100 * 10 ** 18);
    }

    function test_IncreaseLockingAmount_NotCreator() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));

        // address is inside the allowedCreators list but is not the creator of the locking position
        vm.prank(rewardsContract);
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.increaseLockingAmount(1, 100 * 10 ** 18);

        // address is not inside the allowedCreators list and is not the creator of the locking position
        vm.prank(address(0x3));
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.increaseLockingAmount(1, 100 * 10 ** 18);
    }

    function test_IncreaseLockingAmount_ZeroAmountIncrease() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);

        vm.prank(alice);
        vm.expectRevert("L2Staking: increased amount should be greater than zero");
        l2Staking.increaseLockingAmount(1, 0);
    }

    function test_IncreaseLockingAmount_ExpiredLockingPosition() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);

        // advance block time by 365 days
        vm.warp(365 days);

        // position is already expired
        vm.prank(alice);
        vm.expectRevert("L2Staking: can not increase amount for expired locking position");
        l2Staking.increaseLockingAmount(1, 100 * 10 ** 18);
    }

    function test_IncreaseLockingAmount_ExpiredLockingPosition_PausedLockingDurationNotZero() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(alice);
        l2Staking.pauseRemainingLockingDuration(1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265);

        // advance block time by 365 days
        vm.warp(365 days);

        // fund alice with additional 100 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(alice, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);

        // approve L2Staking to spend alice's additional 100 L2LiskToken
        vm.prank(alice);
        l2LiskToken.approve(address(l2Staking), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(alice, address(l2Staking)), 100 * 10 ** 18);

        // position is already expired but the remaining locking duration is paused so increasing the amount is allowed
        vm.prank(alice);
        l2Staking.increaseLockingAmount(1, 100 * 10 ** 18);

        assertEq(l2LockingPosition.getLockingPosition(1).amount, 200 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265);

        assertEq(l2VotingPower.totalSupply(), 345205479452054794520);
        assertEq(l2VotingPower.balanceOf(alice), 345205479452054794520);
    }

    function test_IncreaseLockingAmount_InsufficientUserBalance() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);

        uint256 aliceBalance = l2LiskToken.balanceOf(alice);
        uint256 invalidAmount = aliceBalance + 1;
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, address(l2Staking), aliceBalance, invalidAmount
            )
        );
        l2Staking.increaseLockingAmount(1, invalidAmount);
    }

    function test_ExtendLockingDuration_PausedLockingDurationIsZero() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 200 days so that the locking position is not yet expired
        vm.warp(200 days);

        vm.prank(alice);
        l2Staking.extendLockingDuration(1, 100);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 465); // 365 + 100 days
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);
    }

    function test_ExtendLockingDuration_PausedLockingDurationIsZero_PositionAlreadyExpired() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 500 days so that the locking position was already expired
        vm.warp(500 days);

        vm.prank(alice);
        l2Staking.extendLockingDuration(1, 100);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 600); // 500 + 100 days
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);
    }

    function test_ExtendLockingDuration_PausedLockingDurationNotZero() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(alice);
        l2Staking.pauseRemainingLockingDuration(1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265); // 365 - 100 days

        vm.prank(alice);
        l2Staking.extendLockingDuration(1, 50);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 315); // 265 + 50 days
            // (pausedLockingDuration + extendDays)

        assertEq(l2VotingPower.totalSupply(), 186301369863013698630);
        assertEq(l2VotingPower.balanceOf(alice), 186301369863013698630);
    }

    function test_ExtendLockingDuration_InvalidLockingPositionId() public {
        vm.prank(alice);
        vm.expectRevert("L2Staking: locking position does not exist");
        l2Staking.extendLockingDuration(1, 100);
    }

    function test_ExtendLockingDuration_NotCreator() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));

        // address is inside the allowedCreators list but is not the creator of the locking position
        vm.prank(rewardsContract);
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.extendLockingDuration(1, 100);

        // address is not inside the allowedCreators list and is not the creator of the locking position
        vm.prank(address(0x3));
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.extendLockingDuration(1, 100);
    }

    function test_ExtendLockingDuration_ZeroExtendedDays() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);

        vm.prank(alice);
        vm.expectRevert("L2Staking: extendDays should be greater than zero");
        l2Staking.extendLockingDuration(1, 0);
    }

    function test_PauseRemainingLockingDuration() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(alice);
        l2Staking.pauseRemainingLockingDuration(1);

        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265); // 365 - 100 days

        assertEq(l2VotingPower.totalSupply(), 172602739726027397260);
        assertEq(l2VotingPower.balanceOf(alice), 172602739726027397260);
    }

    function test_PauseRemainingLockingDuration_InvalidLockingPositionId() public {
        vm.prank(alice);
        vm.expectRevert("L2Staking: locking position does not exist");
        l2Staking.pauseRemainingLockingDuration(1);
    }

    function test_PauseRemainingLockingDuration_NotCreator() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));

        // address is inside the allowedCreators list but is not the creator of the locking position
        vm.prank(rewardsContract);
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.pauseRemainingLockingDuration(1);

        // address is not inside the allowedCreators list and is not the creator of the locking position
        vm.prank(address(0x3));
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.pauseRemainingLockingDuration(1);
    }

    function test_PauseRemainingLockingDuration_AlreadyPaused() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(alice);
        l2Staking.pauseRemainingLockingDuration(1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265); // 365 - 100 days

        vm.prank(alice);
        vm.expectRevert("L2Staking: remaining duration is already paused");
        l2Staking.pauseRemainingLockingDuration(1);
    }

    function test_PauseRemainingLockingDuration_ExpiredLockingPosition() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        // advance block time by 365 days so that the locking position is already expired
        vm.warp(365 days);

        vm.prank(alice);
        vm.expectRevert("L2Staking: locking period has ended");
        l2Staking.pauseRemainingLockingDuration(1);
    }

    function test_ResumeCountdown() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(alice);
        l2Staking.pauseRemainingLockingDuration(1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265); // 365 - 100 days

        // advance block time by another 50 days
        vm.warp(150 days);

        vm.prank(alice);
        l2Staking.resumeCountdown(1);

        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 415); // 150 + 265 days (today + paused duration)
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);
    }

    function test_ResumeCountdown_InvalidLockingPositionId() public {
        vm.prank(alice);
        vm.expectRevert("L2Staking: locking position does not exist");
        l2Staking.resumeCountdown(1);
    }

    function test_ResumeCountdown_NotCreator() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));

        // address is inside the allowedCreators list but is not the creator of the locking position
        vm.prank(rewardsContract);
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.resumeCountdown(1);

        // address is not inside the allowedCreators list and is not the creator of the locking position
        vm.prank(address(0x3));
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.resumeCountdown(1);
    }

    function test_ResumeCountdown_ZeroPausedLockingDuration() public {
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        vm.prank(alice);
        vm.expectRevert("L2Staking: countdown is not paused");
        l2Staking.resumeCountdown(1);
    }
}
