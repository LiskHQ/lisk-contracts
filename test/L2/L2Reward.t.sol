// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { IL2LiskToken, IL2Staking, L2Reward } from "src/L2/L2Reward.sol";
import { ERC721Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { L2LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2Staking } from "src/L2/L2Staking.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20Errors } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IL2LockingPosition } from "src/interfaces/L2/IL2LockingPosition.sol";

contract L2RewardTest is Test {
    L2LiskToken public l2LiskToken;
    L2Staking public l2Staking;
    L2Staking public l2StakingImplementation;
    L2LockingPosition public l2LockingPosition;
    L2LockingPosition public l2LockingPositionImplementation;
    L2VotingPower public l2VotingPowerImplementation;
    L2VotingPower public l2VotingPower;
    L2Reward public l2Reward;
    L2Reward public l2RewardImplementation;

    address public remoteToken;
    address public bridge;
    uint256 deploymentDate = 19740;

    struct Funds {
        uint256 amount;
        uint16 duration;
        uint16 delay;
    }

    struct Scenario {
        address[] stakers;
        uint256[] lockIDs;
        uint256[] oldBalances;
        uint256[] balances;
        uint256 lastClaimedAmount;
    }

    struct Position {
        uint256 amount;
        uint256 duration;
    }

    function setUp() public {
        skip(deploymentDate * 1 days);

        bridge = vm.addr(uint256(bytes32("bridge")));
        remoteToken = vm.addr(uint256(bytes32("remoteToken")));

        vm.prank(address(this), address(this));

        l2LiskToken = new L2LiskToken(remoteToken);
        l2LiskToken.initialize(bridge);

        vm.stopPrank();

        l2StakingImplementation = new L2Staking();
        l2Staking = L2Staking(
            address(
                new ERC1967Proxy(
                    address(l2StakingImplementation),
                    abi.encodeWithSelector(l2Staking.initialize.selector, address(l2LiskToken))
                )
            )
        );

        l2LockingPositionImplementation = new L2LockingPosition();
        l2LockingPosition = L2LockingPosition(
            address(
                new ERC1967Proxy(
                    address(l2LockingPositionImplementation),
                    abi.encodeWithSelector(l2LockingPosition.initialize.selector, address(l2Staking))
                )
            )
        );

        l2VotingPowerImplementation = new L2VotingPower();
        l2VotingPower = L2VotingPower(
            address(
                new ERC1967Proxy(
                    address(l2VotingPowerImplementation),
                    abi.encodeWithSelector(l2VotingPower.initialize.selector, address(l2LockingPosition))
                )
            )
        );

        l2Staking.initializeLockingPosition(address(l2LockingPosition));
        l2LockingPosition.initializeVotingPower(address(l2VotingPower));

        l2RewardImplementation = new L2Reward();

        vm.expectEmit(true, true, true, true);
        emit L2Staking.LiskTokenContractAddressChanged(address(0x0), address(l2LiskToken));

        l2Reward = L2Reward(
            address(
                new ERC1967Proxy(
                    address(l2RewardImplementation),
                    abi.encodeWithSelector(l2Reward.initialize.selector, address(l2LiskToken))
                )
            )
        );

        l2Reward.initializeLockingPosition(address(l2LockingPosition));

        vm.expectEmit(true, true, true, true);
        emit L2Reward.StakingContractAddressChanged(address(0x0), address(l2Staking));
        l2Reward.initializeStaking(address(l2Staking));

        assertEq(l2Reward.l2TokenContract(), address(l2LiskToken));
        assertEq(l2Reward.lockingPositionContract(), address(l2LockingPosition));
        assertEq(l2Reward.stakingContract(), address(l2Staking));

        l2Staking.addCreator(address(l2Reward));
    }

    function test_initialize() public view {
        assertEq(l2Reward.lastTrsDate(), deploymentDate);
        assertEq(l2Reward.OFFSET(), 150);
        assertEq(l2Reward.REWARD_DURATION(), 30);
        assertEq(l2Reward.REWARD_DURATION_DELAY(), 1);
        assertEq(l2Reward.version(), "1.0.0");
        assertEq(l2Reward.totalWeight(), 0);
        assertEq(l2Reward.totalAmountLocked(), 0);
        assertEq(l2Reward.pendingUnlockAmount(), 0);
    }

    function given_accountHasBalance(address account, uint256 balance) private {
        vm.startPrank(bridge);
        l2LiskToken.mint(account, balance);
        vm.stopPrank();
    }

    function given_accountsHaveBalance(address[] memory accounts, uint256 balance) private {
        vm.startPrank(bridge);
        for (uint8 i = 0; i < accounts.length; i++) {
            l2LiskToken.mint(accounts[i], balance);
        }
        vm.stopPrank();
    }

    function given_ownerHasFundedStaking(Funds memory funds) public returns (uint256) {
        l2LiskToken.approve(address(l2Reward), funds.amount);
        l2Reward.fundStakingRewards(funds.amount, funds.duration, funds.delay);

        return funds.amount / funds.duration;
    }

    function given_anArrayOfStakersOfLength(uint8 length) private pure returns (address[] memory) {
        address[] memory stakers = new address[](length);

        for (uint8 i = 0; i < length; i++) {
            stakers[i] = address(uint160(i + 1));
        }

        return stakers;
    }

    function when_stakerCreatesPosition(address staker, Position memory position) private returns (uint256) {
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), position.amount);
        uint256 ID = l2Reward.createPosition(position.amount, position.duration);
        vm.stopPrank();

        return ID;
    }

    function then_eventLockingPositionCreatedIsEmitted(uint256 lockID) private {
        vm.expectEmit(true, true, true, true, address(l2Reward));
        emit L2Reward.LockingPositionCreated(lockID);
    }

    function then_eventLockingPositionDeletedIsEmitted(uint256 lockID) private {
        vm.expectEmit(true, true, true, true);
        emit L2Reward.LockingPositionDeleted(lockID);
    }

    function then_eventLockingPositionPausedIsEmitted(uint256 lockID) private {
        vm.expectEmit(true, true, true, true);
        emit L2Reward.LockingPositionPaused(lockID);
    }

    function then_eventUnlockingCountdownResumedIsEmitted(uint256 lockID) private {
        vm.expectEmit(true, true, true, true);
        emit L2Reward.UnlockingCountdownResumed(lockID);
    }

    function then_eventLockingDurationExtendedIsEmitted(uint256 lockID, uint256 durationExtension) private {
        vm.expectEmit(true, true, true, true);
        emit L2Reward.LockingDurationExtended(lockID, durationExtension);
    }

    function then_eventLockingAmountIncreasedIsEmitted(uint256 lockID, uint256 amountIncrease) private {
        vm.expectEmit(true, true, true, true);
        emit L2Reward.LockingAmountIncreased(lockID, amountIncrease);
    }

    function then_eventFastUnlockInitiatedIsEmitted(uint256 lockID) private {
        vm.expectEmit(true, true, true, true);
        emit L2Reward.FastUnlockInitiated(lockID);
    }

    function then_eventRewardsClaimedIsEmitted(uint256 lockID, uint256 reward) private {
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockID, reward);
    }

    function when_rewardsAreClaimedByStaker(address staker, uint256[] memory lockIDs) private {
        vm.startPrank(staker);
        l2Reward.claimRewards(lockIDs);
        vm.stopPrank();
    }

    function onDay(uint256 day) private {
        vm.warp((deploymentDate + day) * 86400);
    }

    function stakerCreatesPosition(
        uint256 stakerIndex,
        uint256 amount,
        uint256 duration,
        Scenario memory scenario
    )
        private
    {
        vm.startPrank(scenario.stakers[stakerIndex]);
        l2LiskToken.approve(address(l2Reward), amount);
        scenario.lockIDs[stakerIndex] = l2Reward.createPosition(amount, duration);
        vm.stopPrank();
    }

    function stakerPausesPosition(uint256 stakerIndex, Scenario memory scenario) private {
        uint256[] memory positionsToBeModified = new uint256[](1);
        positionsToBeModified[0] = scenario.lockIDs[stakerIndex];
        vm.prank(scenario.stakers[stakerIndex]);
        l2Reward.pauseUnlocking(positionsToBeModified);
    }

    function stakerInitiatesFastUnlock(uint256 stakerIndex, Scenario memory scenario) private {
        uint256[] memory positionsToBeModified = new uint256[](1);
        positionsToBeModified[0] = scenario.lockIDs[stakerIndex];
        vm.prank(scenario.stakers[stakerIndex]);
        l2Reward.initiateFastUnlock(positionsToBeModified);
    }

    function stakerReumesPosition(uint256 stakerIndex, Scenario memory scenario) private {
        uint256[] memory positionsToBeModified = new uint256[](1);
        positionsToBeModified[0] = scenario.lockIDs[stakerIndex];
        vm.prank(scenario.stakers[stakerIndex]);
        l2Reward.resumeUnlockingCountdown(positionsToBeModified);
    }

    function stakerUnlocksPosition(uint256 stakerIndex, Scenario memory scenario) private {
        uint256[] memory positionsToBeModified = new uint256[](1);
        positionsToBeModified[0] = scenario.lockIDs[stakerIndex];
        vm.prank(scenario.stakers[stakerIndex]);
        l2Reward.deletePositions(positionsToBeModified);
        delete scenario.lockIDs[stakerIndex];
    }

    function stakerExtendsPositionBy(
        uint256 stakerIndex,
        uint256 durationExtension,
        Scenario memory scenario
    )
        private
    {
        L2Reward.ExtendedDuration[] memory durationExtensions = new L2Reward.ExtendedDuration[](1);
        durationExtensions[0].lockID = scenario.lockIDs[stakerIndex];
        durationExtensions[0].durationExtension = durationExtension;
        vm.prank(scenario.stakers[stakerIndex]);
        l2Reward.extendDuration(durationExtensions);
    }

    function stakerIncreasesAmountOfThePositionBy(
        uint256 stakerIndex,
        uint256 amountIncrease,
        Scenario memory scenario
    )
        private
    {
        L2Reward.IncreasedAmount[] memory increasingAmounts = new L2Reward.IncreasedAmount[](1);
        increasingAmounts[0].lockID = scenario.lockIDs[stakerIndex];
        increasingAmounts[0].amountIncrease = amountIncrease;
        vm.startPrank(scenario.stakers[stakerIndex]);
        l2LiskToken.approve(address(l2Reward), amountIncrease);
        l2Reward.increaseLockingAmount(increasingAmounts);
        vm.stopPrank();
    }

    function stakerClaimRewards(uint256 stakerIndex, Scenario memory scenario) private {
        uint256[] memory positionsToBeModified = new uint256[](1);
        positionsToBeModified[0] = scenario.lockIDs[stakerIndex];
        vm.prank(scenario.stakers[stakerIndex]);
        l2Reward.claimRewards(positionsToBeModified);
    }

    function allStakersClaim(Scenario memory scenario) private {
        uint256[] memory positionsToBeModified = new uint256[](1);
        scenario.lastClaimedAmount = 0;
        for (uint8 i = 0; i < scenario.stakers.length; i++) {
            if (scenario.lockIDs[i] == 0) {
                continue;
            }

            positionsToBeModified[0] = scenario.lockIDs[i];
            vm.prank(scenario.stakers[i]);
            l2Reward.claimRewards(positionsToBeModified);

            scenario.balances[i] = l2LiskToken.balanceOf(scenario.stakers[i]);

            scenario.lastClaimedAmount += scenario.balances[i] - scenario.oldBalances[i];
        }
    }

    function cacheBalances(Scenario memory scenario) private {
        for (uint8 i = 0; i < scenario.stakers.length; i++) {
            scenario.oldBalances[i] = l2LiskToken.balanceOf(scenario.stakers[i]);
        }
    }

    function checkRewardsContractBalance(uint256 funds) public {
        uint256 sumOfDailyRewards;
        for (uint256 i = deploymentDate; i < l2Reward.todayDay(); i++) {
            sumOfDailyRewards += l2Reward.dailyRewards(i);
        }

        assertTrue(l2LiskToken.balanceOf(address(l2Reward)) > funds - sumOfDailyRewards);
        assertEq(l2LiskToken.balanceOf(address(l2Reward)) / 10 ** 4, (funds - sumOfDailyRewards) / 10 ** 4);
    }

    function test_scenario1() public {
        address[] memory stakers = given_anArrayOfStakersOfLength(7);
        uint256[] memory lockIDs = new uint256[](7);
        uint256[] memory balances = new uint256[](7);
        uint256[] memory oldBalances = new uint256[](7);
        uint256 funds = convertLiskToSmallestDenomination(5000);
        uint256 balance = convertLiskToSmallestDenomination(500);
        uint256[] memory positionsToBeModified = new uint256[](1);

        // owner gets balance
        given_accountHasBalance(address(this), funds);
        // fund the reward contract, 10 Lisk per day for 500
        given_ownerHasFundedStaking(Funds({ amount: funds, duration: 500, delay: 1 }));

        // all the stakers gets balance
        for (uint8 i = 0; i < stakers.length; i++) {
            given_accountHasBalance(stakers[i], balance);
        }
        Scenario memory scenario = Scenario({
            stakers: stakers,
            lockIDs: lockIDs,
            balances: balances,
            oldBalances: oldBalances,
            lastClaimedAmount: 0
        });

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(1);
        stakerCreatesPosition(0, LSK(100), 30, scenario);
        stakerCreatesPosition(1, LSK(100), 80, scenario);
        onDay(10);
        stakerCreatesPosition(2, LSK(100), 100, scenario);
        onDay(30);
        stakerPausesPosition(1, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(35);
        stakerCreatesPosition(3, LSK(50), 14, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(49);
        stakerUnlocksPosition(3, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        stakerCreatesPosition(4, LSK(80), 80, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(50);
        stakerExtendsPositionBy(0, 30, scenario);
        onDay(70);
        stakerCreatesPosition(5, LSK(100), 150, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(80);
        stakerReumesPosition(1, scenario);
        onDay(89);
        stakerPausesPosition(4, scenario);
        onDay(95);
        stakerCreatesPosition(6, LSK(200), 200, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(100);
        stakerIncreasesAmountOfThePositionBy(6, LSK(50), scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(105);
        allStakersClaim(scenario);
        checkRewardsContractBalance(funds);
        cacheBalances(scenario);
        onDay(106);
        allStakersClaim(scenario);
        checkRewardsContractBalance(funds);
        lastClaimedRewardEqualsDailyRewardBetweenDays(scenario.lastClaimedAmount, 105, 105);
        onDay(115);
        cacheBalances(scenario);
        allStakersClaim(scenario);
        checkRewardsContractBalance(funds);
        lastClaimedRewardEqualsDailyRewardBetweenDays(scenario.lastClaimedAmount, 106, 114);
        cacheBalances(scenario);
        onDay(150);
        allStakersClaim(scenario);
        checkRewardsContractBalance(funds);
        onDay(230);
        allStakersClaim(scenario);
        checkRewardsContractBalance(funds);
        lastClaimedRewardEqualsDailyRewardBetweenDays(scenario.lastClaimedAmount, 115, 229);
        // stake 4 gets resumed, expiry date should be 270
        stakerReumesPosition(4, scenario);
        assertEq(l2LockingPosition.getLockingPosition(scenario.lockIDs[4]).expDate, deploymentDate + 270);
        onDay(240);
        stakerInitiatesFastUnlock(6, scenario);
        stakerClaimRewards(4, scenario);
        cacheBalances(scenario);
        onDay(275);
        allStakersClaim(scenario);
        lastClaimedRewardEqualsDailyRewardBetweenDays(scenario.lastClaimedAmount, 240, 269);
        for (uint256 i = 19740 + 270; i < 19740 + 275; i++) {
            assertEq(l2Reward.totalWeights(i), 0);
        }
    }

    function createScenario2() private returns (uint256[] memory, address[] memory) {
        address[] memory stakers = given_anArrayOfStakersOfLength(7);
        uint256[] memory lockIDs = new uint256[](7);
        uint256 funds = convertLiskToSmallestDenomination(5000);
        uint256 balance = convertLiskToSmallestDenomination(500);
        uint256[] memory balances = new uint256[](7);
        uint256[] memory oldBalances = new uint256[](7);
        uint256[] memory positionsToBeModified = new uint256[](1);

        // owner gets balance
        given_accountHasBalance(address(this), funds);
        // fund the reward contract, 10 Lisk per day for 500
        given_ownerHasFundedStaking(Funds({ amount: funds, duration: 500, delay: 1 }));

        // all the stakers gets balance
        for (uint8 i = 0; i < stakers.length; i++) {
            given_accountHasBalance(stakers[i], balance);
        }

        Scenario memory scenario = Scenario({
            stakers: stakers,
            lockIDs: lockIDs,
            balances: balances,
            oldBalances: oldBalances,
            lastClaimedAmount: 0
        });
        onDay(1);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        stakerCreatesPosition(0, LSK(100), 730, scenario);
        stakerCreatesPosition(1, LSK(100), 730, scenario);
        onDay(2);
        stakerPausesPosition(1, scenario);
        onDay(5);
        stakerCreatesPosition(2, LSK(200), 30, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(10);
        stakerCreatesPosition(3, LSK(50), 100, scenario);
        stakerPausesPosition(3, scenario);
        onDay(20);
        stakerIncreasesAmountOfThePositionBy(3, LSK(30), scenario);
        stakerCreatesPosition(4, LSK(100), 200, scenario);
        onDay(25);
        stakerCreatesPosition(5, LSK(150), 100, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(30);
        stakerPausesPosition(4, scenario);
        onDay(40);
        stakerInitiatesFastUnlock(4, scenario);
        onDay(50);
        stakerPausesPosition(5, scenario);
        onDay(55);
        stakerCreatesPosition(6, LSK(30), 14, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(80);
        stakerReumesPosition(5, scenario);
        onDay(85);
        stakerExtendsPositionBy(6, 25, scenario);
        onDay(90);
        stakerExtendsPositionBy(3, 65, scenario);
        onDay(93);
        stakerIncreasesAmountOfThePositionBy(5, LSK(30), scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        return (lockIDs, stakers);
    }

    function createScenario3() private returns (uint256[] memory, address[] memory) {
        address[] memory stakers = given_anArrayOfStakersOfLength(14);
        uint256[] memory lockIDs = new uint256[](14);
        uint256[] memory balances = new uint256[](7);
        uint256[] memory oldBalances = new uint256[](7);
        uint256 funds = convertLiskToSmallestDenomination(5000);
        uint256 balance = convertLiskToSmallestDenomination(5000);

        uint256[] memory positionsToBeModified = new uint256[](1);
        L2Reward.ExtendedDuration[] memory durationExtensions = new L2Reward.ExtendedDuration[](1);
        L2Reward.IncreasedAmount[] memory increasingAmounts = new L2Reward.IncreasedAmount[](1);

        // owner gets balance
        given_accountHasBalance(address(this), funds);
        // fund the reward contract, 10 Lisk per day for 500 days
        given_ownerHasFundedStaking(Funds({ amount: funds, duration: 500, delay: 1 }));

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        // all the stakers gets balance
        for (uint8 i = 0; i < stakers.length; i++) {
            given_accountHasBalance(stakers[i], balance);
        }

        Scenario memory scenario = Scenario({
            stakers: stakers,
            lockIDs: lockIDs,
            balances: balances,
            oldBalances: oldBalances,
            lastClaimedAmount: 0
        });

        onDay(1);
        stakerCreatesPosition(0, LSK(100), 730, scenario);
        stakerCreatesPosition(1, LSK(30), 50, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        stakerCreatesPosition(2, LSK(400), 730, scenario);
        onDay(15);
        stakerCreatesPosition(3, LSK(5), 300, scenario);
        onDay(20);
        stakerCreatesPosition(4, LSK(500), 50, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        stakerCreatesPosition(5, LSK(1250), 80, scenario);
        onDay(30);
        stakerIncreasesAmountOfThePositionBy(0, LSK(90), scenario);
        stakerIncreasesAmountOfThePositionBy(3, LSK(1), scenario);
        stakerInitiatesFastUnlock(4, scenario);
        onDay(31);
        stakerExtendsPositionBy(4, 21, scenario);
        onDay(35);
        stakerInitiatesFastUnlock(5, scenario);
        onDay(36);
        stakerPausesPosition(5, scenario);
        stakerCreatesPosition(6, LSK(125), 80, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(40);
        stakerIncreasesAmountOfThePositionBy(4, LSK(30), scenario);
        stakerPausesPosition(4, scenario);
        onDay(45);
        stakerCreatesPosition(7, LSK(2000), 70, scenario);
        stakerCreatesPosition(8, LSK(220), 600, scenario);
        stakerCreatesPosition(9, LSK(300), 534, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        stakerCreatesPosition(10, LSK(80), 53, scenario);
        stakerCreatesPosition(11, LSK(110), 23, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        stakerCreatesPosition(12, LSK(1000), 68, scenario);
        onDay(50);
        stakerPausesPosition(8, scenario);
        onDay(51);
        stakerPausesPosition(9, scenario);
        onDay(52);
        stakerExtendsPositionBy(9, 116, scenario);
        onDay(55);
        stakerIncreasesAmountOfThePositionBy(8, LSK(300), scenario);
        onDay(58);
        stakerInitiatesFastUnlock(8, scenario);
        onDay(59);
        stakerPausesPosition(8, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(60);
        stakerInitiatesFastUnlock(6, scenario);
        onDay(61);
        stakerExtendsPositionBy(6, 8, scenario);
        stakerPausesPosition(6, scenario);
        onDay(65);
        stakerExtendsPositionBy(6, 4, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        stakerIncreasesAmountOfThePositionBy(6, LSK(50), scenario);
        onDay(66);
        stakerExtendsPositionBy(10, 10, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(68);
        stakerInitiatesFastUnlock(7, scenario);
        stakerPausesPosition(10, scenario);
        onDay(69);
        stakerExtendsPositionBy(7, 150, scenario);
        onDay(70);
        stakerPausesPosition(0, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(75);
        stakerExtendsPositionBy(5, 20, scenario);
        onDay(76);
        stakerExtendsPositionBy(11, 50, scenario);
        onDay(100);
        stakerReumesPosition(0, scenario);
        stakerReumesPosition(5, scenario);
        stakerCreatesPosition(13, LSK(500), 14, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        stakerPausesPosition(13, scenario);
        stakerExtendsPositionBy(12, 100, scenario);
        onDay(101);
        stakerExtendsPositionBy(10, 10, scenario);
        onDay(102);
        stakerIncreasesAmountOfThePositionBy(12, LSK(500), scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(104);
        stakerPausesPosition(12, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        onDay(107);
        stakerReumesPosition(6, scenario);
        stakerInitiatesFastUnlock(7, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
        stakerIncreasesAmountOfThePositionBy(12, 500, scenario);
        onDay(108);
        stakerReumesPosition(4, scenario);
        onDay(110);
        stakerExtendsPositionBy(0, 30, scenario);
        stakerReumesPosition(12, scenario);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        return (lockIDs, stakers);
    }

    function checkConsistencyPendingUnlockDailyUnlocked(
        uint256[] memory lockIDs,
        uint256 expiryDateOfLongestStake
    )
        private
        view
    {
        uint256 sumOfDailyUnlockedAmount;
        for (uint256 i = l2Reward.lastTrsDate() + 1; i <= expiryDateOfLongestStake; i++) {
            sumOfDailyUnlockedAmount += l2Reward.dailyUnlockedAmounts(i);
        }

        assertEq(l2Reward.pendingUnlockAmount(), sumOfDailyUnlockedAmount);

        uint256 sumOfAmountOfPausedStakes;
        for (uint8 i = 0; i < lockIDs.length; i++) {
            if (l2LockingPosition.getLockingPosition(lockIDs[i]).pausedLockingDuration != 0) {
                sumOfAmountOfPausedStakes += l2LockingPosition.getLockingPosition(lockIDs[i]).amount;
            }
        }

        assertEq(sumOfDailyUnlockedAmount + sumOfAmountOfPausedStakes, l2Reward.totalAmountLocked());
    }

    function getLargestExpiryDate(uint256[] memory lockIDs) private view returns (uint256) {
        uint256 expiryDate;
        IL2LockingPosition.LockingPosition memory lockingPosition;

        for (uint256 i = 0; i < lockIDs.length; i++) {
            lockingPosition = l2LockingPosition.getLockingPosition(lockIDs[i]);
            if (lockingPosition.expDate > expiryDate) {
                expiryDate = lockingPosition.expDate;
            }
        }

        return expiryDate;
    }

    function lastClaimedRewardEqualsDailyRewardBetweenDays(uint256 reward, uint256 startDay, uint256 endDay) private {
        uint256 sumOfDailyRewards;
        for (uint256 i = deploymentDate + startDay; i <= deploymentDate + endDay; i++) {
            sumOfDailyRewards += l2Reward.dailyRewards(i);
        }

        assertTrue(sumOfDailyRewards > reward);
        assertEq(sumOfDailyRewards / 10 ** 4, reward / 10 ** 4);
    }

    function test_scenario2_dailyRewards() public {
        // Scenario: rewards alloted for a certain day(s) is less than or equal to dailyRewards available for those
        // days.
        // Description:
        // claim rewards against all positions on day 105
        // Act:
        // move to day 106, claim rewards against all positions again
        // Assert:
        // total rewards claimed on day 106 is equal to daily rewards available for day 105.
        // Act:
        // move to day 115, claim rewards against all positions again
        // Assert:
        // total rewards claimed on day 115 is equal to sum of daily rewards between day 106 and 114.
        uint256[] memory lockIDs;
        address[] memory stakers;
        uint256[] memory positionsToBeModified = new uint256[](1);
        uint256[] memory balances = new uint256[](7);
        Scenario memory scenario;
        uint256 totalRewards;

        (lockIDs, stakers) = createScenario2();

        vm.warp(19740 days + 105 days);

        for (uint8 i = 0; i < lockIDs.length; i++) {
            positionsToBeModified[0] = lockIDs[i];
            when_rewardsAreClaimedByStaker(stakers[i], positionsToBeModified);
        }

        // get balances before claiming rewards again
        for (uint8 i = 0; i < stakers.length; i++) {
            balances[i] = l2LiskToken.balanceOf(stakers[i]);
        }

        vm.warp(19740 days + 106 days);
        // all positions claim rewards on day 106
        for (uint8 i = 0; i < stakers.length; i++) {
            positionsToBeModified[0] = lockIDs[i];
            when_rewardsAreClaimedByStaker(stakers[i], positionsToBeModified);
        }

        for (uint8 i = 0; i < stakers.length; i++) {
            totalRewards += l2LiskToken.balanceOf(stakers[i]) - balances[i];
        }

        // total rewards claimed on day 106 are less than or equal to dailyRewards on day 105.
        assertTrue(totalRewards <= l2Reward.dailyRewards(19740 + 105));
        assertEq(totalRewards / 10, l2Reward.dailyRewards(19740 + 105) / 10);

        vm.warp(19740 days + 115 days);

        // get balances before claiming rewards again
        for (uint8 i = 0; i < stakers.length; i++) {
            balances[i] = l2LiskToken.balanceOf(stakers[i]);
        }

        // all positions claim rewards on day 115
        for (uint8 i = 0; i < stakers.length; i++) {
            positionsToBeModified[0] = lockIDs[i];
            when_rewardsAreClaimedByStaker(stakers[i], positionsToBeModified);
        }

        totalRewards = 0;
        for (uint8 i = 0; i < stakers.length; i++) {
            totalRewards += l2LiskToken.balanceOf(stakers[i]) - balances[i];
        }

        uint256 sumOfDailyRewards;
        for (uint256 i = deploymentDate + 106; i < deploymentDate + 115; i++) {
            sumOfDailyRewards += l2Reward.dailyRewards(i);
        }

        assertTrue(sumOfDailyRewards > totalRewards);
        assertEq(sumOfDailyRewards / 10 ** 2, totalRewards / 10 ** 2);
    }

    function test_scenario3_dailyRewards() public {
        // Scenario: rewards alloted for a certain day(s) is less than or equal to dailyRewards available for those
        // days.
        // Description:
        // claim rewards against all positions on day 200
        // Act:
        // move to day 201, claim rewards against all positions again
        // Assert:
        // total rewards claimed on day 201 is equal to daily rewards available for day 200
        // Act:
        // move to day 250, claim rewards against all positions again
        // Assert:
        // total rewards claimed on day 250 is equal to sum of daily rewards between 201 and 249

        uint256[] memory lockIDs;
        address[] memory stakers;
        uint256[] memory positionsToBeModified = new uint256[](1);
        uint256[] memory balances = new uint256[](14);
        uint256 totalRewards;

        (lockIDs, stakers) = createScenario3();

        vm.warp(19740 days + 200 days);

        // claim rewards against all positions on day 200
        for (uint8 i = 0; i < lockIDs.length; i++) {
            positionsToBeModified[0] = lockIDs[i];
            when_rewardsAreClaimedByStaker(stakers[i], positionsToBeModified);
        }

        // get balances before claiming rewards again
        for (uint8 i = 0; i < stakers.length; i++) {
            balances[i] = l2LiskToken.balanceOf(stakers[i]);
        }

        vm.warp(19740 days + 201 days);
        // all positions claim rewards on day 201
        for (uint8 i = 0; i < lockIDs.length; i++) {
            positionsToBeModified[0] = lockIDs[i];
            when_rewardsAreClaimedByStaker(stakers[i], positionsToBeModified);
        }

        totalRewards = 0;
        for (uint8 i = 0; i < stakers.length; i++) {
            totalRewards += l2LiskToken.balanceOf(stakers[i]) - balances[i];
        }

        // total rewards claimed on day 201 are less than or equal to dailyRewards on day 200
        assertTrue(totalRewards <= l2Reward.dailyRewards(19740 + 200));
        assertEq(totalRewards / 10 ** 3, l2Reward.dailyRewards(19740 + 200) / 10 ** 3);

        vm.warp(19740 days + 250 days);

        // get balances before claiming rewards again
        for (uint8 i = 0; i < stakers.length; i++) {
            balances[i] = l2LiskToken.balanceOf(stakers[i]);
        }

        // all positions claim rewards on day 250
        for (uint8 i = 0; i < stakers.length; i++) {
            positionsToBeModified[0] = lockIDs[i];
            when_rewardsAreClaimedByStaker(stakers[i], positionsToBeModified);
        }

        totalRewards = 0;
        for (uint8 i = 0; i < stakers.length; i++) {
            totalRewards += l2LiskToken.balanceOf(stakers[i]) - balances[i];
        }

        uint256 sumOfDailyRewards;
        for (uint256 i = 19740 + 201; i < 19740 + 250; i++) {
            sumOfDailyRewards += l2Reward.dailyRewards(i);
        }

        assertTrue(sumOfDailyRewards >= totalRewards);
        assertEq(sumOfDailyRewards / 10 ** 3, totalRewards / 10 ** 3);
    }

    function test_scenario2_pendingUnlockAmount() public {
        uint256[] memory lockIDs;
        address[] memory stakers;

        (lockIDs, stakers) = createScenario2();

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
    }

    function test_scenario3_pendingUnlockAmount() public {
        uint256[] memory lockIDs;
        address[] memory stakers;

        (lockIDs, stakers) = createScenario3();

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
    }

    function test_createPosition_l2RewardContractShouldBeApprovedToTransferFromStakerAccount() public {
        address staker = address(0x1);
        uint256 duration = 20;
        uint256 amount = convertLiskToSmallestDenomination(10);

        given_accountHasBalance(staker, convertLiskToSmallestDenomination(1000));

        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(l2Reward), 0, amount)
        );
        l2Reward.createPosition(amount, duration);
        vm.stopPrank();
    }

    function test_createPosition_updatesGlobals() public {
        address staker = address(0x1);
        uint256 duration = 20;
        uint256 amount = convertLiskToSmallestDenomination(10);

        given_accountHasBalance(staker, convertLiskToSmallestDenomination(1000));
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        then_eventLockingPositionCreatedIsEmitted(1);
        uint256 ID = l2Reward.createPosition(amount, duration);
        vm.stopPrank();

        assertEq(l2Reward.totalWeight(), amount * (duration + l2Reward.OFFSET()));
        assertEq(l2Reward.lastClaimDate(ID), deploymentDate);
        assertEq(l2Reward.totalAmountLocked(), amount);
        assertEq(l2Reward.dailyUnlockedAmounts(l2Reward.lastTrsDate() + duration), amount);
        assertEq(l2Reward.pendingUnlockAmount(), amount);
        assertEq(l2Reward.lastTrsDate(), deploymentDate);
        assertEq(l2LiskToken.allowance(staker, address(l2Reward)), 0);
    }

    function test_createPosition_aggregatesAmountAndWeightAndUpdatesGlobals() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 amount;

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);

        uint256 dailyReward = given_ownerHasFundedStaking(
            Funds({ amount: convertLiskToSmallestDenomination(1000), duration: 350, delay: 1 })
        );

        // staker creates a position on deploymentDate, 19740
        amount = convertLiskToSmallestDenomination(100);
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        then_eventLockingPositionCreatedIsEmitted(1);
        l2Reward.createPosition(amount, 120);
        vm.stopPrank();

        // staker creates another position on deploymentDate + 2, 19742
        skip(2 days);
        amount = convertLiskToSmallestDenomination(1);
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        then_eventLockingPositionCreatedIsEmitted(2);
        l2Reward.createPosition(amount, 100);
        vm.stopPrank();

        uint256 expectedTotalWeight = convertLiskToSmallestDenomination(100) * (120 + l2Reward.OFFSET())
            + convertLiskToSmallestDenomination(1) * (100 + l2Reward.OFFSET()) - 200 * 10 ** 18;
        assertEq(l2Reward.totalWeight(), expectedTotalWeight);
        assertEq(l2Reward.totalAmountLocked(), convertLiskToSmallestDenomination(101));
        assertEq(l2Reward.pendingUnlockAmount(), convertLiskToSmallestDenomination(101));
        assertEq(l2Reward.lastTrsDate(), deploymentDate + 2);
        uint256 cappedRewards = convertLiskToSmallestDenomination(100) / 365;

        // Rewards are capped for the day, 19741 as funding starts at 19741.
        assertEq(l2Reward.dailyRewards(19741), cappedRewards);
        assertEq(l2Reward.rewardsSurplus(), dailyReward - cappedRewards);

        // staker creates another position on deploymentDate + 5, 19745
        skip(3 days);
        amount = convertLiskToSmallestDenomination(100);
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        then_eventLockingPositionCreatedIsEmitted(3);
        l2Reward.createPosition(convertLiskToSmallestDenomination(100), 100);
        vm.stopPrank();

        uint256 newCappedRewards = convertLiskToSmallestDenomination(101) / 365;
        for (uint16 i = 19742; i < 19745; i++) {
            assertEq(l2Reward.dailyRewards(i), newCappedRewards);
        }
    }

    function test_fundStakingRewards_onlyOwnerCanFundRewards() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x1)));

        vm.startPrank(address(0x1));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(3550), 255, 1);
    }

    function test_fundStakingRewards_delayShouldBeGreaterThanZeroWhenFundingStakingRewards() public {
        vm.expectRevert("L2Reward: Funding should start from next day or later");

        vm.prank(address(this));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(3550), 255, 0);
    }

    function test_fundStakingRewards_dailyRewardsAreAggregatedForTheDuration() public {
        uint256 balance = convertLiskToSmallestDenomination(1000);

        given_accountHasBalance(address(this), balance);

        uint256 amount = convertLiskToSmallestDenomination(35);
        uint16 duration = 350;
        uint16 delay = 1;
        uint256 dailyReward = given_ownerHasFundedStaking(Funds({ amount: amount, duration: duration, delay: delay }));

        uint256 today = deploymentDate;
        uint256 endDate = today + delay + duration;

        for (uint256 d = today + delay; d < endDate; d++) {
            assertEq(l2Reward.dailyRewards(d), dailyReward);
        }

        assertEq(l2LiskToken.balanceOf(address(address(this))), balance - amount);
        assertEq(l2LiskToken.balanceOf(address(l2Reward)), amount);
        assertEq(l2Reward.dailyRewards(today), 0);
        assertEq(l2Reward.dailyRewards(endDate), 0);

        delay = 2;
        duration = 10;
        uint256 additionalReward = given_ownerHasFundedStaking(Funds({ amount: amount, duration: duration, delay: 2 }));

        uint256 newEndDate = today + delay + duration;

        for (uint256 d = today + delay; d < newEndDate; d++) {
            assertEq(l2Reward.dailyRewards(d), dailyReward + additionalReward);
        }

        assertEq(l2Reward.dailyRewards(today), 0);
        assertEq(l2Reward.dailyRewards(today + 1), dailyReward);
        assertEq(l2Reward.dailyRewards(newEndDate), dailyReward);
    }

    function test_fundStaking_emitsRewardsAddedEvent() public {
        uint256 balance = convertLiskToSmallestDenomination(10000);

        given_accountHasBalance(address(this), balance);

        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(1000));
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsAdded(convertLiskToSmallestDenomination(1000), 10, 1);
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(1000), 10, 1);
    }

    function test_claimRewards_onlyExistingLockingPositionCanBeClaimedByTheOwner() public {
        address staker = address(0x1);
        uint256 lockID = 1;

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");

        uint256[] memory lockIDs = new uint256[](1);

        lockIDs[0] = lockID;

        l2Reward.claimRewards(lockIDs);

        vm.mockCall(
            address(l2LockingPosition), abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector), abi.encode(staker)
        );
        vm.mockCall(address(l2Reward), abi.encodeWithSelector(l2Reward.lastClaimDate.selector), abi.encode(0));
        vm.prank(staker);
        vm.expectRevert("L2Reward: Locking position does not exist");

        l2Reward.claimRewards(lockIDs);
    }

    function test_claimRewards_rewardIsZeroIfAlreadyClaimedToday() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256[] memory lockIDs = new uint256[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        // staker creates a position on deploymentDate, 19740
        lockIDs[0] = when_stakerCreatesPosition(
            staker, Position({ amount: convertLiskToSmallestDenomination(100), duration: 120 })
        );

        // rewards are claimed from lastClaimDate for the lock (19740) till expiry day
        uint256 today = deploymentDate + 150;
        skip(150 days);

        uint256 expectedRewards = 11.9 * 10 ** 18;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;

        // staker claims rewards on, 19890

        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewards);
        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);

        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2LiskToken.balanceOf(staker), expectedBalance);

        // staker claims again on, 19890
        then_eventRewardsClaimedIsEmitted(lockIDs[0], 0);
        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);
    }

    function test_claimRewards_activePositionsAreRewardedTillExpiry() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256[] memory lockIDs = new uint256[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        // staker creates a position on deploymentDate, 19740
        lockIDs[0] = when_stakerCreatesPosition(
            staker, Position({ amount: convertLiskToSmallestDenomination(100), duration: 120 })
        );

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        // rewards are claimed from lastClaimDate for the lock (19740) till expiry day
        uint256 today = deploymentDate + 150;
        skip(150 days);

        uint256 expectedRewards = 11.9 * 10 ** 18;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;

        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewards);
        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2LiskToken.balanceOf(staker), expectedBalance);
    }

    function test_claimRewards_activePositionsAreRewardedTillTodayIfExpiryIsInFuture() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256[] memory lockIDs = new uint256[](2);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        // staker creates two positions on deploymentDate, 19740
        lockIDs[0] = when_stakerCreatesPosition(
            staker, Position({ amount: convertLiskToSmallestDenomination(100), duration: 120 })
        );
        lockIDs[1] = when_stakerCreatesPosition(
            staker, Position({ amount: convertLiskToSmallestDenomination(1), duration: 100 })
        );

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        // rewards are claimed from lastClaimDate for the lock (19740) till today

        // today is 19830
        uint256 today = deploymentDate + 90;
        skip(90 days);

        uint256 expectedRewards = 8819747074459443653 + 80252925540556258;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;

        then_eventRewardsClaimedIsEmitted(lockIDs[0], 8819747074459443653);
        then_eventRewardsClaimedIsEmitted(lockIDs[1], 80252925540556258);
        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        balance = l2LiskToken.balanceOf(staker);

        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2Reward.lastClaimDate(lockIDs[1]), today);
        assertEq(balance, expectedBalance);
    }

    function test_claimRewards_pausedPositionsAreRewardedTillTodayWeightedAgainstThePausedLockingDuration() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256[] memory lockIDs = new uint256[](2);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        // staker creates two positions on deploymentDate, 19740
        lockIDs[0] = when_stakerCreatesPosition(
            staker, Position({ amount: convertLiskToSmallestDenomination(10), duration: 150 })
        );
        lockIDs[1] = when_stakerCreatesPosition(
            staker, Position({ amount: convertLiskToSmallestDenomination(10), duration: 300 })
        );

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        vm.startPrank(staker);
        l2Reward.pauseUnlocking(lockIDs);
        vm.stopPrank();

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        uint256 expectedRewards = 6575342465753424600 + 9863013698630136900;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;

        uint256 today = deploymentDate + 301;
        skip(301 days);

        then_eventRewardsClaimedIsEmitted(lockIDs[0], 6575342465753424600);
        then_eventRewardsClaimedIsEmitted(lockIDs[1], 9863013698630136900);
        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);

        balance = l2LiskToken.balanceOf(staker);

        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2Reward.lastClaimDate(lockIDs[1]), today);
        assertEq(balance, expectedBalance);
    }

    function test_claimRewards_multipleStakesWithSameAmountAndDurationAreEquallyRewardedCappedRewards() public {
        uint256[] memory lockIDs = new uint256[](5);

        uint256 funds = convertLiskToSmallestDenomination(1000);
        uint16 duration = 300;
        uint256 amount = convertLiskToSmallestDenomination(100);

        address[] memory stakers = given_anArrayOfStakersOfLength(5);
        given_accountHasBalance(address(this), funds);
        given_accountsHaveBalance(stakers, amount);
        // rewards are capped
        given_ownerHasFundedStaking(Funds({ amount: funds, duration: duration, delay: 1 }));

        skip(1 days);

        // All stakers create a position on deploymentDate + 1, 19741
        for (uint8 i = 0; i < stakers.length; i++) {
            lockIDs[i] = when_stakerCreatesPosition(stakers[i], Position(amount, duration));
        }

        uint256[] memory locksToClaim = new uint256[](1);

        uint256 expectedRewardsFor100Days = 27397260273972602700;

        for (uint8 i = 0; i < 3; i++) {
            skip(100 days);
            for (uint8 j = 0; j < stakers.length; j++) {
                locksToClaim[0] = lockIDs[j];
                then_eventRewardsClaimedIsEmitted(lockIDs[j], expectedRewardsFor100Days);
                vm.prank(stakers[j]);
                l2Reward.claimRewards(locksToClaim);
            }
        }

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        for (uint8 i = 0; i < 5; i++) {
            assertEq(l2LiskToken.balanceOf(stakers[i]), expectedRewardsFor100Days * 3);
        }
    }

    function test_claimRewards_multipleStakesWithSameAmountAndDurationAreEquallyRewarded() public {
        uint256[] memory lockIDs = new uint256[](5);

        uint256 funds = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(1000);
        uint256 duration = 300;

        address[] memory stakers = given_anArrayOfStakersOfLength(5);
        given_accountHasBalance(address(this), funds);
        given_accountsHaveBalance(stakers, amount);
        given_ownerHasFundedStaking(Funds({ amount: funds, duration: 365, delay: 1 }));

        skip(1 days);

        // All stakers create a position on deploymentDate + 1, 19741
        for (uint8 i = 0; i < stakers.length; i++) {
            lockIDs[i] = when_stakerCreatesPosition(stakers[i], Position(amount, duration));
        }

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        uint256[] memory locksToClaim = new uint256[](1);

        uint256 expectedRewardsFor100Days = 54794520547945205400;

        for (uint8 i = 0; i < 3; i++) {
            skip(100 days);
            for (uint8 j = 0; j < stakers.length; j++) {
                locksToClaim[0] = lockIDs[j];
                then_eventRewardsClaimedIsEmitted(lockIDs[j], expectedRewardsFor100Days);

                vm.prank(stakers[j]);
                l2Reward.claimRewards(locksToClaim);
            }
        }

        skip(1 days);

        // All positions are expired, reward is zero
        for (uint8 i = 0; i < stakers.length; i++) {
            locksToClaim[0] = lockIDs[i];
            then_eventRewardsClaimedIsEmitted(lockIDs[i], 0);

            vm.prank(stakers[i]);
            l2Reward.claimRewards(locksToClaim);
        }

        for (uint8 i = 0; i < 5; i++) {
            assertEq(l2LiskToken.balanceOf(stakers[i]), expectedRewardsFor100Days * 3);
        }
    }

    function test_claimRewards_multipleStakesWithDifferentAmountForSimilarDurationAreRewardedAccordinglyWhenUnlocked()
        public
    {
        uint256[] memory lockIDs = new uint256[](3);

        uint256 funds = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(1000);
        uint256 duration = 300;

        address[] memory stakers = given_anArrayOfStakersOfLength(3);
        given_accountHasBalance(address(this), funds);
        for (uint8 i = 0; i < stakers.length; i++) {
            given_accountHasBalance(stakers[i], amount * (i + 1));
        }
        given_ownerHasFundedStaking(Funds({ amount: funds, duration: 365, delay: 1 }));

        // All stakers create a position on deploymentDate, 19740
        for (uint8 i = 0; i < stakers.length; i++) {
            lockIDs[i] =
                when_stakerCreatesPosition(stakers[i], Position({ amount: amount * (i + 1), duration: duration }));
        }

        uint256[3] memory expectedRewardsOnDeletion =
            [uint256(136529680365296803455), uint256(273059360730593607209), uint256(409589041095890410664)];

        uint256[] memory positionsToDelete = new uint256[](1);

        skip(350 days);
        for (uint8 i = 0; i < stakers.length; i++) {
            then_eventRewardsClaimedIsEmitted(lockIDs[i], expectedRewardsOnDeletion[i]);

            vm.startPrank(stakers[i]);
            positionsToDelete[0] = lockIDs[i];

            l2Reward.deletePositions(positionsToDelete);
            vm.stopPrank();

            assertEq(l2LiskToken.balanceOf(stakers[i]), (amount * (i + 1)) + expectedRewardsOnDeletion[i]);
        }
    }

    function test_claimRewards_multipleStakesWithSameAmountForDifferentDurationAreRewardedAsPerTheWeight() public {
        uint256[] memory lockIDs = new uint256[](2);

        uint256 funds = convertLiskToSmallestDenomination(100);
        uint256 amount = convertLiskToSmallestDenomination(100);
        uint256 duration = 100;

        address[] memory stakers = given_anArrayOfStakersOfLength(2);
        given_accountHasBalance(address(this), funds);
        given_accountsHaveBalance(stakers, amount);
        given_ownerHasFundedStaking(Funds({ amount: funds, duration: 365, delay: 1 }));

        skip(1 days);

        // All stakers create a position on deploymentDate + 1, 19741
        for (uint8 i = 0; i < stakers.length; i++) {
            lockIDs[i] =
                when_stakerCreatesPosition(stakers[i], Position({ amount: amount, duration: duration * (i + 1) }));
        }

        uint256[] memory locksToClaim = new uint256[](1);

        skip(2 days);

        uint256[2] memory expectedRewardsAfter2Days = [uint256(228234144255585589), uint256(319711061223866463)];

        for (uint8 i = 0; i < stakers.length; i++) {
            locksToClaim[0] = lockIDs[i];

            then_eventRewardsClaimedIsEmitted(lockIDs[i], expectedRewardsAfter2Days[i]);
            when_rewardsAreClaimedByStaker(stakers[i], locksToClaim);
        }

        skip(49 days);

        uint256[2] memory expectedRewardsAfter51Days = [uint256(5484172493642193937), uint256(7940485040604381337)];

        for (uint8 i = 0; i < stakers.length; i++) {
            locksToClaim[0] = lockIDs[i];

            then_eventRewardsClaimedIsEmitted(lockIDs[i], expectedRewardsAfter51Days[i]);
            when_rewardsAreClaimedByStaker(stakers[i], locksToClaim);
        }

        skip(49 days);

        uint256[2] memory expectedRewardsAfter100Days = [uint256(5214765059512775305), uint256(8209892474733799969)];

        for (uint8 i = 0; i < stakers.length; i++) {
            locksToClaim[0] = lockIDs[i];

            then_eventRewardsClaimedIsEmitted(lockIDs[i], expectedRewardsAfter100Days[i]);
            when_rewardsAreClaimedByStaker(stakers[i], locksToClaim);
        }

        skip(100 days);
        uint256[2] memory expectedRewardsAfter200Days = [uint256(0), uint256(27397260273972602700)];

        for (uint8 i = 0; i < stakers.length; i++) {
            locksToClaim[0] = lockIDs[i];

            then_eventRewardsClaimedIsEmitted(lockIDs[i], expectedRewardsAfter200Days[i]);
            when_rewardsAreClaimedByStaker(stakers[i], locksToClaim);
        }
    }

    function test_claimRewards_rewardClaimedAgainstExpiredPositionIsZeroIfAlreadyClaimedAfterExpiry() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256[] memory lockIDs = new uint256[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        // staker creates a position on deploymentDate, 19740
        lockIDs[0] = when_stakerCreatesPosition(
            staker, Position({ amount: convertLiskToSmallestDenomination(100), duration: 120 })
        );

        // rewards are claimed from lastClaimDate for the lock (19740) till expiry day
        uint256 today = deploymentDate + 150;
        uint256 expectedRewards = 11.9 * 10 ** 18;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;

        skip(150 days);

        // staker claims rewards on, 19890
        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewards);
        when_rewardsAreClaimedByStaker(staker, lockIDs);

        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2LiskToken.balanceOf(staker), expectedBalance);

        skip(5 days);
        today += 5;

        // staker claims again on, 19895
        then_eventRewardsClaimedIsEmitted(lockIDs[0], 0);
        when_rewardsAreClaimedByStaker(staker, lockIDs);

        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
    }

    function test_deletePositions_onlyOwnerCanDeleteALockingPosition() public {
        address staker = address(0x1);
        uint256[] memory lockIDs = new uint256[](1);
        lockIDs[0] = 1;

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");
        l2Reward.deletePositions(lockIDs);
    }

    function test_deletePositions_onlyExistingLockingPositionCanBeDeletedByAnOwner() public {
        address staker = address(0x1);
        uint256[] memory lockIDs = new uint256[](1);
        lockIDs[0] = 1;

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Locking position does not exist");
        vm.prank(staker);
        l2Reward.deletePositions(lockIDs);
    }

    function test_deletePositions_onlyExpiredLockingPositionsCanBeDeleted() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256[] memory lockIDs = new uint256[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        // staker creates a position on deploymentDate, 19740
        lockIDs[0] = when_stakerCreatesPosition(
            staker, Position({ amount: convertLiskToSmallestDenomination(100), duration: 120 })
        );

        skip(30 days);

        vm.expectRevert("L2Staking: locking duration active, can not unlock");
        vm.prank(staker);
        l2Reward.deletePositions(lockIDs);
    }

    function test_deletePositions_forMultipleStakesIssuesRewardAndUnlocksPositions() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256[] memory lockIDs = new uint256[](2);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        skip(1 days);

        // staker creates two positions on deploymentDate + 1, 19741
        for (uint8 i = 0; i < 2; i++) {
            lockIDs[i] = when_stakerCreatesPosition(
                staker, Position({ amount: convertLiskToSmallestDenomination(100), duration: 120 })
            );
        }

        skip(150 days);

        uint256 expectedRewardsPerStake = 6 * 10 ** 18;

        // locked amount gets unlocked
        uint256 expectedBalance =
            l2LiskToken.balanceOf(staker) + expectedRewardsPerStake * 2 + convertLiskToSmallestDenomination(100) * 2;

        // staker deletes position
        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewardsPerStake);
        then_eventLockingPositionDeletedIsEmitted(lockIDs[0]);
        then_eventRewardsClaimedIsEmitted(lockIDs[1], expectedRewardsPerStake);
        then_eventLockingPositionDeletedIsEmitted(lockIDs[1]);
        vm.prank(staker);
        l2Reward.deletePositions(lockIDs);

        balance = l2LiskToken.balanceOf(staker);

        assertEq(l2Reward.lastClaimDate(lockIDs[0]), 0);
        assertEq(l2Reward.lastClaimDate(lockIDs[1]), 0);
        assertEq(balance, expectedBalance);
    }

    function test_pauseUnlocking_onlyOwnerCanPauseALockingPosition() public {
        address staker = address(0x1);
        uint256[] memory lockIDs = new uint256[](1);
        lockIDs[0] = 1;

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");
        l2Reward.deletePositions(lockIDs);
    }

    function test_pauseUnlocking_onlyExisitingLockingPositionCanBePausedByAnOwner() public {
        address staker = address(0x1);
        uint256[] memory lockIDs = new uint256[](1);
        lockIDs[0] = 1;

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Locking position does not exist");
        vm.prank(staker);
        l2Reward.pauseUnlocking(lockIDs);
    }

    function test_pauseUnlocking_lockingPositionCanBePausedOnlyOnce() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256[] memory lockIDs = new uint256[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        // staker creates a position on deploymentDate, 19740
        lockIDs[0] = when_stakerCreatesPosition(
            staker, Position({ amount: convertLiskToSmallestDenomination(100), duration: 120 })
        );

        then_eventRewardsClaimedIsEmitted(lockIDs[0], 0);

        vm.prank(staker);
        then_eventLockingPositionPausedIsEmitted(lockIDs[0]);
        l2Reward.pauseUnlocking(lockIDs);

        vm.expectRevert("L2Staking: remaining duration is already paused");
        vm.prank(staker);
        l2Reward.pauseUnlocking(lockIDs);
    }

    function test_pauseUnlocking_issuesRewardAndUpdatesGlobalUnlockAmounts() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256[] memory lockIDs = new uint256[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        // staker creates a position on deploymentDate, 19740
        lockIDs[0] = when_stakerCreatesPosition(
            staker, Position({ amount: convertLiskToSmallestDenomination(100), duration: 120 })
        );

        skip(75 days);
        uint256 today = deploymentDate + 75;

        uint256 expectedRewards = 7.4 * 10 ** 18;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;
        uint256 expectedPausedLockingDuration = 45;

        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewards);
        then_eventLockingPositionPausedIsEmitted(lockIDs[0]);
        vm.prank(staker);
        l2Reward.pauseUnlocking(lockIDs);

        balance = l2LiskToken.balanceOf(staker);

        IL2LockingPosition.LockingPosition memory lockingPosition = l2LockingPosition.getLockingPosition(lockIDs[0]);

        assertEq(balance, expectedBalance);
        assertEq(l2Reward.pendingUnlockAmount(), 0);
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + 120), 0);
        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(lockingPosition.pausedLockingDuration, expectedPausedLockingDuration);
    }

    function test_pauseUnlocking_forMultipleStakesIssuesRewardsAndUpdatesLockingPosition() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256[] memory lockIDs = new uint256[](2);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        skip(1 days);

        // staker creates two positions on deploymentDate + 1, 19741
        for (uint8 i = 0; i < 2; i++) {
            lockIDs[i] = when_stakerCreatesPosition(
                staker, Position({ amount: convertLiskToSmallestDenomination(100), duration: 120 })
            );
        }

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        skip(75 days);
        uint256 today = deploymentDate + 1 + 75;

        uint256 expectedRewardsPerStake = 3.75 * 10 ** 18;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewardsPerStake * 2;
        uint256 expectedPausedLockingDuration = 45;

        // staker pauses positions
        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewardsPerStake);
        then_eventLockingPositionPausedIsEmitted(lockIDs[0]);
        then_eventRewardsClaimedIsEmitted(lockIDs[1], expectedRewardsPerStake);
        then_eventLockingPositionPausedIsEmitted(lockIDs[1]);
        vm.prank(staker);
        l2Reward.pauseUnlocking(lockIDs);

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        balance = l2LiskToken.balanceOf(staker);

        assertEq(balance, expectedBalance);
        assertEq(l2Reward.pendingUnlockAmount(), 0);
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + 120), 0);
        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2Reward.lastClaimDate(lockIDs[1]), today);
        assertEq(l2LockingPosition.getLockingPosition(lockIDs[0]).pausedLockingDuration, expectedPausedLockingDuration);
        assertEq(l2LockingPosition.getLockingPosition(lockIDs[1]).pausedLockingDuration, expectedPausedLockingDuration);
    }

    function test_resumeUnlockingCountdown_onlyOwnerCanResumeUnlockingForALockingPosition() public {
        address staker = address(0x1);
        uint256[] memory lockIDs = new uint256[](1);
        lockIDs[0] = 1;

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");
        l2Reward.resumeUnlockingCountdown(lockIDs);
    }

    function test_resumeUnlockingCountdown_onlyExisitingLockingPositionCanBeResumedByAnOwner() public {
        address staker = address(0x1);
        uint256[] memory lockIDs = new uint256[](1);
        lockIDs[0] = 1;

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Locking position does not exist");
        vm.prank(staker);
        l2Reward.resumeUnlockingCountdown(lockIDs);
    }

    function test_resumeUnlockingCountdown_onlyPausedLockingPositionCanBeResumed() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256[] memory lockIDs = new uint256[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        // staker creates a position on deploymentDate, 19740
        lockIDs[0] = when_stakerCreatesPosition(
            staker, Position({ amount: convertLiskToSmallestDenomination(100), duration: 120 })
        );

        vm.expectRevert("L2Staking: countdown is not paused");
        vm.prank(staker);
        l2Reward.resumeUnlockingCountdown(lockIDs);
    }

    function test_resumeUnlockingCountdown_issuesRewardAndUpdatesGlobalUnlockAmount() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256[] memory lockIDs = new uint256[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        lockIDs[0] = when_stakerCreatesPosition(
            staker, Position({ amount: convertLiskToSmallestDenomination(100), duration: 120 })
        );

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        skip(50 days);
        uint256 today = deploymentDate + 50;

        uint256 expectedRewardsWhenPausing = 4.9 * 10 ** 18;

        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewardsWhenPausing);

        // staker pauses the position
        vm.prank(staker);
        l2Reward.pauseUnlocking(lockIDs);

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        uint256 expectedPausedLockingDuration = 70;
        uint256 expectedRewardsWhenResuming = convertLiskToSmallestDenomination(5);

        balance = l2LiskToken.balanceOf(staker);

        skip(50 days);
        today = deploymentDate + 100;

        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewardsWhenResuming);
        then_eventUnlockingCountdownResumedIsEmitted(lockIDs[0]);
        vm.prank(staker);
        l2Reward.resumeUnlockingCountdown(lockIDs);

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        uint256 expectedBalance = balance + expectedRewardsWhenResuming;

        IL2LockingPosition.LockingPosition memory lockingPosition = l2LockingPosition.getLockingPosition(lockIDs[0]);

        assertEq(lockingPosition.expDate, today + expectedPausedLockingDuration);
        assertEq(l2Reward.pendingUnlockAmount(), convertLiskToSmallestDenomination(100));
        assertEq(
            l2Reward.dailyUnlockedAmounts(today + expectedPausedLockingDuration), convertLiskToSmallestDenomination(100)
        );
        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2LiskToken.balanceOf(staker), expectedBalance);
    }

    function test_resumeUnlockingCountdown_forMultipleStakesIssuesRewardsAndUpdatesLockingPosition() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 duration = 120;
        uint256[] memory lockIDs = new uint256[](2);
        uint256 amount = convertLiskToSmallestDenomination(100);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        skip(1 days);

        // staker creates two positions on deploymentDate + 1, 19741
        for (uint8 i = 0; i < 2; i++) {
            lockIDs[i] = when_stakerCreatesPosition(staker, Position({ amount: amount, duration: duration }));
        }

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        // staker pauses the position on 19741, rewards when pausing is zero
        then_eventRewardsClaimedIsEmitted(lockIDs[0], 0);
        then_eventRewardsClaimedIsEmitted(lockIDs[1], 0);
        vm.prank(staker);
        l2Reward.pauseUnlocking(lockIDs);

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        assertEq(l2Reward.pendingUnlockAmount(), 0);
        assertEq(l2Reward.dailyUnlockedAmounts(19741), 0);
        assertEq(l2Reward.totalAmountLocked(), amount * lockIDs.length);

        balance = l2LiskToken.balanceOf(staker);

        skip(100 days);

        uint256 expectedRewardsPerStake = 5 * 10 ** 18;
        uint256 today = deploymentDate + 101;
        uint256 expectedBalance = expectedRewardsPerStake * lockIDs.length + balance;

        // staker resumes the positions
        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewardsPerStake);
        then_eventUnlockingCountdownResumedIsEmitted(lockIDs[0]);
        then_eventRewardsClaimedIsEmitted(lockIDs[1], expectedRewardsPerStake);
        then_eventUnlockingCountdownResumedIsEmitted(lockIDs[1]);
        vm.prank(staker);
        l2Reward.resumeUnlockingCountdown(lockIDs);

        balance = l2LiskToken.balanceOf(staker);

        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2Reward.lastClaimDate(lockIDs[1]), today);
        assertEq(balance, expectedBalance);
        assertEq(l2LockingPosition.getLockingPosition(lockIDs[0]).expDate, today + duration);
        assertEq(l2LockingPosition.getLockingPosition(lockIDs[1]).expDate, today + duration);

        assertEq(l2Reward.pendingUnlockAmount(), amount * lockIDs.length);
        assertEq(l2Reward.dailyUnlockedAmounts(today + duration), amount * lockIDs.length);
        assertEq(l2Reward.totalAmountLocked(), amount * lockIDs.length);
        assertEq(l2Reward.pendingUnlockAmount(), l2Reward.totalAmountLocked());
    }

    function test_increaseLockingAmount_onlyOwnerCanIncreaseAmountForALockingPosition() public {
        address staker = address(0x1);
        L2Reward.IncreasedAmount[] memory increasingAmounts = new L2Reward.IncreasedAmount[](1);
        increasingAmounts[0].lockID = 1;
        increasingAmounts[0].amountIncrease = convertLiskToSmallestDenomination(10);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");
        l2Reward.increaseLockingAmount(increasingAmounts);
    }

    function test_increaseLockingAmount_amountCanOnlyBeIncreasedByAnOwnerForAnExistingLockingPosition() public {
        address staker = address(0x1);
        L2Reward.IncreasedAmount[] memory increasingAmounts = new L2Reward.IncreasedAmount[](1);
        increasingAmounts[0].lockID = 1;
        increasingAmounts[0].amountIncrease = convertLiskToSmallestDenomination(10);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Locking position does not exist");
        vm.prank(staker);
        l2Reward.increaseLockingAmount(increasingAmounts);
    }

    function test_increaseLockingAmount_increasedAmountShouldBeGreaterThanZero() public {
        address staker = address(0x1);
        L2Reward.IncreasedAmount[] memory increasingAmounts = new L2Reward.IncreasedAmount[](1);
        increasingAmounts[0].lockID = 1;
        increasingAmounts[0].amountIncrease = 0;

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Increased amount should be greater than zero");
        vm.prank(staker);
        l2Reward.increaseLockingAmount(increasingAmounts);
    }

    function test_increaseLockingAmount_forActivePositionIncreasesLockedAmountAndWeightByRemainingDurationAndClaimsRewards(
    )
        public
    {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(100);
        L2Reward.IncreasedAmount[] memory increasingAmounts = new L2Reward.IncreasedAmount[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        increasingAmounts[0].lockID = when_stakerCreatesPosition(staker, Position({ amount: amount, duration: 120 }));

        skip(50 days);

        increasingAmounts[0].amountIncrease = convertLiskToSmallestDenomination(35);
        uint256 remainingDuration = 70;
        uint256 expectedTotalWeight = (27000 * 10 ** 18) - (5000 * 10 ** 18)
            + (increasingAmounts[0].amountIncrease * (remainingDuration + l2Reward.OFFSET()));

        balance = l2LiskToken.balanceOf(staker);

        uint256 expectedReward = 4.9 * 10 ** 18;

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), increasingAmounts[0].amountIncrease);
        then_eventRewardsClaimedIsEmitted(increasingAmounts[0].lockID, expectedReward);
        then_eventLockingAmountIncreasedIsEmitted(increasingAmounts[0].lockID, increasingAmounts[0].amountIncrease);
        l2Reward.increaseLockingAmount(increasingAmounts);
        vm.stopPrank();

        assertEq(
            l2LockingPosition.getLockingPosition(increasingAmounts[0].lockID).amount,
            amount + increasingAmounts[0].amountIncrease
        );

        assertEq(l2Reward.totalAmountLocked(), amount + increasingAmounts[0].amountIncrease);
        assertEq(l2Reward.totalWeight(), expectedTotalWeight);
        assertEq(l2LiskToken.balanceOf(staker), balance + expectedReward - increasingAmounts[0].amountIncrease);
        assertEq(l2Reward.pendingUnlockAmount(), convertLiskToSmallestDenomination(135));
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + 120), convertLiskToSmallestDenomination(135));
    }

    function test_increaseLockingAmount_forPausedPositionIncreasesTotalWeightByPausedLockingDurationAndClaimsRewards()
        public
    {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(100);
        uint256[] memory lockIDs = new uint256[](1);
        L2Reward.IncreasedAmount[] memory increasingAmounts = new L2Reward.IncreasedAmount[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        increasingAmounts[0].lockID = when_stakerCreatesPosition(staker, Position({ amount: amount, duration: 120 }));

        lockIDs[0] = increasingAmounts[0].lockID;
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        // pausedLockingDuration set to 120
        vm.prank(staker);
        l2Reward.pauseUnlocking(lockIDs);
        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        skip(50 days);

        increasingAmounts[0].amountIncrease = convertLiskToSmallestDenomination(35);

        uint256 totalWeight = l2Reward.totalWeight();

        uint256 totalWeightIncrease = increasingAmounts[0].amountIncrease * (120 + l2Reward.OFFSET());

        balance = l2LiskToken.balanceOf(staker);

        uint256 expectedReward = 4.9 * 10 ** 18;

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), increasingAmounts[0].amountIncrease);
        then_eventRewardsClaimedIsEmitted(increasingAmounts[0].lockID, expectedReward);
        then_eventLockingAmountIncreasedIsEmitted(increasingAmounts[0].lockID, increasingAmounts[0].amountIncrease);
        l2Reward.increaseLockingAmount(increasingAmounts);
        vm.stopPrank();

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        assertEq(l2LockingPosition.getLockingPosition(lockIDs[0]).amount, amount + increasingAmounts[0].amountIncrease);

        assertEq(l2Reward.totalAmountLocked(), amount + increasingAmounts[0].amountIncrease);
        assertEq(l2LiskToken.balanceOf(staker), balance + expectedReward - increasingAmounts[0].amountIncrease);
        assertEq(l2Reward.totalWeight(), totalWeightIncrease + totalWeight);
    }

    function test_increaseLockingAmount_updatesTotalAmountLockedAndImpactsRewardCapping() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(10);
        L2Reward.IncreasedAmount[] memory increasingAmounts = new L2Reward.IncreasedAmount[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        uint256 dailyRewards = given_ownerHasFundedStaking(
            Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 })
        );

        skip(10 days);

        // staker stakes on 19750
        // daily rewards from 19740 to 19749 are capped due to zero total amount unlocked
        increasingAmounts[0].lockID = when_stakerCreatesPosition(staker, Position({ amount: amount, duration: 120 }));

        // daily rewards are capped to zero
        for (uint256 i = deploymentDate; i < deploymentDate + 10; i++) {
            assertEq(l2Reward.dailyRewards(i), 0);
        }

        skip(10 days);

        // staker increase amount on 19760
        // "daily rewards from 19750 to 19759 are capped due too low total locked amount
        uint256 cappedRewards = amount / 365;
        increasingAmounts[0].amountIncrease = 90;

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), increasingAmounts[0].amountIncrease);

        then_eventRewardsClaimedIsEmitted(increasingAmounts[0].lockID, 273972602739726020);
        then_eventLockingAmountIncreasedIsEmitted(increasingAmounts[0].lockID, increasingAmounts[0].amountIncrease);

        l2Reward.increaseLockingAmount(increasingAmounts);
        vm.stopPrank();

        assertEq(
            l2LockingPosition.getLockingPosition(increasingAmounts[0].lockID).amount,
            amount + increasingAmounts[0].amountIncrease
        );

        // daily rewards are capped
        for (uint256 i = 19750; i < 19760; i++) {
            assertEq(l2Reward.dailyRewards(i), cappedRewards);
        }

        skip(10);

        // staker stakes on 19770
        // rewards from 19760 to 19769 are not capped  as the total amount locked is 100 in this time window which is
        // high enough
        vm.startPrank(staker);
        // daily rewards are capped
        for (uint256 i = 19760; i < 19770; i++) {
            assertEq(l2Reward.dailyRewards(i), dailyRewards);
        }
        vm.stopPrank();
    }

    function test_increaseLockingAmount_forMultipleStakesIncreasesLockingAmountAndClaimRewards() public {
        address staker = address(0x1);

        uint256 funds = convertLiskToSmallestDenomination(35);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(100);
        uint256 amountIncrease = convertLiskToSmallestDenomination(65);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance * 2);
        given_ownerHasFundedStaking(Funds({ amount: funds, duration: 350, delay: 1 }));

        L2Reward.IncreasedAmount[] memory increasingAmounts = new L2Reward.IncreasedAmount[](2);
        uint256[] memory lockIDs = new uint256[](2);

        skip(1 days);

        for (uint8 i = 0; i < increasingAmounts.length; i++) {
            lockIDs[i] = when_stakerCreatesPosition(staker, Position({ amount: amount, duration: 120 }));

            // sets the amount to be increased
            increasingAmounts[i].lockID = lockIDs[i];
            increasingAmounts[i].amountIncrease = amountIncrease;
        }

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        skip(50 days);

        uint256 expectedRewardPerStakeFor50Days = 2.5 * 10 ** 18;

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amountIncrease * 2);
        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewardPerStakeFor50Days);
        then_eventLockingAmountIncreasedIsEmitted(increasingAmounts[0].lockID, increasingAmounts[0].amountIncrease);
        then_eventRewardsClaimedIsEmitted(lockIDs[1], expectedRewardPerStakeFor50Days);
        then_eventLockingAmountIncreasedIsEmitted(increasingAmounts[1].lockID, increasingAmounts[1].amountIncrease);

        l2Reward.increaseLockingAmount(increasingAmounts);
        vm.stopPrank();

        assertEq(l2LockingPosition.getLockingPosition(lockIDs[0]).amount, amount + amountIncrease);
        assertEq(l2LockingPosition.getLockingPosition(lockIDs[1]).amount, amount + amountIncrease);

        assertEq(l2Reward.totalAmountLocked(), (amount + amountIncrease) * 2);
        assertEq(
            l2LiskToken.balanceOf(address(l2Reward)),
            convertLiskToSmallestDenomination(35) - (2 * expectedRewardPerStakeFor50Days)
        );

        skip(50 days);

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewardPerStakeFor50Days);
        then_eventRewardsClaimedIsEmitted(lockIDs[1], expectedRewardPerStakeFor50Days);
        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);

        skip(30 days);

        uint256 expectedRewardsPerStakeFor30Days = 1 * 10 ** 18;
        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewardsPerStakeFor30Days);
        then_eventRewardsClaimedIsEmitted(lockIDs[1], expectedRewardsPerStakeFor30Days);
        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);

        uint256 totalRewardsClaimedByStaker = expectedRewardPerStakeFor50Days * 4 + expectedRewardsPerStakeFor30Days * 2;

        assertEq(l2LiskToken.balanceOf(address(l2Reward)), funds - totalRewardsClaimedByStaker);
    }

    function test_extendDuration_onlyOwnerCanExtendDurationForALockingPosition() public {
        address staker = address(0x1);
        L2Reward.ExtendedDuration[] memory extensions = new L2Reward.ExtendedDuration[](1);
        extensions[0].lockID = 1;
        extensions[0].durationExtension = 1;

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");
        l2Reward.extendDuration(extensions);
    }

    function test_extendDuration_durationCanOnlyBeExtendedByAnOwnerForAnExistingLockingPositions() public {
        address staker = address(0x1);
        L2Reward.ExtendedDuration[] memory extensions = new L2Reward.ExtendedDuration[](1);
        extensions[0].lockID = 1;
        extensions[0].durationExtension = 1;

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Locking position does not exist");

        vm.prank(staker);
        l2Reward.extendDuration(extensions);
    }

    function test_extendDuration_extendedDurationShouldBeGreaterThanZero() public {
        address staker = address(0x1);
        L2Reward.ExtendedDuration[] memory extensions = new L2Reward.ExtendedDuration[](1);
        extensions[0].lockID = 1;
        extensions[0].durationExtension = 0;

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Extended duration should be greater than zero");

        vm.prank(staker);
        l2Reward.extendDuration(extensions);
    }

    function test_extendDuration_updatesGlobalsAndClaimRewardsForActivePositionWithExpiryInFuture() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 duration = 120;
        uint256 amount = convertLiskToSmallestDenomination(100);
        L2Reward.ExtendedDuration[] memory extensions = new L2Reward.ExtendedDuration[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        extensions[0].lockID = when_stakerCreatesPosition(staker, Position(amount, duration));

        skip(50 days);

        extensions[0].durationExtension = 50;

        uint256 weightIncrease = amount * extensions[0].durationExtension;
        balance = l2LiskToken.balanceOf(staker);

        uint256 expectedReward = 4.9 * 10 ** 18;

        vm.startPrank(staker);
        then_eventRewardsClaimedIsEmitted(extensions[0].lockID, expectedReward);
        then_eventLockingDurationExtendedIsEmitted(extensions[0].lockID, extensions[0].durationExtension);
        l2Reward.extendDuration(extensions);
        vm.stopPrank();

        uint256 expectedExpiryDate = deploymentDate + duration + extensions[0].durationExtension;

        assertEq(l2LockingPosition.getLockingPosition(extensions[0].lockID).expDate, expectedExpiryDate);

        assertEq(l2Reward.totalWeight(), (27000 * 10 ** 18) - (5000 * 10 ** 18) + weightIncrease);
        assertEq(l2LiskToken.balanceOf(staker), balance + expectedReward);
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + duration), 0);
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + duration + extensions[0].durationExtension), amount);
    }

    function test_extendDuration_updatesGlobalsAndClaimRewardsForExpiredPositions() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 duration = 120;
        uint256 amount = convertLiskToSmallestDenomination(100);
        L2Reward.ExtendedDuration[] memory extensions = new L2Reward.ExtendedDuration[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        extensions[0].lockID = when_stakerCreatesPosition(staker, Position(amount, duration));

        skip(150 days);

        extensions[0].durationExtension = 50;
        // For expired positions, amount is effectively re-locked for the extended duration.
        uint256 weightIncrease = (amount * extensions[0].durationExtension) + (amount * l2Reward.OFFSET());
        uint256 expectedReward = 11.9 * 10 ** 18;

        vm.startPrank(staker);
        then_eventRewardsClaimedIsEmitted(extensions[0].lockID, expectedReward);
        then_eventLockingDurationExtendedIsEmitted(extensions[0].lockID, extensions[0].durationExtension);
        l2Reward.extendDuration(extensions);
        vm.stopPrank();

        assertEq(l2LiskToken.balanceOf(staker), balance + expectedReward - amount);
        assertEq(l2Reward.totalWeight(), weightIncrease);

        assertEq(l2Reward.totalAmountLocked(), amount);
        assertEq(l2Reward.pendingUnlockAmount(), amount);

        // today is assumed to be the expiry date
        assertEq(l2Reward.dailyUnlockedAmounts(l2Reward.todayDay() + extensions[0].durationExtension), amount);
        assertEq(
            l2LockingPosition.getLockingPosition(extensions[0].lockID).expDate,
            l2Reward.todayDay() + extensions[0].durationExtension
        );

        skip(60 days);

        uint256[] memory lockIDs = new uint256[](1);
        lockIDs[0] = extensions[0].lockID;

        uint256 expectedRewardAfterExtension = 5 * 10 ** 18;
        // staker claims rewards, after expiry date
        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewardAfterExtension);
        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        // staker unlocks rewards
        then_eventRewardsClaimedIsEmitted(lockIDs[0], 0);
        vm.prank(staker);
        l2Reward.deletePositions(lockIDs);

        assertEq(l2LiskToken.balanceOf(staker), balance + expectedReward + expectedRewardAfterExtension);
    }

    function test_extendDuration_updatesGlobalsAndClaimRewardsForPausedPositions() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 duration = 120;
        uint256 amount = convertLiskToSmallestDenomination(100);
        L2Reward.ExtendedDuration[] memory extensions = new L2Reward.ExtendedDuration[](1);
        uint256[] memory lockIDs = new uint256[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        extensions[0].lockID = l2Reward.createPosition(amount, duration);
        lockIDs[0] = extensions[0].lockID;
        l2Reward.pauseUnlocking(lockIDs);
        vm.stopPrank();

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        skip(120 days);

        extensions[0].durationExtension = 50;

        uint256 weightIncrease = amount * extensions[0].durationExtension;
        uint256 expectedTotalWeight = l2Reward.totalWeight() + weightIncrease;
        uint256 expectedReward = 11.9 * 10 ** 18;

        balance = l2LiskToken.balanceOf(staker);

        vm.startPrank(staker);
        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedReward);
        then_eventLockingDurationExtendedIsEmitted(lockIDs[0], extensions[0].durationExtension);
        l2Reward.extendDuration(extensions);
        vm.stopPrank();

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        // expDate does not change for paused position
        assertEq(l2LockingPosition.getLockingPosition(extensions[0].lockID).expDate, deploymentDate + duration);
        // pausedLockingDuration is extended by 50 days
        assertEq(
            l2LockingPosition.getLockingPosition(extensions[0].lockID).pausedLockingDuration,
            duration + extensions[0].durationExtension
        );

        assertEq(l2LiskToken.balanceOf(staker), balance + expectedReward);
        assertEq(l2Reward.totalWeight(), expectedTotalWeight);
    }

    function test_extendDuration_forMultipleStakesUpdatesTotalWeightAndClaimRewards() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 duration = 120;
        uint256 amount = convertLiskToSmallestDenomination(100);
        uint256 durationExtension = 50;
        L2Reward.ExtendedDuration[] memory extensions = new L2Reward.ExtendedDuration[](2);
        uint256[] memory lockIDs = new uint256[](2);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        skip(1 days);

        for (uint8 i = 0; i < extensions.length; i++) {
            lockIDs[i] = when_stakerCreatesPosition(staker, Position(amount, duration));

            //sets the extension in duration
            extensions[i].lockID = lockIDs[i];
            extensions[i].durationExtension = durationExtension;
        }

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        uint256 totalWeightBeforeExtension = l2Reward.totalWeight();
        uint256 expectedReward = 2.5 * 10 ** 18;

        skip(50 days);

        // after 50 days extend duration for 50 days, given the locked amount stays same total weight remains same
        vm.startPrank(staker);
        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedReward);
        then_eventRewardsClaimedIsEmitted(lockIDs[1], expectedReward);
        l2Reward.extendDuration(extensions);
        vm.stopPrank();

        assertEq(l2Reward.totalWeight(), totalWeightBeforeExtension);
        assertEq(
            l2LockingPosition.getLockingPosition(lockIDs[0]).expDate, deploymentDate + 1 + duration + durationExtension
        );

        uint256 expectedRewardsFor20Days = 1 * 10 ** 18;

        skip(20 days);
        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewardsFor20Days);
        then_eventRewardsClaimedIsEmitted(lockIDs[1], expectedRewardsFor20Days);
        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));
    }

    function test_initiateFastUnlock_onlyOwnerCanUnlockAPosition() public {
        address staker = address(0x1);
        uint256[] memory lockIDs = new uint256[](1);
        lockIDs[0] = 1;

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");
        l2Reward.initiateFastUnlock(lockIDs);
    }

    function test_initiateFastUnlock_onlyExistingLockingPositionCanBeUnlockedByAnOwner() public {
        address staker = address(0x1);
        uint256[] memory lockIDs = new uint256[](1);
        lockIDs[0] = 1;

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: Locking position does not exist");
        l2Reward.initiateFastUnlock(lockIDs);
    }

    function test_initiateFastUnlock_forActivePositionAddsPenaltyAsRewardAlsoUpdatesGlobalsAndClaimRewardsAlsoReducesStakedAmountByPenalty(
    )
        public
    {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(100);
        uint256 duration = 120;

        uint256[] memory lockIDs = new uint256[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        lockIDs[0] = when_stakerCreatesPosition(staker, Position(amount, duration));

        skip(50 days);

        uint256 reward = 4.9e18;
        uint256 penalty = 4589041095890410958;

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        vm.startPrank(staker);
        then_eventRewardsClaimedIsEmitted(lockIDs[0], reward);
        then_eventFastUnlockInitiatedIsEmitted(lockIDs[0]);
        l2Reward.initiateFastUnlock(lockIDs);
        vm.stopPrank();

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        uint256 expectedTotalWeight = (l2Staking.FAST_UNLOCK_DURATION() + l2Reward.OFFSET()) * (amount - penalty);

        assertEq(l2LiskToken.balanceOf(address(l2Reward)), convertLiskToSmallestDenomination(35) - reward + penalty);
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + duration), 0);
        assertEq(
            l2Reward.dailyUnlockedAmounts(deploymentDate + 50 + l2Staking.FAST_UNLOCK_DURATION()), amount - penalty
        );
        assertEq(l2Reward.totalAmountLocked(), amount - penalty);
        assertEq(l2Reward.pendingUnlockAmount(), amount - penalty);
        assertEq(l2Reward.totalWeight(), expectedTotalWeight);

        uint256 dailyFundedReward = 0.1 * 10 ** 18;
        uint256 rewardsFromPenalty = penalty / 30;

        for (uint16 i = 19791; i < 19821; i++) {
            assertEq(l2Reward.dailyRewards(i), dailyFundedReward + rewardsFromPenalty);
        }

        assertEq(l2LiskToken.balanceOf(staker), convertLiskToSmallestDenomination(1000) - amount + reward);
        assertEq(l2Reward.dailyRewards(19821), dailyFundedReward);
        assertEq(l2LockingPosition.getLockingPosition(lockIDs[0]).amount, amount - penalty);
    }

    function test_initiateFastUnlock_forPausedPositionAddsPenaltyAsRewardAlsoUpdatesGlobalsAndClaimRewardsAlsoReducesStakedAmountByPenalty(
    )
        public
    {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(100);
        uint256 duration = 120;
        uint256[] memory lockIDs = new uint256[](1);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        skip(1 days);

        lockIDs[0] = when_stakerCreatesPosition(staker, Position(amount, duration));

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        skip(20 days);

        vm.startPrank(staker);
        then_eventLockingPositionPausedIsEmitted(lockIDs[0]);
        l2Reward.pauseUnlocking(lockIDs);
        vm.stopPrank();

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        uint256 rewardFor20Days = convertLiskToSmallestDenomination(2);
        uint256 penalty = 6643835616438356164;

        skip(20 days);

        vm.startPrank(staker);
        then_eventRewardsClaimedIsEmitted(lockIDs[0], rewardFor20Days);
        then_eventFastUnlockInitiatedIsEmitted(lockIDs[0]);
        l2Reward.initiateFastUnlock(lockIDs);
        vm.stopPrank();

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        uint256 expectedTotalWeight = (l2Staking.FAST_UNLOCK_DURATION() + l2Reward.OFFSET()) * (amount - penalty);

        assertEq(l2LiskToken.balanceOf(staker), balance - amount + rewardFor20Days * 2);
        assertEq(l2Reward.totalWeight(), expectedTotalWeight);
        assertEq(l2Reward.pendingUnlockAmount(), amount - penalty);
        assertEq(l2Reward.totalAmountLocked(), amount - penalty);
        assertEq(
            l2Reward.dailyUnlockedAmounts(deploymentDate + 1 + 40 + l2Staking.FAST_UNLOCK_DURATION()), amount - penalty
        );
        assertEq(l2LockingPosition.getLockingPosition(lockIDs[0]).amount, amount - penalty);
    }

    function test_initiateFastUnlock_forMultipleStakesUpdatesGlobalsAndClaimsRewards() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(100);
        uint256[] memory lockIDs = new uint256[](2);

        uint256 duration = 120;

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(35), duration: 350, delay: 1 }));

        skip(1 days);

        // staker creates two positions on expiry date + 1, 19741
        for (uint8 i = 0; i < lockIDs.length; i++) {
            lockIDs[i] = when_stakerCreatesPosition(staker, Position(amount, duration));
        }

        uint256 votingPowerAtLocking = l2VotingPower.balanceOf(staker);

        skip(30 days);

        uint256 expectedRewardsPerStakeAfter30Days = 1.5 * 10 ** 18;
        uint256 expectedPenaltyPerStakeAfter30Days = 5958904109589041095;

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        // staker initates fast unlock after 30 days
        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewardsPerStakeAfter30Days);
        then_eventRewardsClaimedIsEmitted(lockIDs[1], expectedRewardsPerStakeAfter30Days);
        vm.startPrank(staker);
        l2Reward.initiateFastUnlock(lockIDs);
        vm.stopPrank();

        uint256 expectedTotalWeight =
            2 * (l2Staking.FAST_UNLOCK_DURATION() + l2Reward.OFFSET()) * (amount - expectedPenaltyPerStakeAfter30Days);

        assertEq(l2Reward.totalAmountLocked(), 2 * (amount - expectedPenaltyPerStakeAfter30Days));
        assertEq(l2Reward.totalWeight(), expectedTotalWeight);

        // penalty is burned from voting power
        assertEq(l2VotingPower.balanceOf(staker), votingPowerAtLocking - expectedPenaltyPerStakeAfter30Days * 2);

        uint256 expectedRewardsForFAST_UNLOCK_DURATION = 547260273972602738;

        skip(5 days);

        then_eventRewardsClaimedIsEmitted(lockIDs[0], expectedRewardsForFAST_UNLOCK_DURATION);
        then_eventRewardsClaimedIsEmitted(lockIDs[1], expectedRewardsForFAST_UNLOCK_DURATION);
        vm.startPrank(staker);
        l2Reward.claimRewards(lockIDs);
        vm.stopPrank();

        uint256 balanceAfterClaimingAllRewards = balance - (amount * 2) + (expectedRewardsPerStakeAfter30Days * 2)
            + (expectedRewardsForFAST_UNLOCK_DURATION * 2);

        assertEq(l2LiskToken.balanceOf(staker), balanceAfterClaimingAllRewards);

        then_eventRewardsClaimedIsEmitted(lockIDs[0], 0);
        then_eventRewardsClaimedIsEmitted(lockIDs[1], 0);
        vm.startPrank(staker);
        l2Reward.deletePositions(lockIDs);
        vm.stopPrank();

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        uint256 expectedBalanceAfterUnlocking =
            balanceAfterClaimingAllRewards + amount * 2 - expectedPenaltyPerStakeAfter30Days * 2;

        assertEq(l2LiskToken.balanceOf(staker), expectedBalanceAfterUnlocking);
    }

    function test_initializeLockingPosition_onlyOwnerCanInitializeLockingPosition() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x1)));
        vm.prank(address(0x1));
        l2Reward.initializeLockingPosition(address(0x2));
    }

    function test_initializeLockingPosition_canOnlyBeInitializedOnce() public {
        vm.expectRevert("L2Reward: LockingPosition contract is already initialized");

        l2Reward.initializeLockingPosition(address(0x1));
    }

    function test_initializeLockingPosition_lockingPositionContractAddressCanNotBeZero() public {
        l2RewardImplementation = new L2Reward();
        l2Reward = L2Reward(
            address(
                new ERC1967Proxy(
                    address(l2RewardImplementation),
                    abi.encodeWithSelector(l2Reward.initialize.selector, address(l2LiskToken))
                )
            )
        );

        vm.expectRevert("L2Reward: LockingPosition contract address can not be zero");
        l2Reward.initializeLockingPosition(address(0x0));
    }

    function test_initializeLockingPosition_emitsLockingPositionContractAddressChanged() public {
        l2RewardImplementation = new L2Reward();
        l2Reward = L2Reward(
            address(
                new ERC1967Proxy(
                    address(l2RewardImplementation),
                    abi.encodeWithSelector(l2Reward.initialize.selector, address(l2LiskToken))
                )
            )
        );

        vm.expectEmit(true, true, true, true);
        emit L2Reward.LockingPositionContractAddressChanged(address(0x0), address(0x1));
        l2Reward.initializeLockingPosition(address(0x1));
    }

    function test_initializeStaking_onlyOwnerCanInitializeStaking() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x1)));
        vm.prank(address(0x1));
        l2Reward.initializeStaking(address(0x2));
    }

    function test_initializeStaking_canOnlyBeInitializedOnce() public {
        vm.expectRevert("L2Reward: Staking contract is already initialized");

        l2Reward.initializeStaking(address(0x1));
    }

    function test_initializeStaking_stakingContractAddressCanNotBeZero() public {
        l2RewardImplementation = new L2Reward();
        l2Reward = L2Reward(
            address(
                new ERC1967Proxy(
                    address(l2RewardImplementation),
                    abi.encodeWithSelector(l2Reward.initialize.selector, address(l2LiskToken))
                )
            )
        );

        vm.expectRevert("L2Reward: Staking contract address can not be zero");
        l2Reward.initializeStaking(address(0x0));
    }

    function test_initializeStaking_emitsStakingContractAddressChangedEvent() public {
        l2RewardImplementation = new L2Reward();
        l2Reward = L2Reward(
            address(
                new ERC1967Proxy(
                    address(l2RewardImplementation),
                    abi.encodeWithSelector(l2Reward.initialize.selector, address(l2LiskToken))
                )
            )
        );

        vm.expectEmit(true, true, true, true);
        emit L2Reward.StakingContractAddressChanged(address(0x0), address(0x1));

        l2Reward.initializeStaking(address(0x1));
    }

    function test_addUnusedRewards_onlyOwnerCanAddUnusedRewards() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x1)));

        vm.prank(address(0x1));
        l2Reward.addUnusedRewards(100, 100, 1);
    }

    function test_addUnusedRewards_delayShouldBeGreaterThanZeroWhenAddingRewards() public {
        vm.expectRevert("L2Reward: Rewards can only be added from next day or later");

        l2Reward.addUnusedRewards(100, 100, 0);
    }

    function test_addUnusedRewards_rewardAmountShouldNotBeGreaterThanRewardSurplus() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        given_ownerHasFundedStaking(Funds({ amount: convertLiskToSmallestDenomination(1000), duration: 350, delay: 1 }));

        // staker creates a positions on deploymentDate, 19740
        when_stakerCreatesPosition(staker, Position({ amount: convertLiskToSmallestDenomination(100), duration: 120 }));

        // staker creates another position on deploymentDate + 2, 19742
        // This will trigger updateGlobalState() for 19740 and 19741, with funds availbe only for 19741
        skip(2 days);
        when_stakerCreatesPosition(staker, Position({ amount: convertLiskToSmallestDenomination(1), duration: 100 }));

        uint256 invalidRewardAmount = l2Reward.rewardsSurplus() + 1;
        vm.expectRevert("L2Reward: Reward amount should not exceed available surplus funds");
        l2Reward.addUnusedRewards(invalidRewardAmount, 10, 1);

        // correct amount equal to rewardsSurplus gets added
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsAdded(l2Reward.rewardsSurplus(), 10, 1);
        l2Reward.addUnusedRewards(l2Reward.rewardsSurplus(), 10, 1);

        assertEq(l2Reward.rewardsSurplus(), 0);
    }

    function test_addUnusedRewards_updatesDailyRewardsAndEmitsRewardsAddedEvent() public {
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(10000);

        uint256[] memory lockIDs = new uint256[](2);

        given_accountHasBalance(address(this), balance);
        given_accountHasBalance(staker, balance);
        uint256 dailyReward = given_ownerHasFundedStaking(
            Funds({ amount: convertLiskToSmallestDenomination(1000), duration: 350, delay: 1 })
        );

        // staker creates a positions on deploymentDate, 19740
        lockIDs[0] = when_stakerCreatesPosition(
            staker, Position({ amount: convertLiskToSmallestDenomination(100), duration: 120 })
        );

        skip(2 days);
        lockIDs[1] = when_stakerCreatesPosition(
            staker, Position({ amount: convertLiskToSmallestDenomination(1), duration: 100 })
        );

        uint256 additionalReward = convertLiskToSmallestDenomination(1);
        uint256 additionalRewardPerDay = additionalReward / 10;
        uint256 cappedRewards = convertLiskToSmallestDenomination(100) / 365;

        assertEq(l2Reward.dailyRewards(19741), cappedRewards);

        uint256 rewardsSurplusBeforeAdditionalRewards = l2Reward.rewardsSurplus();

        // days 19743 to 19752 are funded
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsAdded(additionalReward, 10, 1);
        l2Reward.addUnusedRewards(additionalReward, 10, 1);
        vm.stopPrank();

        for (uint16 i = 19743; i < 19753; i++) {
            assertEq(l2Reward.dailyRewards(i), dailyReward + additionalRewardPerDay);
        }

        assertEq(l2Reward.rewardsSurplus(), rewardsSurplusBeforeAdditionalRewards - additionalReward);
        assertEq(l2Reward.lastTrsDate(), 19742);

        skip(10 days);

        uint256 rewardSurplusAfterAdditionalRewards = l2Reward.rewardsSurplus();

        // staker cerates another position on deploymentDate + 2 + 10, 19752
        // This will trigger updateGlobalState() from 19742 to 19751
        when_stakerCreatesPosition(staker, Position({ amount: convertLiskToSmallestDenomination(100), duration: 100 }));
        cappedRewards = convertLiskToSmallestDenomination(101) / 365;
        for (uint16 i = 19742; i < 19752; i++) {
            assertEq(l2Reward.dailyRewards(i), cappedRewards);
        }

        // For day 19742 additional rewards are not assigned but for the
        // remaining days from 19743 onwards additional rewards are assigned
        uint256 expectedRewardSurplus = rewardSurplusAfterAdditionalRewards + (dailyReward - cappedRewards)
            + (9 * (dailyReward + additionalRewardPerDay - cappedRewards));

        assertEq(l2Reward.rewardsSurplus(), expectedRewardSurplus);
    }

    function test_rewardContractBalanceNearsZeroAndHasFundsForRewards() public {
        address[] memory stakers = given_anArrayOfStakersOfLength(5);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 funds = convertLiskToSmallestDenomination(35);
        uint256[] memory locksToClaim = new uint256[](1);
        uint256[] memory lockIDs = new uint256[](5);

        given_accountHasBalance(address(this), balance);
        given_ownerHasFundedStaking(Funds({ amount: funds, duration: 150, delay: 1 }));

        skip(1 days);
        for (uint8 i = 0; i < stakers.length; i++) {
            given_accountHasBalance(stakers[i], balance);
            lockIDs[i] = when_stakerCreatesPosition(
                stakers[i], Position({ amount: convertLiskToSmallestDenomination(37) * (i + 1), duration: 150 })
            );
        }

        skip(150 days);
        for (uint8 i = 0; i < stakers.length; i++) {
            locksToClaim[0] = lockIDs[i];
            when_rewardsAreClaimedByStaker(stakers[i], locksToClaim);
        }

        checkConsistencyPendingUnlockDailyUnlocked(lockIDs, getLargestExpiryDate(lockIDs));

        uint256 sumOfDailyRewards;
        for (uint256 i = 19740; i < l2Reward.todayDay(); i++) {
            sumOfDailyRewards += l2Reward.dailyRewards(i);
        }

        uint256 sumOfRewards;
        for (uint8 i = 0; i < stakers.length; i++) {
            // expected reward is current balance + amount staked - initial balance
            sumOfRewards +=
                (l2LiskToken.balanceOf(stakers[i]) + (convertLiskToSmallestDenomination(37) * (i + 1))) - balance;
        }

        // balance of the l2Reward is almost zero
        assertEq(l2LiskToken.balanceOf(address(l2Reward)) / 10 ** 3, 0);

        assertTrue(sumOfDailyRewards <= funds);
        assertTrue(sumOfRewards <= funds);
        assertTrue(sumOfDailyRewards > sumOfRewards);

        // daily rewards and rewards assigned are almost equal
        assertEq(sumOfDailyRewards / 10 ** 3, sumOfRewards / 10 ** 3);
    }

    function convertLiskToSmallestDenomination(uint256 lisk) internal pure returns (uint256) {
        return lisk * 10 ** 18;
    }

    function LSK(uint256 lisk) internal pure returns (uint256) {
        return lisk * 10 ** 18;
    }
}
