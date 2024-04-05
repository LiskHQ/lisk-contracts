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


struct Stake {
    address addr;
    uint256 amount;
    uint256 duration;
    uint256 rewards;
    uint256 id;
}

contract L2RewardTest is Test {
    L2LiskToken public l2LiskToken;
    L2Staking public l2Staking;
    L2Staking public l2StakingImplementation;
    L2LockingPosition public l2LockingPosition;
    L2LockingPosition public l2LockingPositionImplementation;
    L2VotingPower public l2VotingPowerImplementation;
    L2VotingPower public l2VotingPower;
    L2Reward public l2Reward;

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
        l2Reward = new L2Reward(address(l2Staking), address(l2LockingPosition), address(l2LiskToken));

        l2Reward.initializeDaoTreasury(daoTreasury);
    }

    function test_initialize() public {
        assertEq(l2Reward.lastTrsDate(), deploymentDate);
        assertEq(l2Reward.OFFSET(), 150);
    }

    function test_createPosition_updatesGlobals() public {
        l2Staking.addCreator(address(l2Reward));

        address staker = address(0x1);

        uint256 duration = 20;
        uint256 amount = convertLiskToBeddows(10);
        uint256 ID;

        vm.startPrank(bridge);
        l2LiskToken.mint(address(l2Reward), convertLiskToBeddows(1000));
        l2LiskToken.mint(staker, convertLiskToBeddows(1000));
        vm.stopPrank();

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        ID = l2Reward.createPosition(amount, duration);
        vm.stopPrank();

        assertEq(l2Reward.totalWeight(), (amount * (duration + l2Reward.OFFSET())) / 10 ** 16);
        assertEq(l2Reward.lastClaimDate(ID), deploymentDate);
        assertEq(l2Reward.totalAmountLocked(), amount);
        assertEq(l2Reward.dailyUnlockedAmounts(l2Reward.lastTrsDate() + duration), amount);
        assertEq(l2Reward.pendingUnlockAmount(), amount);
    }

    function test_createPosition_aggregatesAmountAndWeightAndUpdatesGlobals() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToBeddows(1000);

        uint256[] memory lockIDs = new uint256[](2);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(1000));
        l2Reward.fundStakingRewards(convertLiskToBeddows(1000), 350, 1);
        vm.stopPrank();

        // staker gets balance
        vm.prank(bridge);
        l2LiskToken.mint(staker, balance);

        // staker creates two positions on deploymentDate, 19740.
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(100));
        lockIDs[0] = l2Reward.createPosition(convertLiskToBeddows(100), 120);

        skip(2 days);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(1));
        lockIDs[1] = l2Reward.createPosition(convertLiskToBeddows(1), 100);
        vm.stopPrank();

        uint256 expectedTotalWeight = ((convertLiskToBeddows(100) * (120 + l2Reward.OFFSET())) / 10 ** 16)
            + ((convertLiskToBeddows(1) * (100 + l2Reward.OFFSET())) / 10 ** 16) - 20000;

        assertEq(l2Reward.totalWeight(), expectedTotalWeight);
        assertEq(l2Reward.totalAmountLocked(), convertLiskToBeddows(101));
        assertEq(l2Reward.pendingUnlockAmount(), convertLiskToBeddows(101));

        uint256 cappedRewards = convertLiskToBeddows(100) / 365;
        uint256 dailyReward = convertLiskToBeddows(1000) / 350;

        // Rewards are capped for day, 19741 as funding starts at 19741.
        assertEq(l2Reward.dailyRewards(19741), cappedRewards);
        assertEq(l2Reward.rewardsSurplus(), dailyReward - cappedRewards);
    }

    function test_fundStakingRewards_onlyDAOTreasuryCanFundRewards() public {
        vm.expectRevert("L2Reward: Funds can only be added by DAO treasury");

        vm.startPrank(address(0x1));
        l2Reward.fundStakingRewards(convertLiskToBeddows(3550), 255, 1);
    }

    function test_fundStakingRewards_delayShouldBeGreaterThanZeroWhenFundingStakingRewards() public {
        vm.expectRevert("L2Reward: Funding should start from next day or later");

        vm.prank(daoTreasury);
        l2Reward.fundStakingRewards(convertLiskToBeddows(3550), 255, 0);
    }

    function test_fundStakingRewards_dailyRewardsAreAggregatedForTheDuration() public {
        uint256 balance = convertLiskToBeddows(1000);
        vm.startPrank(bridge);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        uint256 amount = convertLiskToBeddows(35);
        uint16 duration = 350;
        uint16 delay = 1;
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), amount);
        l2Reward.fundStakingRewards(amount, duration, delay);
        vm.stopPrank();

        uint256 dailyReward = amount / duration;
        uint256 today = 19740;
        uint256 endDate = today + delay + duration;

        for (uint256 d = today + delay; d < endDate; d++) {
            assertEq(l2Reward.dailyRewards(d), dailyReward);
        }

        assertEq(l2LiskToken.balanceOf(address(daoTreasury)), balance - amount);
        assertEq(l2LiskToken.balanceOf(address(l2Reward)), amount);

        delay = 2;
        duration = 10;
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), amount);
        l2Reward.fundStakingRewards(amount, duration, delay);
        vm.stopPrank();

        delay = 2;
        duration = 10;

        endDate = today + delay + duration;
        uint256 additionalReward = amount / duration;

        for (uint256 d = today + delay; d < endDate; d++) {
            if (d % 2 == 0) {
                assertEq(l2Reward.dailyRewards(d), dailyReward + additionalReward);
            } else {
                assertEq(l2Reward.dailyRewards(d), dailyReward);
            }
        }
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
        uint256 lockID = 1;
        uint256 amount = convertLiskToBeddows(100);
        uint256 expDate = deploymentDate + 300;
        uint256 pausedLockingDuration = 0;

        LockingPosition memory lockingPosition = LockingPosition(staker, amount, expDate, pausedLockingDuration);

        vm.mockCall(
            address(l2LockingPosition), abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector), abi.encode(staker)
        );

        // lastClaimDate is today => deploymentDate
        vm.mockCall(
            address(l2Reward), abi.encodeWithSelector(l2Reward.lastClaimDate.selector), abi.encode(deploymentDate)
        );

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(L2LockingPosition.getLockingPosition.selector),
            abi.encode(lockingPosition)
        );

        uint256[] memory lockIDs = new uint256[](1);
        lockIDs[0] = lockID;

        vm.prank(staker);
        l2Reward.claimRewards(lockIDs);
        assertEq(l2LiskToken.balanceOf(staker), 0);
    }

    function test_claimRewards_activePositionsAreRewardedTillExpiry() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToBeddows(1000);

        uint256[] memory lockIDs = new uint256[](1);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(35));
        l2Reward.fundStakingRewards(convertLiskToBeddows(35), 350, 1);
        vm.stopPrank();

        // staker creates two positions on deploymentDate, 19740.
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(100));
        lockIDs[0] = l2Reward.createPosition(convertLiskToBeddows(100), 120);
        vm.stopPrank();

        // rewards are claimed from lastClaimDate for the lock (19740) till expiry day

        uint256 today = deploymentDate + 150;
        skip(150 days);

        uint256 expectedRewards = (11.9 * 10 ** 18) + 0;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;

        vm.prank(staker);
        uint256[] memory rewards = l2Reward.claimRewards(lockIDs);

        assertEq(rewards[0], 11.9 * 10 ** 18);
        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2LiskToken.balanceOf(staker), expectedBalance);
    }

    function test_claimRewards_activePositionsAreRewardedTillTodayIfExpiryIsInFuture() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToBeddows(1000);

        uint256[] memory lockIDs = new uint256[](2);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(35));
        l2Reward.fundStakingRewards(convertLiskToBeddows(35), 350, 1);
        vm.stopPrank();

        // staker creates two positions on deploymentDate, 19740.
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(100));
        lockIDs[0] = l2Reward.createPosition(convertLiskToBeddows(100), 120);

        l2LiskToken.approve(address(l2Reward), 1 * 10 ** 18);
        lockIDs[1] = l2Reward.createPosition(1 * 10 ** 18, 100);
        vm.stopPrank();

        // rewards are claimed from lastClaimDate for the lock (19740) till today

        // today is 19830
        uint256 today = deploymentDate + 90;
        skip(90 days);

        uint256 expectedRewards = 8819747074459443653 + 80252925540556258;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;

        vm.prank(staker);
        uint256[] memory rewards = l2Reward.claimRewards(lockIDs);

        balance = l2LiskToken.balanceOf(staker);

        assertEq(rewards[0], 8819747074459443653);
        assertEq(rewards[1], 80252925540556258);
        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2Reward.lastClaimDate(lockIDs[1]), today);
        assertEq(balance, expectedBalance);
    }

    function test_claimRewards_pausedPositionsAreRewardedTillTodayWeightedAgainstThePausedLockingDuration() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToBeddows(1000);

        uint256[] memory lockIDs = new uint256[](2);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(35));
        l2Reward.fundStakingRewards(convertLiskToBeddows(35), 350, 1);
        vm.stopPrank();

        // staker creates two positions on deploymentDate, 19740.
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(10));
        lockIDs[0] = l2Reward.createPosition(convertLiskToBeddows(10), 150);

        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(10));
        lockIDs[1] = l2Reward.createPosition(convertLiskToBeddows(10), 300);
        vm.stopPrank();

        vm.startPrank(staker);
        l2Reward.pauseUnlocking(lockIDs[0]);
        l2Reward.pauseUnlocking(lockIDs[1]);
        vm.stopPrank();

        uint256 expectedRewards = 6575342465753424600 + 9863013698630136900;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;

        uint256 today = deploymentDate + 301;
        skip(301 days);

        vm.prank(staker);
        uint256[] memory rewards = l2Reward.claimRewards(lockIDs);

        balance = l2LiskToken.balanceOf(staker);

        assertEq(rewards[0], 6575342465753424600);
        assertEq(rewards[1], 9863013698630136900);
        assertEq(l2Reward.lastClaimDate(lockIDs[0]), today);
        assertEq(l2Reward.lastClaimDate(lockIDs[1]), today);
        assertEq(balance, expectedBalance);
    }

    function test_claimRewards_multipleStakersStakeSameAmountAndDurationAreEquallyRewardedCappedRewards() public {
        l2Staking.addCreator(address(l2Reward));

        address[5] memory stakers = [address(0x1), address(0x2), address(0x3), address(0x4), address(0x5)];
        uint256[] memory lockIDs = new uint256[](5);
        uint256[] memory rewards = new uint256[](5);

        // rewards are capped
        uint256 funds = convertLiskToBeddows(1000);
        uint256 amount = convertLiskToBeddows(100);
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

        // All stakers creates a position on deploymentDate + 1, 19741.
        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            l2LiskToken.approve(address(l2Reward), amount);
            lockIDs[i] = l2Reward.createPosition(amount, duration);
            vm.stopPrank();
        }

        uint256[] memory locksToClaim = new uint256[](1);
        uint256[] memory rewardsClaimed = new uint256[](1);

        uint256 expectedRewardsFor100Days = 27397260273972602700;

        for (uint8 i = 0; i < 3; i++) {
            skip(100 days);
            for (uint8 j = 0; j < stakers.length; j++) {
                locksToClaim[0] = lockIDs[j];
                vm.startPrank(stakers[j]);
                rewardsClaimed = l2Reward.claimRewards(locksToClaim);

                rewards[j] += rewardsClaimed[0];

                assertEq(rewardsClaimed[0], expectedRewardsFor100Days);
            }
        }

        for (uint8 i = 0; i < 5; i++) {
            assertEq(rewards[i], expectedRewardsFor100Days * 3);
        }
    }

    function test_claimRewards_multipleStakersStakeSameAmountAndDurationAreEquallyRewarded() public {
        l2Staking.addCreator(address(l2Reward));

        address[5] memory stakers = [address(0x1), address(0x2), address(0x3), address(0x4), address(0x5)];
        uint256[] memory lockIDs = new uint256[](5);
        uint256[] memory rewards = new uint256[](5);

        uint256 funds = convertLiskToBeddows(1000);
        uint256 amount = convertLiskToBeddows(1000);
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

        // All stakers creates a position on deploymentDate + 1, 19741.
        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            l2LiskToken.approve(address(l2Reward), amount);
            lockIDs[i] = l2Reward.createPosition(amount, duration);
            vm.stopPrank();
        }

        uint256[] memory locksToClaim = new uint256[](1);
        uint256[] memory rewardsClaimed = new uint256[](1);

        uint256 expectedRewardsFor100Days = 54794520547945205400;

        for (uint8 i = 0; i < 3; i++) {
            skip(100 days);
            for (uint8 j = 0; j < stakers.length; j++) {
                locksToClaim[0] = lockIDs[j];
                vm.startPrank(stakers[j]);
                rewardsClaimed = l2Reward.claimRewards(locksToClaim);

                rewards[j] += rewardsClaimed[0];

                assertEq(rewardsClaimed[0], expectedRewardsFor100Days);
                console2.logUint(rewardsClaimed[0]);
            }
        }

        for (uint8 i = 0; i < 5; i++) {
            assertEq(rewards[i], expectedRewardsFor100Days * 3);
        }

        skip(1 days);

        // positions are expired, rewards zero
        for (uint8 i = 0; i < stakers.length; i++) {
            locksToClaim[0] = lockIDs[i];
            vm.startPrank(stakers[i]);

            rewardsClaimed = l2Reward.claimRewards(locksToClaim);

            assertEq(rewardsClaimed[0], 0);
        }
    }

    function test_claimRewards_multipleStakersStakeDifferentAmountForSimilarDurationAreRewardedAccordinglyAndUnlocked()
        public
    {
        l2Staking.addCreator(address(l2Reward));

        address[3] memory stakers = [address(0x1), address(0x2), address(0x3)];
        uint256[] memory lockIDs = new uint256[](3);
        uint256[] memory rewards = new uint256[](3);

        uint256 funds = convertLiskToBeddows(1000);
        uint256 amount = convertLiskToBeddows(1000);
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

        // All stakers creates a position on deploymentDate, 19740.
        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            l2LiskToken.approve(address(l2Reward), amount * (i + 1));
            lockIDs[i] = l2Reward.createPosition(amount * (i + 1), duration);
            vm.stopPrank();
        }

        uint256[] memory locksToClaim = new uint256[](1);
        uint256[] memory rewardsClaimed = new uint256[](1);

        for (uint8 i = 0; i < 2; i++) {
            skip(100 days);
            for (uint8 j = 0; j < stakers.length; j++) {
                locksToClaim[0] = lockIDs[j];
                vm.startPrank(stakers[j]);
                rewardsClaimed = l2Reward.claimRewards(locksToClaim);

                rewards[j] += rewardsClaimed[0];
            }
        }

        uint256[3] memory expectedRewards =
            [uint256(136529680365296803455), uint256(273059360730593607209), uint256(409589041095890410664)];

        skip(100 days);
        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            l2Reward.deletePosition(lockIDs[i]);
            vm.stopPrank();

            assertEq(l2LiskToken.balanceOf(stakers[i]), amount * (i + 1) + expectedRewards[i]);
        }
    }

    function test_claimRewards_multipleStakersStakeSameAmountForDifferentDurationAreRewardedAsPerTheWeight() public {
        l2Staking.addCreator(address(l2Reward));

        address[2] memory stakers = [address(0x1), address(0x2)];
        uint256[] memory lockIDs = new uint256[](2);
        uint256[] memory rewards = new uint256[](2);

        uint256 funds = convertLiskToBeddows(100);
        uint256 amount = convertLiskToBeddows(100);
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

        // All stakers creates a position on deploymentDate + 1, 19741.
        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            l2LiskToken.approve(address(l2Reward), amount);
            lockIDs[i] = l2Reward.createPosition(amount, duration * (i + 1));
            vm.stopPrank();
        }

        uint256[] memory locksToClaim = new uint256[](1);
        uint256[] memory rewardsClaimed = new uint256[](2);

        skip(2 days);

        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            locksToClaim[0] = lockIDs[i];
            rewardsClaimed = l2Reward.claimRewards(locksToClaim);

            rewards[i] += rewardsClaimed[0];
            vm.stopPrank();
        }

        assertEq(rewards[0], 228234144255585589);
        assertEq(rewards[1], 319711061223866463);

        skip(49 days);

        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            locksToClaim[0] = lockIDs[i];
            rewardsClaimed = l2Reward.claimRewards(locksToClaim);

            rewards[i] += rewardsClaimed[0];
            vm.stopPrank();
        }

        assertEq(rewards[0], 5712406637897779526);
        assertEq(rewards[1], 8260196101828247800);

        skip(49 days);

        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            locksToClaim[0] = lockIDs[i];
            rewardsClaimed = l2Reward.claimRewards(locksToClaim);

            rewards[i] += rewardsClaimed[0];
            vm.stopPrank();
        }

        assertEq(rewards[0], 10927171697410554831);
        assertEq(rewards[1], 16470088576562047769);

        skip(100 days);

        for (uint8 i = 0; i < stakers.length; i++) {
            vm.startPrank(stakers[i]);
            locksToClaim[0] = lockIDs[i];
            rewardsClaimed = l2Reward.claimRewards(locksToClaim);

            rewards[i] += rewardsClaimed[0];
            vm.stopPrank();
        }

        // no additional rewards as lock is expired after 100 days
        assertEq(rewards[0], 10927171697410554831);
        assertEq(rewards[1], 43867348850534650469);
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

    function test_deletePosition_issuesRewardAndUnlocksPosition() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToBeddows(1000);

        uint256 lockID;

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(35));
        l2Reward.fundStakingRewards(convertLiskToBeddows(35), 350, 1);
        vm.stopPrank();

        // staker creates a position on deploymentDate, 19740.
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(100));
        lockID = l2Reward.createPosition(convertLiskToBeddows(100), 120);

        vm.stopPrank();

        skip(150 days);

        uint256 expectedRewards = 11.9 * 10 ** 18;
        // locked amount gets unlocked
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards + convertLiskToBeddows(100);

        // staker deletes position
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

    function test_pauseUnlocking_issuesRewardAndUpdatesGlobalUnlockAmounts() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToBeddows(1000);

        uint256 lockID;

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(35));
        l2Reward.fundStakingRewards(convertLiskToBeddows(35), 350, 1);
        vm.stopPrank();

        // staker creates a position on deploymentDate, 19740.
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(100));
        lockID = l2Reward.createPosition(convertLiskToBeddows(100), 120);
        vm.stopPrank();

        skip(75 days);
        uint256 today = deploymentDate + 75;

        uint256 expectedRewards = 7.4 * 10 ** 18;
        uint256 expectedBalance = l2LiskToken.balanceOf(staker) + expectedRewards;
        uint256 expectedPausedLockingDuration = deploymentDate + 120 - today;

        vm.prank(staker);
        uint256 reward = l2Reward.pauseUnlocking(lockID);

        balance = l2LiskToken.balanceOf(staker);

        LockingPosition memory lockingPosition = l2LockingPosition.getLockingPosition(lockID);

        assertEq(reward, 7.4 * 10 ** 18);
        assertEq(balance, expectedBalance);
        assertEq(l2Reward.pendingUnlockAmount(), 0);
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + 120), 0);
        assertEq(l2Reward.lastClaimDate(lockID), today);
        assertEq(lockingPosition.pausedLockingDuration, expectedPausedLockingDuration);
    }

    function test_resumeUnlocking_onlyOwnerCanBeResumeUnlockingForALockingPosition() public {
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

    function test_resumeUnlocking_onlyExisitingLockingPositionCanBeResumedByAnOwner() public {
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

    function test_resumeUnlocking_issuesRewardAndUpdatesGlobalUnlockAmount() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToBeddows(1000);

        uint256 lockID;

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(35));
        l2Reward.fundStakingRewards(convertLiskToBeddows(35), 350, 1);
        vm.stopPrank();

        // staker creates a position on deploymentDate, 19740.
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(100));
        lockID = l2Reward.createPosition(convertLiskToBeddows(100), 120);
        vm.stopPrank();

        skip(50 days);
        uint256 today = deploymentDate + 50;

        // staker pauses the position
        vm.prank(staker);
        l2Reward.pauseUnlocking(lockID);

        uint256 expectedPausedLockingDuration = deploymentDate + 120 - today;
        uint256 expectedRewards = convertLiskToBeddows(5);

        balance = l2LiskToken.balanceOf(staker);

        skip(50 days);
        today = deploymentDate + 100;

        vm.prank(staker);
        uint256 reward = l2Reward.resumeUnlockingCountdown(lockID);

        uint256 expectedBalance = balance + expectedRewards;

        LockingPosition memory lockingPosition = l2LockingPosition.getLockingPosition(lockID);

        assertEq(lockingPosition.expDate, today + expectedPausedLockingDuration);
        assertEq(l2Reward.pendingUnlockAmount(), convertLiskToBeddows(100));
        assertEq(l2Reward.dailyUnlockedAmounts(today + expectedPausedLockingDuration), convertLiskToBeddows(100));
        assertEq(l2Reward.lastClaimDate(lockID), today);
        assertEq(reward, expectedRewards);
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
        l2Reward.increaseLockingAmount(1, convertLiskToBeddows(10));
    }

    function test_increaseLockingAmount_amountCanOnlyBeIncreasedByAnOwnerForAnExistingLockingPositions() public {
        address staker = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Locking position does not exist");

        vm.prank(staker);
        l2Reward.increaseLockingAmount(1, 1);
    }

    function test_increaseLockingAmount_forActivePositionIncreasesLockedAmountAndWeightByRemainingDurationAndClaimsRewards(
    )
        public
    {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToBeddows(1000);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(35));
        l2Reward.fundStakingRewards(convertLiskToBeddows(35), 350, 1);
        vm.stopPrank();

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(100));
        uint256 lockID = l2Reward.createPosition(convertLiskToBeddows(100), 120);
        vm.stopPrank();

        skip(50 days);

        uint256 amountIncrease = convertLiskToBeddows(35);
        uint256 totalWeightAfterClaim = l2Reward.totalWeight() - 500000;
        uint256 duration = (deploymentDate + 120) - (deploymentDate + 50);
        uint256 totalWeightIncrease = (amountIncrease * (duration + l2Reward.OFFSET())) / 10 ** 16;

        balance = l2LiskToken.balanceOf(staker);

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amountIncrease);
        uint256 reward = l2Reward.increaseLockingAmount(lockID, amountIncrease);
        vm.stopPrank();

        assertEq(l2Reward.totalWeight(), totalWeightAfterClaim + totalWeightIncrease);
        assertEq(l2LiskToken.balanceOf(staker), balance + reward - amountIncrease);
        assertEq(l2Reward.pendingUnlockAmount(), convertLiskToBeddows(135));
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + 120), convertLiskToBeddows(135));
    }

    function test_increaseLockingAmount_forPausedPositionIncreasesTotalWeightByPausedLockingDurationAndClaimsRewards()
        public
    {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToBeddows(1000);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(35));
        l2Reward.fundStakingRewards(convertLiskToBeddows(35), 350, 1);
        vm.stopPrank();

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(100));
        uint256 lockID = l2Reward.createPosition(convertLiskToBeddows(100), 120);
        vm.stopPrank();

        // pausedLockingDuration set to 120
        vm.prank(staker);
        l2Reward.pauseUnlocking(lockID);

        skip(50 days);

        uint256 amountIncrease = convertLiskToBeddows(35);

        uint256 totalWeight = l2Reward.totalWeight();

        uint256 totalWeightIncrease = (amountIncrease * (120 + l2Reward.OFFSET())) / 10 ** 16;

        balance = l2LiskToken.balanceOf(staker);

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amountIncrease);
        uint256 reward = l2Reward.increaseLockingAmount(lockID, amountIncrease);
        vm.stopPrank();

        assertEq(l2LiskToken.balanceOf(staker), balance + reward - amountIncrease);
        assertEq(l2Reward.totalWeight(), totalWeightIncrease + totalWeight);
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

    function test_extendDuration_updatesGlobalsAndClaimRewardsForActivePositionWithExpiryInFuture() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToBeddows(1000);
        uint256 duration = 120;
        uint256 durationExtension = 50;
        uint256 amount = convertLiskToBeddows(100);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(35));
        l2Reward.fundStakingRewards(convertLiskToBeddows(35), 350, 1);
        vm.stopPrank();

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        uint256 lockID = l2Reward.createPosition(amount, duration);
        vm.stopPrank();

        skip(50 days);

        uint256 totalWeightAfterClaim = l2Reward.totalWeight() - 500000;
        uint256 weightIncrease = (amount * durationExtension) / 10 ** 16;
        balance = l2LiskToken.balanceOf(staker);

        vm.startPrank(staker);
        uint256 reward = l2Reward.extendDuration(lockID, durationExtension);
        vm.stopPrank();

        assertEq(l2Reward.totalWeight(), totalWeightAfterClaim + weightIncrease);
        assertEq(l2LiskToken.balanceOf(staker), balance + reward);
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + duration), 0);
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + duration + durationExtension), amount);
    }

    function test_extendDuration_updatesGlobalsAndClaimRewardsForExpiredPositions() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToBeddows(1000);
        uint256 duration = 120;
        uint256 durationExtension = 50;
        uint256 amount = convertLiskToBeddows(100);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(35));
        l2Reward.fundStakingRewards(convertLiskToBeddows(35), 350, 1);
        vm.stopPrank();

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        uint256 lockID = l2Reward.createPosition(amount, duration);
        vm.stopPrank();

        skip(121 days);

        uint256 weightIncrease = (amount * durationExtension) / 10 ** 16;
        balance = l2LiskToken.balanceOf(staker);

        vm.startPrank(staker);
        uint256 reward = l2Reward.extendDuration(lockID, durationExtension);
        vm.stopPrank();

        console2.logUint(reward);

        assertEq(l2LiskToken.balanceOf(staker), balance + reward);
        assertEq(l2Reward.totalWeight(), weightIncrease);

        assertEq(l2Reward.totalAmountLocked(), amount);
        assertEq(l2Reward.pendingUnlockAmount(), amount);
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + duration + durationExtension), amount);
    }

    function test_extendDuration_updatesGlobalsAndClaimRewardsForPausedPositions() public {
        l2Staking.addCreator(address(l2Reward));
        address staker = address(0x1);
        uint256 balance = convertLiskToBeddows(1000);
        uint256 duration = 120;
        uint256 durationExtension = 50;
        uint256 amount = convertLiskToBeddows(100);

        // staker and DAO gets balance
        vm.startPrank(bridge);
        l2LiskToken.mint(staker, balance);
        l2LiskToken.mint(daoTreasury, balance);
        vm.stopPrank();

        // DAO funds staking
        vm.startPrank(daoTreasury);
        l2LiskToken.approve(address(l2Reward), convertLiskToBeddows(35));
        l2Reward.fundStakingRewards(convertLiskToBeddows(35), 350, 1);
        vm.stopPrank();

        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), amount);
        uint256 lockID = l2Reward.createPosition(amount, duration);
        uint256 reward = l2Reward.pauseUnlocking(lockID);
        vm.stopPrank();

        skip(120 days);

        uint256 weightIncrease = (amount * durationExtension) / 10 ** 16;
        uint256 expectedTotalWeight = l2Reward.totalWeight() + weightIncrease;

        balance = l2LiskToken.balanceOf(staker);

        vm.startPrank(staker);
        reward = l2Reward.extendDuration(lockID, durationExtension);
        vm.stopPrank();

        assertEq(l2LiskToken.balanceOf(staker), balance + reward);
        assertEq(l2Reward.totalWeight(), expectedTotalWeight);
        assertEq(l2Reward.dailyUnlockedAmounts(deploymentDate + duration + durationExtension), amount);
    }

    function test_initializeDaoTreasury_onlyOwnerCanInitializeDaoTreasury() public {
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(0x1))
        );
        vm.prank(address(0x1));
        l2Reward.initializeDaoTreasury(address(0x2));
    }

    function convertLiskToBeddows(uint256 lisk) internal pure returns (uint256) {
        return lisk * 10 ** 18;
    }
}
