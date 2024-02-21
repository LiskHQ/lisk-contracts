// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { L2Staking } from "src/L2/L2Staking.sol";

/*contract L2StakingTest is Test {
    L2Staking l2Staking;

    uint256 private constant HEADSTART = 150;

    uint256 deploymentDay = 19740;

    function setUp() public {
        skip(deploymentDay * 1 days);
        l2Staking = new L2Staking();

        assertEq(l2Staking.HEADSTART(), HEADSTART);
        assertEq(l2Staking.lastTxDate(), deploymentDay);
    }

    function test_StakeIsAddedForTheSender() public {
        uint256 creationDate = deploymentDay + 2;
        uint256 amount = 1000;
        uint256 duration = 450;
        bool autoExtend = true;
        uint256 creationTotalWeight = amount * (duration + HEADSTART);

        skip(2 days);

        l2Staking.createStake(amount, duration, autoExtend);

        Stake[] memory stakes = l2Staking.getStakes(address(this));

        assertEq(stakes.length, 1);
        assertEq(
            abi.encode(stakes[0]),
            abi.encode(
                Stake(address(0x0), amount, creationDate + duration, creationDate, duration, creationTotalWeight)
            )
        );

        l2Staking.createStake(amount, duration, !autoExtend);

        stakes = l2Staking.getStakes(address(this));
        assertEq(stakes.length, 2);
        assertEq(
            abi.encode(stakes[1]),
            abi.encode(Stake(address(0x0), amount, creationDate + duration, creationDate, 0, creationTotalWeight * 2))
        );
    }

    function test_TotalWeightIsAggregatedWhenStakeIsCreated() public {
        uint256 amount = 1000;
        uint256 duration = 450;
        bool autoExtend = false;
        uint256 totalWeight = amount * (duration + HEADSTART);

        l2Staking.createStake(amount, duration, autoExtend);

        assertEq(l2Staking.totalWeight(), totalWeight);

        duration = 150;
        totalWeight += (amount * (duration + HEADSTART));
        l2Staking.createStake(amount, duration, autoExtend);

        assertEq(l2Staking.totalWeight(), totalWeight);
    }

    function test_totalAmountLockedIsAggregatedWhenStakeIsCreated() public {
        uint256 amount = 1000;
        uint256 duration = 450;
        bool autoExtend = false;

        l2Staking.createStake(amount, duration, autoExtend);

        assertEq(l2Staking.totalAmountLocked(), amount);

        uint256 anotherAmount = 5000;
        l2Staking.createStake(anotherAmount, duration, autoExtend);

        assertEq(l2Staking.totalAmountLocked(), amount + anotherAmount);
    }

    function test_pendingUnlockAmountIsAggregatedWhenCreatingAnExtendedState() public {
        uint256 amount = 1000;
        uint256 duration = 450;

        l2Staking.createStake(amount, duration, true);

        assertEq(l2Staking.pendingUnlockAmount(), amount);

        uint256 anotherAmount = 5000;
        l2Staking.createStake(anotherAmount, duration, true);

        assertEq(l2Staking.pendingUnlockAmount(), amount + anotherAmount);
    }

    function test_LastTxDateIsUpdatedWhenCreatingAStake() public {
        uint256 day = deploymentDay + 3;

        skip(3 days);

        l2Staking.createStake(1000, 150, true);

        assertEq(l2Staking.lastTxDate(), day);

        day += 1;

        skip(1 days);

        l2Staking.createStake(1000, 150, true);

        assertEq(l2Staking.lastTxDate(), day);
    }

    function test_TotalUnlockedAmountForExpiryDateIsAggregatedIfStakeIsNotExtended() public {
        uint256 day = deploymentDay + 1;

        skip(1 days);

        l2Staking.createStake(1000, 450, false);

        assertEq(l2Staking.totalUnlocked(day + 450), 1000);

        l2Staking.createStake(1000, 450, false);

        assertEq(l2Staking.totalUnlocked(day + 450), 1000 * 2);
    }

    function test_totalAmountLockedIsSetForTheDayWhenStakeIsCreated() public {
        uint256 day = deploymentDay + 1;
        uint256 amount = 1000;

        skip(1 days);

        l2Staking.createStake(amount, 450, false);
        l2Staking.createStake(amount, 450, false);

        assertEq(l2Staking.totalAmountsLocked(day), 2000);

        skip(2 days);
        day += 2;

        l2Staking.createStake(amount, 450, true);

        assertEq(l2Staking.totalAmountsLocked(day), 3000);
    }

    function test_TotalWeightIsSetForTheDayWhenStakeIsCreated() public {
        uint256 day = deploymentDay + 1;
        uint256 amount = 1000;
        uint256 duration = 450;
        uint256 creationTotalWeight = amount * (duration + HEADSTART) * 2;

        skip(1 days);

        l2Staking.createStake(amount, duration, false);
        l2Staking.createStake(amount, duration, true);

        assertEq(l2Staking.totalWeights(day), creationTotalWeight);

        day += 2;
        skip(2 days);

        duration = 150;
        creationTotalWeight += amount * (duration + HEADSTART);

        l2Staking.createStake(amount, duration, false);

        assertEq(l2Staking.totalWeights(day), creationTotalWeight);
    }

    function test_MissingPositionsAreSetWhenStakeIsCreated() public {
        uint256 day = deploymentDay + 1;
        uint256 amount = 1000;
        uint256 duration = 450;
        uint256 creationTotalWeight = amount * (duration + HEADSTART);

        skip(1 days);

        l2Staking.createStake(amount, duration, false);

        console2.logUint(l2Staking.lastTxDate());

        assertEq(l2Staking.totalAmountsLocked(day - 1), 0);
        assertEq(l2Staking.totalAmountsLocked(day), amount);

        assertEq(l2Staking.totalWeights(day - 1), 0);
        assertEq(l2Staking.totalWeights(day), creationTotalWeight);

        skip(3 days);
        day += 3;

        l2Staking.createStake(amount, duration, false);

        assertEq(l2Staking.totalAmountsLocked(deploymentDay + 2), amount);
        assertEq(l2Staking.totalAmountsLocked(deploymentDay + 3), amount);

        assertEq(l2Staking.totalWeights(deploymentDay + 2), creationTotalWeight);
        assertEq(l2Staking.totalWeights(deploymentDay + 3), creationTotalWeight);

        console2.logUint(l2Staking.lastTxDate());

        assertEq(l2Staking.totalAmountsLocked(day), amount * 2);
        assertEq(l2Staking.totalWeights(day), creationTotalWeight * 2);
    }

    function test_StakedAmountIsTransferredToEscrowContractWhenStakeIsCreated() public {
        //assertTrue(false);
    }

    function test_dailyRewardIsCapped() public {
        uint256 amount = 1000;
        l2Staking.createStake(amount, 150, false);

        assertEq(l2Staking.dailyReward(deploymentDay), 2);

        l2Staking.createStake(l2Staking.YEARLY_REWARDS_AMOUNT(), 150, false);

        assertEq(l2Staking.dailyReward(deploymentDay), l2Staking.YEARLY_REWARDS_AMOUNT() / 365);
    }
}*/
