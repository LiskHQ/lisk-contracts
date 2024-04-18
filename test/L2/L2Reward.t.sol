// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { IL2LiskToken, IL2LockingPosition, IL2Staking, L2Reward } from "src/L2/L2Reward.sol";
import { ERC721Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { L2LockingPosition, LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2Staking } from "src/L2/L2Staking.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20Errors } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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

    address daoTreasury = address(0xff);

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

        l2Reward.initializeDaoTreasury(daoTreasury);

        vm.expectEmit(true, true, true, true);
        emit L2Reward.LockingPositionContractAddressChanged(address(0x0), address(l2LockingPosition));
        l2Reward.initializeLockingPosition(address(l2LockingPosition));

        vm.expectEmit(true, true, true, true);
        emit L2Reward.StakingContractAddressChanged(address(0x0), address(l2Staking));
        l2Reward.initializeStaking(address(l2Staking));

        assertEq(l2Reward.l2TokenContract(), address(l2LiskToken));
        assertEq(l2Reward.daoTreasury(), daoTreasury);
        assertEq(l2Reward.lockingPositionContract(), address(l2LockingPosition));
        assertEq(l2Reward.stakingContract(), address(l2Staking));
    }

    function test_initialize() public {
        assertEq(l2Reward.lastTrsDate(), deploymentDate);
        assertEq(l2Reward.OFFSET(), 150);
        assertEq(l2Reward.REWARD_DURATION(), 30);
        assertEq(l2Reward.REWARD_DURATION_DELAY(), 1);
        assertEq(l2Reward.version(), "1.0.0");
    }

    function test_createPosition_l2RewardContractShouldBeApprovedToTransferFromStakerAccount() public {
        l2Staking.addCreator(address(l2Reward));

        address staker = address(0x1);

        uint256 duration = 20;
        uint256 amount = convertLiskToSmallestDenomination(10);
        uint256 ID;

        vm.startPrank(bridge);
        l2LiskToken.mint(address(l2Reward), convertLiskToSmallestDenomination(1000));
        l2LiskToken.mint(staker, convertLiskToSmallestDenomination(1000));
        vm.stopPrank();

        vm.startPrank(staker);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(l2Reward), 0, amount)
        );
        ID = l2Reward.createPosition(amount, duration);
        vm.stopPrank();
    }

    function test_createPosition_updatesGlobals() public {
        l2Staking.addCreator(address(l2Reward));

        address staker = address(0x1);

        uint256 duration = 20;
        uint256 amount = convertLiskToSmallestDenomination(10);
        uint256 ID;

        vm.startPrank(bridge);
        l2LiskToken.mint(address(l2Reward), convertLiskToSmallestDenomination(1000));
        l2LiskToken.mint(staker, convertLiskToSmallestDenomination(1000));
        vm.stopPrank();

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        ID = l2Reward.createPosition(amount, duration);
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
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(1000));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(1000), 350, 1);
        vm.stopPrank();

        // staker creates a position on deploymentDate, 19740.
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        l2Reward.createPosition(convertLiskToSmallestDenomination(100), 120);

        // staker creates another position on deploymentDate + 2, 19742.
        skip(2 days);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(1));
        l2Reward.createPosition(convertLiskToSmallestDenomination(1), 100);
        vm.stopPrank();

        uint256 expectedTotalWeight = convertLiskToSmallestDenomination(100) * (120 + l2Reward.OFFSET())
            + convertLiskToSmallestDenomination(1) * (100 + l2Reward.OFFSET()) - 200 * 10 ** 18;
        assertEq(l2Reward.totalWeight(), expectedTotalWeight);
        assertEq(l2Reward.totalAmountLocked(), convertLiskToSmallestDenomination(101));
        assertEq(l2Reward.pendingUnlockAmount(), convertLiskToSmallestDenomination(101));
        assertEq(l2Reward.lastTrsDate(), deploymentDate + 2);
        uint256 cappedRewards = convertLiskToSmallestDenomination(100) / 365;
        uint256 dailyReward = convertLiskToSmallestDenomination(1000) / 350;

        // Rewards are capped for the day, 19741 as funding starts at 19741.
        assertEq(l2Reward.dailyRewards(19741), cappedRewards);
        assertEq(l2Reward.rewardsSurplus(), dailyReward - cappedRewards);

        skip(3 days);

        // staker creates another position on deploymentDate + 4, 1745.
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        l2Reward.createPosition(convertLiskToSmallestDenomination(100), 100);
        vm.stopPrank();

        uint256 newCappedRewards = convertLiskToSmallestDenomination(101) / 365;
        for (uint16 i = 19742; i < 19745; i++) {
            assertEq(l2Reward.dailyRewards(i), newCappedRewards);
        }
    }

    function test_fundStakingRewards_onlyDAOTreasuryCanFundRewards() public {
        vm.expectRevert("L2Reward: Funds can only be added by DAO treasury");

        vm.startPrank(address(0x1));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(3550), 255, 1);
    }

    function test_fundStakingRewards_delayShouldBeGreaterThanZeroWhenFundingStakingRewards() public {
        vm.expectRevert("L2Reward: Funding should start from next day or later");

        vm.prank(daoTreasury);
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(3550), 255, 0);
    }

    function test_fundStakingRewards_dailyRewardsAreAggregatedForTheDuration() public {
        uint256 balance = convertLiskToSmallestDenomination(1000);
        vm.startPrank(bridge);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        uint256 amount = convertLiskToSmallestDenomination(35);
        uint16 duration = 350;
        uint16 delay = 1;
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), amount);
        l2Reward.fundStakingRewards(amount, duration, delay);
        vm.stopPrank();

        uint256 dailyReward = amount / duration;
        uint256 today = deploymentDate;
        uint256 endDate = today + delay + duration;

        for (uint256 d = today + delay; d < endDate; d++) {
            assertEq(l2Reward.dailyRewards(d), dailyReward);
        }

        assertEq(l2LiskToken.balanceOf(address(daoTreasury)), balance - amount);
        assertEq(l2LiskToken.balanceOf(address(l2Reward)), amount);
        assertEq(l2Reward.dailyRewards(today), 0);
        assertEq(l2Reward.dailyRewards(endDate), 0);

        delay = 2;
        duration = 10;
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), amount);
        l2Reward.fundStakingRewards(amount, duration, delay);
        vm.stopPrank();

        uint256 newEndDate = today + delay + duration;
        uint256 additionalReward = amount / duration;

        for (uint256 d = today + delay; d < newEndDate; d++) {
            assertEq(l2Reward.dailyRewards(d), dailyReward + additionalReward);
        }

        assertEq(l2Reward.dailyRewards(today), 0);
        assertEq(l2Reward.dailyRewards(today + 1), dailyReward);
        assertEq(l2Reward.dailyRewards(newEndDate), dailyReward);
    }

    function test_fundStaking_emitsRewardsAddedEvent() public {
        l2Staking.addCreator(address(l2Reward));
        uint256 balance = convertLiskToSmallestDenomination(10000);

        // DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(1000));
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsAdded(convertLiskToSmallestDenomination(1000), 10, 1);
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(1000), 10, 1);
        vm.stopPrank();
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
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256[] memory lockIDs = new uint256[](1);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        // staker creates a position on deploymentDate, 19740
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        lockIDs[0] = l2Reward.createPosition(convertLiskToSmallestDenomination(100), 120);
        vm.stopPrank();

        // rewards are claimed from lastClaimDate for the lock (19740) till expiry day
        uint256 today = deploymentDate + 150;
        skip(150 days);

        uint256 expectedRewards = 11.9 * 10 ** 18;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;

        // staker claims rewards on, 19890
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockIDs[0], expectedRewards);
        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);

        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2LiskToken.balanceOf(staker), expectedBalance);

        // staker claims again on, 19890
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockIDs[0], 0);
        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);
    }

    function test_claimRewards_activePositionsAreRewardedTillExpiry() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256[] memory lockIDs = new uint256[](1);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        // staker creates a position on deploymentDate, 19740
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        lockIDs[0] = l2Reward.createPosition(convertLiskToSmallestDenomination(100), 120);
        vm.stopPrank();

        // rewards are claimed from lastClaimDate for the lock (19740) till expiry day

        uint256 today = deploymentDate + 150;
        skip(150 days);

        uint256 expectedRewards = 11.9 * 10 ** 18;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;

        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockIDs[0], expectedRewards);
        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);

        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2LiskToken.balanceOf(staker), expectedBalance);
    }

    function test_claimRewards_activePositionsAreRewardedTillTodayIfExpiryIsInFuture() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256[] memory lockIDs = new uint256[](2);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        // staker creates a position on deploymentDate, 19740
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        lockIDs[0] = l2Reward.createPosition(convertLiskToSmallestDenomination(100), 120);

        l2LiskToken.approve(address(l2Reward), 1 * 10 ** 18);
        lockIDs[1] = l2Reward.createPosition(1 * 10 ** 18, 100);
        vm.stopPrank();

        // rewards are claimed from lastClaimDate for the lock (19740) till today

        // today is 19830
        uint256 today = deploymentDate + 90;
        skip(90 days);

        uint256 expectedRewards = 8819747074459443653 + 80252925540556258;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;

        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockIDs[0], 8819747074459443653);
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockIDs[1], 80252925540556258);
        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);

        balance = l2LiskToken.balanceOf(staker);

        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2Reward.lastClaimDate(lockIDs[1]), today);
        assertEq(balance, expectedBalance);
    }

    function test_claimRewards_pausedPositionsAreRewardedTillTodayWeightedAgainstThePausedLockingDuration() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256[] memory lockIDs = new uint256[](2);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        // staker creates two positions on deploymentDate, 19740
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(10));
        lockIDs[0] = l2Reward.createPosition(convertLiskToSmallestDenomination(10), 150);

        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(10));
        lockIDs[1] = l2Reward.createPosition(convertLiskToSmallestDenomination(10), 300);
        vm.stopPrank();

        vm.startPrank(staker);
        l2Reward.pauseUnlocking(lockIDs[0]);
        l2Reward.pauseUnlocking(lockIDs[1]);
        vm.stopPrank();

        uint256 expectedRewards = 6575342465753424600 + 9863013698630136900;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;

        uint256 today = deploymentDate + 301;
        skip(301 days);

        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockIDs[0], 6575342465753424600);
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockIDs[1], 9863013698630136900);
        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);

        balance = l2LiskToken.balanceOf(staker);

        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2Reward.lastClaimDate(lockIDs[1]), today);
        assertEq(balance, expectedBalance);
    }

    function test_claimRewards_multipleStakesWithSameAmountAndDurationAreEquallyRewardedCappedRewards() public {
        l2Staking.addCreator(address(l2Reward));

        address[5] memory stakers = [address(0x1), address(0x2), address(0x3), address(0x4), address(0x5)];
        uint256[] memory lockIDs = new uint256[](5);

        // rewards are capped
        uint256 funds = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(100);
        uint256 duration = 300;

        // stakers and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(daoTreasury, funds);

        for (uint8 i = 0; i < stakers.length; i++) {
            l2LiskToken.mint(stakers[i], amount);
        }
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), funds);
        l2Reward.fundStakingRewards(funds, 365, 1);
        vm.stopPrank();

        skip(1 days);

        // All stakers create a position on deploymentDate + 1, 19741
        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            l2LiskToken.approve(address(l2Reward), amount);
            lockIDs[i] = l2Reward.createPosition(amount, duration);
            vm.stopPrank();
        }

        uint256[] memory locksToClaim = new uint256[](1);

        uint256 expectedRewardsFor100Days = 27397260273972602700;

        for (uint8 i = 0; i < 3; i++) {
            skip(100 days);
            for (uint8 j = 0; j < stakers.length; j++) {
                locksToClaim[0] = lockIDs[j];
                vm.expectEmit(true, true, true, true);
                emit L2Reward.RewardsClaimed(lockIDs[j], expectedRewardsFor100Days);
                vm.startPrank(stakers[j]);
                l2Reward.claimRewards(locksToClaim);
            }
        }

        for (uint8 i = 0; i < 5; i++) {
            assertEq(l2LiskToken.balanceOf(stakers[i]), expectedRewardsFor100Days * 3);
        }
    }

    function test_claimRewards_multipleStakesWithSameAmountAndDurationAreEquallyRewarded() public {
        l2Staking.addCreator(address(l2Reward));

        address[5] memory stakers = [address(0x1), address(0x2), address(0x3), address(0x4), address(0x5)];
        uint256[] memory lockIDs = new uint256[](5);

        uint256 funds = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(1000);
        uint256 duration = 300;

        // stakers and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(daoTreasury, funds);

        for (uint8 i = 0; i < stakers.length; i++) {
            l2LiskToken.mint(stakers[i], amount);
        }
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), funds);
        l2Reward.fundStakingRewards(funds, 365, 1);
        vm.stopPrank();

        skip(1 days);

        // All stakers create a position on deploymentDate + 1, 19741
        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            l2LiskToken.approve(address(l2Reward), amount);
            lockIDs[i] = l2Reward.createPosition(amount, duration);
            vm.stopPrank();
        }

        uint256[] memory locksToClaim = new uint256[](1);

        uint256 expectedRewardsFor100Days = 54794520547945205400;

        for (uint8 i = 0; i < 3; i++) {
            skip(100 days);
            for (uint8 j = 0; j < stakers.length; j++) {
                locksToClaim[0] = lockIDs[j];
                vm.expectEmit(true, true, true, true);
                emit L2Reward.RewardsClaimed(lockIDs[j], expectedRewardsFor100Days);
                vm.startPrank(stakers[j]);
                l2Reward.claimRewards(locksToClaim);
            }
        }

        skip(1 days);

        // All positions are expired, reward is zero
        for (uint8 i = 0; i < stakers.length; i++) {
            locksToClaim[0] = lockIDs[i];
            vm.startPrank(stakers[i]);

            vm.expectEmit(true, true, true, true);
            emit L2Reward.RewardsClaimed(lockIDs[i], 0);
            l2Reward.claimRewards(locksToClaim);
        }

        for (uint8 i = 0; i < 5; i++) {
            assertEq(l2LiskToken.balanceOf(stakers[i]), expectedRewardsFor100Days * 3);
        }
    }

    function test_claimRewards_multipleStakesWithDifferentAmountForSimilarDurationAreRewardedAccordinglyWhenUnlocked()
        public
    {
        l2Staking.addCreator(address(l2Reward));

        address[3] memory stakers = [address(0x1), address(0x2), address(0x3)];
        uint256[] memory lockIDs = new uint256[](3);

        uint256 funds = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(1000);
        uint256 duration = 300;

        // stakers and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(daoTreasury, funds);

        for (uint8 i = 0; i < stakers.length; i++) {
            l2LiskToken.mint(stakers[i], amount * (i + 1));
        }
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), funds);
        l2Reward.fundStakingRewards(funds, 365, 1);
        vm.stopPrank();

        // All stakers create a position on deploymentDate, 19740
        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            l2LiskToken.approve(address(l2Reward), amount * (i + 1));
            lockIDs[i] = l2Reward.createPosition(amount * (i + 1), duration);
            vm.stopPrank();
        }

        uint256[] memory locksToClaim = new uint256[](1);
        uint256[3] memory expectedRewardsAfter200Days =
            [uint256(90867579908675798955), uint256(181735159817351598109), uint256(272602739726027397064)];

        skip(200 days);
        for (uint8 i = 0; i < stakers.length; i++) {
            locksToClaim[0] = lockIDs[i];
            vm.expectEmit(true, true, true, true);
            emit L2Reward.RewardsClaimed(lockIDs[i], expectedRewardsAfter200Days[i]);
            vm.startPrank(stakers[i]);
            l2Reward.claimRewards(locksToClaim);
        }

        uint256[3] memory expectedRewards =
            [uint256(136529680365296803455), uint256(273059360730593607209), uint256(409589041095890410664)];

        uint256[3] memory expectedRewardsOnDeletion =
            [uint256(45662100456621004500), uint256(91324200913242009100), uint256(136986301369863013600)];
        skip(100 days);
        for (uint8 i = 0; i < stakers.length; i++) {
            vm.expectEmit(true, true, true, true);
            emit L2Reward.RewardsClaimed(lockIDs[i], expectedRewardsOnDeletion[i]);
            vm.startPrank(stakers[i]);
            l2Reward.deletePosition(lockIDs[i]);
            vm.stopPrank();

            assertEq(l2LiskToken.balanceOf(stakers[i]), amount * (i + 1) + expectedRewards[i]);
        }
    }

    function test_claimRewards_multipleStakesWithSameAmountForDifferentDurationAreRewardedAsPerTheWeight() public {
        l2Staking.addCreator(address(l2Reward));

        address[2] memory stakers = [address(0x1), address(0x2)];
        uint256[] memory lockIDs = new uint256[](2);

        uint256 funds = convertLiskToSmallestDenomination(100);
        uint256 amount = convertLiskToSmallestDenomination(100);
        uint256 duration = 100;

        // stakers and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(daoTreasury, funds);

        l2LiskToken.mint(stakers[0], amount);
        l2LiskToken.mint(stakers[1], amount);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), funds);
        l2Reward.fundStakingRewards(funds, 365, 1);
        vm.stopPrank();

        skip(1 days);

        // All stakers create a position on deploymentDate + 1, 19741
        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            l2LiskToken.approve(address(l2Reward), amount);
            lockIDs[i] = l2Reward.createPosition(amount, duration * (i + 1));
            vm.stopPrank();
        }

        uint256[] memory locksToClaim = new uint256[](1);

        skip(2 days);

        uint256[2] memory expectedRewardsAfter2Days = [uint256(228234144255585589), uint256(319711061223866463)];

        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            locksToClaim[0] = lockIDs[i];
            vm.expectEmit(true, true, true, true);
            emit L2Reward.RewardsClaimed(lockIDs[i], expectedRewardsAfter2Days[i]);
            l2Reward.claimRewards(locksToClaim);
            vm.stopPrank();
        }

        skip(49 days);

        uint256[2] memory expectedRewardsAfter51Days = [uint256(5484172493642193937), uint256(7940485040604381337)];

        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            locksToClaim[0] = lockIDs[i];
            vm.expectEmit(true, true, true, true);
            emit L2Reward.RewardsClaimed(lockIDs[i], expectedRewardsAfter51Days[i]);
            l2Reward.claimRewards(locksToClaim);
            vm.stopPrank();
        }

        skip(49 days);

        uint256[2] memory expectedRewardsAfter100Days = [uint256(5214765059512775305), uint256(8209892474733799969)];

        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            locksToClaim[0] = lockIDs[i];
            vm.expectEmit(true, true, true, true);
            emit L2Reward.RewardsClaimed(lockIDs[i], expectedRewardsAfter100Days[i]);
            l2Reward.claimRewards(locksToClaim);
            vm.stopPrank();
        }

        skip(100 days);
        uint256[2] memory expectedRewardsAfter200Days = [uint256(0), uint256(27397260273972602700)];

        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            locksToClaim[0] = lockIDs[i];
            vm.expectEmit(true, true, true, true);
            emit L2Reward.RewardsClaimed(lockIDs[i], expectedRewardsAfter200Days[i]);
            l2Reward.claimRewards(locksToClaim);
            vm.stopPrank();
        }
    }

    function test_deletePosition_onlyOwnerCanDeleteALockingPosition() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");
        l2Reward.deletePosition(1);
    }

    function test_deletePosition_onlyExistingLockingPositionCanBeDeletedByAnOwner() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Locking position does not exist");
        vm.prank(staker);
        l2Reward.deletePosition(1);
    }

    function test_deletePosition_onlyExpiredLockingPositionsCanBeDeleted() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256 lockID;

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        // staker creates a position on deploymentDate, 19740
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        lockID = l2Reward.createPosition(convertLiskToSmallestDenomination(100), 120);

        vm.stopPrank();

        skip(30 days);

        vm.expectRevert("L2Staking: locking duration active, can not unlock");
        vm.prank(staker);
        l2Reward.deletePosition(lockID);
    }

    function test_deletePosition_issuesRewardAndUnlocksPosition() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256 lockID;

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        // staker creates a position on deploymentDate, 19740
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        lockID = l2Reward.createPosition(convertLiskToSmallestDenomination(100), 120);

        vm.stopPrank();

        skip(150 days);

        uint256 expectedRewards = 11.9 * 10 ** 18;
        // locked amount gets unlocked
        uint256 expectedBalance =
            l2LiskToken.balanceOf(staker) + expectedRewards + convertLiskToSmallestDenomination(100);

        // staker deletes position
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockID, expectedRewards);
        vm.prank(staker);
        l2Reward.deletePosition(lockID);

        balance = l2LiskToken.balanceOf(staker);

        assertEq(l2Reward.lastClaimDate(lockID), 0);
        assertEq(balance, expectedBalance);
    }

    function test_pauseUnlocking_onlyOwnerCanPauseALockingPosition() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");
        l2Reward.deletePosition(1);
    }

    function test_pauseUnlocking_onlyExisitingLockingPositionCanBePausedByAnOwner() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Locking position does not exist");
        vm.prank(staker);
        l2Reward.pauseUnlocking(1);
    }

    function test_pauseUnlocking_lockingPositionCanBePausedOnlyOnce() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256 lockID;

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        // staker creates a position on deploymentDate, 19740
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        lockID = l2Reward.createPosition(convertLiskToSmallestDenomination(100), 120);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockID, 0);
        vm.prank(staker);
        l2Reward.pauseUnlocking(lockID);

        vm.expectRevert("L2Staking: remaining duration is already paused");
        vm.prank(staker);
        l2Reward.pauseUnlocking(lockID);
    }

    function test_pauseUnlocking_issuesRewardAndUpdatesGlobalUnlockAmounts() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256 lockID;

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        // staker creates a position on deploymentDate, 19740
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        lockID = l2Reward.createPosition(convertLiskToSmallestDenomination(100), 120);
        vm.stopPrank();

        skip(75 days);
        uint256 today = deploymentDate + 75;

        uint256 expectedRewards = 7.4 * 10 ** 18;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;
        uint256 expectedPausedLockingDuration = 45;

        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockID, expectedRewards);
        vm.prank(staker);
        l2Reward.pauseUnlocking(lockID);

        balance = l2LiskToken.balanceOf(staker);

        LockingPosition memory lockingPosition = l2LockingPosition.getLockingPosition(lockID);

        assertEq(balance, expectedBalance);
        assertEq(l2Reward.pendingUnlockAmount(), 0);
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + 120), 0);
        assertEq(l2Reward.lastClaimDate(lockID), today);
        assertEq(lockingPosition.pausedLockingDuration, expectedPausedLockingDuration);
    }

    function test_resumeUnlockingCountdown_onlyOwnerCanResumeUnlockingForALockingPosition() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");
        l2Reward.deletePosition(1);
    }

    function test_resumeUnlockingCountdown_onlyExisitingLockingPositionCanBeResumedByAnOwner() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Locking position does not exist");
        vm.prank(staker);
        l2Reward.resumeUnlockingCountdown(1);
    }

    function test_resumeUnlockingCountdown_onlyPausedLockingPositionCanBeResumed() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256 lockID;

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        // staker creates a position on deploymentDate, 19740
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        lockID = l2Reward.createPosition(convertLiskToSmallestDenomination(100), 120);
        vm.stopPrank();

        vm.expectRevert("L2Staking: countdown is not paused");
        vm.prank(staker);
        l2Reward.resumeUnlockingCountdown(lockID);
    }

    function test_resumeUnlockingCountdown_issuesRewardAndUpdatesGlobalUnlockAmount() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        uint256 lockID;

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        // staker creates a position on deploymentDate, 19740
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        lockID = l2Reward.createPosition(convertLiskToSmallestDenomination(100), 120);
        vm.stopPrank();

        skip(50 days);
        uint256 today = deploymentDate + 50;

        uint256 expectedRewardsWhenPausing = 4.9 * 10 ** 18;
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockID, expectedRewardsWhenPausing);
        // staker pauses the position
        vm.prank(staker);
        l2Reward.pauseUnlocking(lockID);

        uint256 expectedPausedLockingDuration = 70;
        uint256 expectedRewardsWhenResuming = convertLiskToSmallestDenomination(5);

        balance = l2LiskToken.balanceOf(staker);

        skip(50 days);
        today = deploymentDate + 100;

        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockID, expectedRewardsWhenResuming);
        vm.prank(staker);
        l2Reward.resumeUnlockingCountdown(lockID);

        uint256 expectedBalance = balance + expectedRewardsWhenResuming;

        LockingPosition memory lockingPosition = l2LockingPosition.getLockingPosition(lockID);

        assertEq(lockingPosition.expDate, today + expectedPausedLockingDuration);
        assertEq(l2Reward.pendingUnlockAmount(), convertLiskToSmallestDenomination(100));
        assertEq(
            l2Reward.dailyUnlockedAmounts(today + expectedPausedLockingDuration), convertLiskToSmallestDenomination(100)
        );
        assertEq(l2Reward.lastClaimDate(lockID), today);
        assertEq(l2LiskToken.balanceOf(staker), expectedBalance);
    }

    function test_increaseLockingAmount_onlyOwnerCanIncreaseAmountForALockingPosition() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");
        l2Reward.increaseLockingAmount(1, convertLiskToSmallestDenomination(10));
    }

    function test_increaseLockingAmount_amountCanOnlyBeIncreasedByAnOwnerForAnExistingLockingPosition() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Locking position does not exist");
        vm.prank(staker);
        l2Reward.increaseLockingAmount(1, convertLiskToSmallestDenomination(1));
    }

    function test_increaseLockingAmount_increasedAmountShouldBeGreaterThanZero() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Increased amount should be greater than zero");
        vm.prank(staker);
        l2Reward.increaseLockingAmount(1, 0);
    }

    function test_increaseLockingAmount_forActivePositionIncreasesLockedAmountAndWeightByRemainingDurationAndClaimsRewards(
    )
        public
    {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(100);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        uint256 lockID = l2Reward.createPosition(amount, 120);
        vm.stopPrank();

        skip(50 days);

        uint256 amountIncrease = convertLiskToSmallestDenomination(35);
        uint256 remainingDuration = 70;
        uint256 expectedTotalWeight =
            (27000 * 10 ** 18) - (5000 * 10 ** 18) + (amountIncrease * (remainingDuration + l2Reward.OFFSET()));

        balance = l2LiskToken.balanceOf(staker);

        uint256 expectedReward = 4.9 * 10 ** 18;

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amountIncrease);
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockID, expectedReward);
        l2Reward.increaseLockingAmount(lockID, amountIncrease);
        vm.stopPrank();

        assertEq(l2Reward.totalAmountLocked(), amount + amountIncrease);
        assertEq(l2Reward.totalWeight(), expectedTotalWeight);
        assertEq(l2LiskToken.balanceOf(staker), balance + expectedReward - amountIncrease);
        assertEq(l2Reward.pendingUnlockAmount(), convertLiskToSmallestDenomination(135));
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + 120), convertLiskToSmallestDenomination(135));
    }

    function test_increaseLockingAmount_forPausedPositionIncreasesTotalWeightByPausedLockingDurationAndClaimsRewards()
        public
    {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(100);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        uint256 lockID = l2Reward.createPosition(amount, 120);
        vm.stopPrank();

        // pausedLockingDuration set to 120
        vm.prank(staker);
        l2Reward.pauseUnlocking(lockID);

        skip(50 days);

        uint256 amountIncrease = convertLiskToSmallestDenomination(35);

        uint256 totalWeight = l2Reward.totalWeight();

        uint256 totalWeightIncrease = amountIncrease * (120 + l2Reward.OFFSET());

        balance = l2LiskToken.balanceOf(staker);

        uint256 expectedReward = 4.9 * 10 ** 18;

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amountIncrease);
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockID, expectedReward);
        l2Reward.increaseLockingAmount(lockID, amountIncrease);
        vm.stopPrank();

        assertEq(l2Reward.totalAmountLocked(), amount + amountIncrease);
        assertEq(l2LiskToken.balanceOf(staker), balance + expectedReward - amountIncrease);
        assertEq(l2Reward.totalWeight(), totalWeightIncrease + totalWeight);
    }

    function test_increaseLockingAmount_updatesTotalAmountLockedAndImpactsRewardCapping() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(10);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        uint256 dailyRewards = convertLiskToSmallestDenomination(35) / 350;

        skip(10 days);

        // staker stakes on 19750
        // daily rewards from 19740 to 19749 are capped due to zero total amount unlocked
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        uint256 lockID = l2Reward.createPosition(amount, 120);
        vm.stopPrank();

        // daily rewards are capped to zero
        for (uint256 i = deploymentDate; i < deploymentDate + 10; i++) {
            assertEq(l2Reward.dailyRewards(i), 0);
        }

        skip(10 days);

        // staker increase amount on 19760
        // "daily rewards from 19750 to 19759 are capped due too low total locked amount
        uint256 cappedRewards = amount / 365;
        uint256 amountIncrease = 90;

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amountIncrease);
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockID, 273972602739726020);
        l2Reward.increaseLockingAmount(lockID, amountIncrease);
        vm.stopPrank();

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

    function test_extendDuration_onlyOwnerCanExtendDurationForALockingPosition() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");
        l2Reward.extendDuration(1, 1);
    }

    function test_extendDuration_durationCanOnlyBeExtendedByAnOwnerForAnExistingLockingPositions() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Locking position does not exist");

        vm.prank(staker);
        l2Reward.extendDuration(1, 1);
    }

    function test_extendDuration_extendedDurationShouldBeGreaterThanZero() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Extended duration should be greater than zero");

        vm.prank(staker);
        l2Reward.extendDuration(1, 0);
    }

    function test_extendDuration_updatesGlobalsAndClaimRewardsForActivePositionWithExpiryInFuture() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 duration = 120;
        uint256 durationExtension = 50;
        uint256 amount = convertLiskToSmallestDenomination(100);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        uint256 lockID = l2Reward.createPosition(amount, duration);
        vm.stopPrank();

        skip(50 days);

        uint256 weightIncrease = amount * durationExtension;
        balance = l2LiskToken.balanceOf(staker);

        uint256 expectedReward = 4.9 * 10 ** 18;

        vm.startPrank(staker);
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockID, expectedReward);
        l2Reward.extendDuration(lockID, durationExtension);
        vm.stopPrank();

        assertEq(l2Reward.totalWeight(), (27000 * 10 ** 18) - (5000 * 10 ** 18) + weightIncrease);
        assertEq(l2LiskToken.balanceOf(staker), balance + expectedReward);
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + duration), 0);
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + duration + durationExtension), amount);
    }

    function test_extendDuration_updatesGlobalsAndClaimRewardsForExpiredPositions() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 duration = 120;
        uint256 durationExtension = 50;
        uint256 amount = convertLiskToSmallestDenomination(100);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        uint256 lockID = l2Reward.createPosition(amount, duration);
        vm.stopPrank();

        skip(121 days);

        uint256 weightIncrease = (amount * durationExtension) + (amount * l2Reward.OFFSET());
        balance = l2LiskToken.balanceOf(staker);

        uint256 expectedReward = 11.9 * 10 ** 18;

        vm.startPrank(staker);
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockID, expectedReward);
        l2Reward.extendDuration(lockID, durationExtension);
        vm.stopPrank();

        assertEq(l2LiskToken.balanceOf(staker), balance + expectedReward);
        assertEq(l2Reward.totalWeight(), weightIncrease);

        assertEq(l2Reward.totalAmountLocked(), amount);
        assertEq(l2Reward.pendingUnlockAmount(), amount);
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + duration + durationExtension), amount);
    }

    function test_extendDuration_updatesGlobalsAndClaimRewardsForPausedPositions() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 duration = 120;
        uint256 durationExtension = 50;
        uint256 amount = convertLiskToSmallestDenomination(100);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        uint256 lockID = l2Reward.createPosition(amount, duration);
        l2Reward.pauseUnlocking(lockID);
        vm.stopPrank();

        skip(120 days);

        uint256 weightIncrease = amount * durationExtension;
        uint256 expectedTotalWeight = l2Reward.totalWeight() + weightIncrease;
        uint256 expectedReward = 11.9 * 10 ** 18;

        balance = l2LiskToken.balanceOf(staker);

        vm.startPrank(staker);
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockID, expectedReward);
        l2Reward.extendDuration(lockID, durationExtension);
        vm.stopPrank();

        assertEq(l2LiskToken.balanceOf(staker), balance + expectedReward);
        assertEq(l2Reward.totalWeight(), expectedTotalWeight);
    }

    function test_initiateFastUnlock_onlyOwnerCanUnlockAPosition() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");
        l2Reward.initiateFastUnlock(1);
    }

    function test_initiateFastUnlock_onlyExistingLockingPositionCanBeUnlockedByAnOwner() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.prank(staker);
        vm.expectRevert("L2Reward: Locking position does not exist");
        l2Reward.initiateFastUnlock(1);
    }

    function test_initiateFastUnlock_forActivePositionAddsPenaltyAsRewardAlsoUpdatesGlobalsAndClaimRewards() public {
        l2Staking.addCreator(address(l2Reward));

        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(100);
        uint256 duration = 120;

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        uint256 lockID = l2Reward.createPosition(amount, duration);
        vm.stopPrank();

        skip(50 days);

        uint256 reward = 4.9e18;
        uint256 penalty = 4794520547945205479;

        vm.startPrank(staker);
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockID, reward);
        l2Reward.initiateFastUnlock(lockID);
        vm.stopPrank();

        uint256 expectedTotalWeight = (27000 * 10 ** 18) - (5000 * 10 ** 18)
            - (amount * (19860 - 19790 + l2Reward.OFFSET()))
            + ((l2Staking.FAST_UNLOCK_DURATION() + l2Reward.OFFSET()) * (amount - penalty));

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
    }

    function test_initiateFastUnlock_forPausedPositionAddsPenaltyAsRewardAlsoUpdatesGlobalsAndClaimRewards() public {
        l2Staking.addCreator(address(l2Reward));

        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);
        uint256 amount = convertLiskToSmallestDenomination(100);
        uint256 duration = 120;

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(35));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(35), 350, 1);
        vm.stopPrank();

        skip(1 days);

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        uint256 lockID = l2Reward.createPosition(amount, duration);
        vm.stopPrank();

        skip(20 days);

        vm.startPrank(staker);
        l2Reward.pauseUnlocking(lockID);
        vm.stopPrank();

        uint256 rewardFor20Days = convertLiskToSmallestDenomination(2);
        uint256 penalty = 6849315068493150684;

        skip(20 days);

        vm.startPrank(staker);
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsClaimed(lockID, rewardFor20Days);
        l2Reward.initiateFastUnlock(lockID);
        vm.stopPrank();

        uint256 expectedTotalWeight = (27000 * 10 ** 18) - (2000 * 10 ** 18) - ((100 + l2Reward.OFFSET()) * amount)
            + ((l2Staking.FAST_UNLOCK_DURATION() + l2Reward.OFFSET()) * (amount - penalty));

        assertEq(l2LiskToken.balanceOf(staker), balance - amount + rewardFor20Days * 2);
        assertEq(l2Reward.totalWeight(), expectedTotalWeight);
        assertEq(l2Reward.pendingUnlockAmount(), amount - penalty);
        assertEq(l2Reward.totalAmountLocked(), amount - penalty);
        assertEq(
            l2Reward.dailyUnlockedAmounts(deploymentDate + 1 + 40 + l2Staking.FAST_UNLOCK_DURATION()), amount - penalty
        );
    }

    function test_initializeDaoTreasury_onlyOwnerCanInitializeDaoTreasury() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x1)));
        vm.prank(address(0x1));
        l2Reward.initializeDaoTreasury(address(0x2));
    }

    function test_initializeDaoTreasury_canOnlyBeInitializedOnce() public {
        vm.expectRevert("L2Reward: Lisk DAO Treasury contract is already initialized");

        l2Reward.initializeDaoTreasury(address(0x1));
    }

    function test_initializeDaoTreasury_daoTreasuryContractAddressCanNotBeZero() public {
        l2RewardImplementation = new L2Reward();
        l2Reward = L2Reward(
            address(
                new ERC1967Proxy(
                    address(l2RewardImplementation),
                    abi.encodeWithSelector(l2Reward.initialize.selector, address(l2LiskToken))
                )
            )
        );

        vm.expectRevert("L2Reward: Lisk DAO Treasury contract address can not be zero");
        l2Reward.initializeDaoTreasury(address(0x0));
    }

    function test_initializeDaoTreasury_emitsDaoTreasuryAddressChanged() public {
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
        emit L2Reward.DaoTreasuryAddressChanged(address(0x0), address(0x1));
        l2Reward.initializeDaoTreasury(address(0x1));
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
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(1000);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(1000));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(1000), 350, 1);
        vm.stopPrank();

        // staker creates a positions on deploymentDate, 19740
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        l2Reward.createPosition(convertLiskToSmallestDenomination(100), 120);

        // staker creates another position on deploymentDate + 2, 19742
        // This will trigger updateGlobalState() for 19740 and 19741, with funds availbe only for 19741
        skip(2 days);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(1));
        l2Reward.createPosition(convertLiskToSmallestDenomination(1), 100);
        vm.stopPrank();

        uint256 invalidRewardAmount = l2Reward.rewardsSurplus() + 1;
        vm.expectRevert("L2Reward: Reward amount should not exceed available surplus funds");
        l2Reward.addUnusedRewards(invalidRewardAmount, 10, 1);

        // correct amount equal to rewardsSurplus gets added
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsAdded(l2Reward.rewardsSurplus(), 10, 1);
        l2Reward.addUnusedRewards(l2Reward.rewardsSurplus(), 10, 1);
    }

    function test_addUnusedRewards_updatesDailyRewardsAndEmitsRewardsAddedEvent() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToSmallestDenomination(10000);

        uint256[] memory lockIDs = new uint256[](2);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(1000));
        l2Reward.fundStakingRewards(convertLiskToSmallestDenomination(1000), 350, 1);
        vm.stopPrank();

        // staker creates a positions on deploymentDate, 19740
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        lockIDs[0] = l2Reward.createPosition(convertLiskToSmallestDenomination(100), 120);

        // staker creates another position on deploymentDate + 2, 19740
        // This will trigger updateGlobalState() for 19740 and 19741, updating rewardsSurplus
        skip(2 days);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(1));
        lockIDs[1] = l2Reward.createPosition(convertLiskToSmallestDenomination(1), 100);
        vm.stopPrank();

        uint256 dailyReward = convertLiskToSmallestDenomination(1000) / 350;
        uint256 additionalReward = l2Reward.rewardsSurplus() / 10;
        uint256 cappedRewards = convertLiskToSmallestDenomination(100) / 365;

        assertEq(l2Reward.dailyRewards(19741), cappedRewards);

        // days 19743 to 19752 are funded
        vm.expectEmit(true, true, true, true);
        emit L2Reward.RewardsAdded(l2Reward.rewardsSurplus(), 10, 1);
        l2Reward.addUnusedRewards(l2Reward.rewardsSurplus(), 10, 1);
        vm.stopPrank();

        for (uint16 i = 19743; i < 19753; i++) {
            assertEq(l2Reward.dailyRewards(i), dailyReward + additionalReward);
        }

        assertEq(l2Reward.rewardsSurplus(), 0);
        assertEq(l2Reward.lastTrsDate(), 19742);

        skip(10 days);

        // staker cerates another position on deploymentDate + 2 + 10, 19752
        // This will trigger updateGlobalState() from 19742 to 19751
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        l2Reward.createPosition(convertLiskToSmallestDenomination(1), 100);
        vm.stopPrank();

        cappedRewards = convertLiskToSmallestDenomination(101) / 365;

        // For day 19742 additional rewards are not assigned but for the
        // remaining days from 19743 onwards additional rewards are assigned
        uint256 expectedRewardSurplus =
            (dailyReward - cappedRewards) + (9 * (dailyReward + additionalReward - cappedRewards));

        for (uint16 i = 19742; i < 19752; i++) {
            assertEq(l2Reward.dailyRewards(i), cappedRewards);
        }

        assertEq(l2Reward.rewardsSurplus(), expectedRewardSurplus);
    }

    function convertLiskToSmallestDenomination(uint256 lisk) internal pure returns (uint256) {
        return lisk * 10 ** 18;
    }
}
