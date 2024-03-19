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
    }

    function test_initialize() public {
        assertEq(l2Reward.lastTrsDate(), 0);
        assertEq(l2Reward.OFFSET(), 150);
    }

    function test_createPosition() public {
        address alice = address(0x1);

        uint256 duration = 20;
        uint256 amount = convertLiskToBeddows(10);
        uint256 ID;

        vm.startPrank(bridge);
        l2LiskToken.mint(address(l2Reward), convertLiskToBeddows(1000));
        l2LiskToken.mint(alice, convertLiskToBeddows(1000));
        vm.stopPrank();

        vm.startPrank(alice);
        l2LiskToken.approve(address(l2Staking), convertLiskToBeddows(100));
        ID = l2Reward.createPosition(amount, duration);
        vm.stopPrank();

        console2.logUint(ID);
        assertEq(l2Reward.totalWeight(), (amount * (duration + l2Reward.OFFSET())) / convertLiskToBeddows(1));
        assertEq(l2Reward.lastClaimDate(ID), deploymentDate);
        assertEq(l2Reward.totalAmountLocked(), amount);
        assertEq(l2Reward.dailyUnlockedAmounts(l2Reward.lastTrsDate() + duration), amount);
        assertEq(l2Reward.pendingUnlockAmount(), amount);
    }

    function test_onlyOwnerCanDeleteALockingPosition() public {
        address alice = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(alice);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");
        l2Reward.deletePosition(1);
    }

    function test_onlyExistingLockingPositionCanBeDeletedByAnOwner() public {
        address alice = address(0x1);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x1))
        );

        vm.expectRevert("L2Reward: Locking position does not exist");
        vm.prank(alice);
        l2Reward.deletePosition(1);
    }

    function test_calculateRewardsForNotPausedLockingPosition() public {
        skip(deploymentDate + 150 days);
        address alice = address(0x1);

        uint256 amount = convertLiskToBeddows(100);
        uint256 expDate = deploymentDate + 300;
        uint256 pausedLockingDuration = 0;

        LockingPosition memory lockingPosition = LockingPosition(alice, amount, expDate, pausedLockingDuration);

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(L2LockingPosition.getLockingPosition.selector),
            abi.encode(lockingPosition)
        );

        LockingPosition memory result = l2LockingPosition.getLockingPosition(10);

        vm.mockCall(address(l2Reward), abi.encodeWithSelector(l2Reward.lastClaimDate.selector), abi.encode(333));

        console2.logUint(l2Reward.lastClaimDate(1));

        console2.logUint(l2Reward.todayDay());

        console2.logUint(result.amount);
    }

    function test_onlyExistingLockingPositionCanBeClaimedByTheOwner() public {
        address alice = address(0x1);
        uint256 lockID = 1;

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0x0))
        );

        vm.prank(alice);
        vm.expectRevert("L2Reward: msg.sender does not own the locking position");
        l2Reward.claimReward(lockID, false);

        vm.mockCall(
            address(l2LockingPosition), abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector), abi.encode(alice)
        );
        vm.mockCall(address(l2Reward), abi.encodeWithSelector(l2Reward.lastClaimDate.selector), abi.encode(0));
        vm.prank(alice);
        vm.expectRevert("L2Reward: Locking position does not exist");
        l2Reward.claimReward(lockID, true);
    }

    function test_rewardsIsZeroIfLastClaimDateIsToday() public {
        address alice = address(0x1);
        uint256 lockID = 1;
        uint256 amount = convertLiskToBeddows(100);
        uint256 expDate = deploymentDate + 300;
        uint256 pausedLockingDuration = 0;

        LockingPosition memory lockingPosition = LockingPosition(alice, amount, expDate, pausedLockingDuration);

        vm.mockCall(
            address(l2LockingPosition), abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector), abi.encode(alice)
        );

        vm.mockCall(address(l2Reward), abi.encodeWithSelector(l2Reward.lastClaimDate.selector), abi.encode(20000));

        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(L2LockingPosition.getLockingPosition.selector),
            abi.encode(lockingPosition)
        );

        LockingPosition memory result = l2LockingPosition.getLockingPosition(10);

        vm.prank(alice);
        l2Reward.claimReward(lockID, false);
        assertEq(l2LiskToken.balanceOf(alice), 0);
    }

    function test_delayShouldBeGreaterThanZeroWhenFundingStakingRewards() public {
        address alice = address(0x1);

        vm.startPrank(bridge);
        l2LiskToken.mint(alice, convertLiskToBeddows(1000));
        vm.stopPrank();

        vm.expectRevert("L2Reward: Funding should start from next day or later");
        l2Reward.fundStakingRewards(convertLiskToBeddows(3550), 255, 0);
    }

    function test_dailyRewardsShouldBeAddedForTheDuration() public {
        address alice = address(0x1);
        uint256 balanceOfAlice = convertLiskToBeddows(1000);
        vm.startPrank(bridge);
        l2LiskToken.mint(alice, balanceOfAlice);
        vm.stopPrank();

        uint256 amount = convertLiskToBeddows(35);
        uint16 duration = 350;
        uint16 delay = 1;
        vm.startPrank(alice);
        l2LiskToken.approve(address(l2Reward), amount);
        l2Reward.fundStakingRewards(amount, duration, delay);
        vm.stopPrank();

        uint256 dailyReward = amount / duration;
        uint256 today = l2Reward.todayDay();
        uint256 endDate = today + delay + duration;

        for (uint256 d = today + delay; d < endDate; d++) {
            assertEq(l2Reward.dailyRewards(d), convertLiskToBeddows(1) / 10);
        }

        assertEq(l2LiskToken.balanceOf(address(alice)), balanceOfAlice - amount);
        assertEq(l2LiskToken.balanceOf(address(l2Reward)), amount);
    }

    function test_claimRewards() public {
        address alice = address(0x1);
        uint256 duration = 300;

        vm.startPrank(bridge);
        l2LiskToken.mint(address(l2Reward), convertLiskToBeddows(1000));
        l2LiskToken.mint(alice, convertLiskToBeddows(1000));
        vm.stopPrank();

        uint256 amount = convertLiskToBeddows(100);
        uint256 expDate = deploymentDate + 300;
        uint256 pausedLockingDuration = 0;
        uint256 lockID;

        // skip(deploymentDate + 150 days);

        vm.startPrank(alice);
        l2LiskToken.approve(address(l2Staking), amount);
        lockID = l2Reward.createPosition(amount, duration);
        vm.stopPrank();

        console2.logUint(l2Reward.lastTrsDate());

        skip(deploymentDate + 150 days);
        vm.prank(alice);
        l2Reward.claimReward(lockID, false);

        LockingPosition memory position = l2LockingPosition.getLockingPosition(lockID);
        console2.logUint(l2Reward.todayDay());
        console2.logUint(l2Reward.lastClaimDate(lockID));
        console2.logUint(l2Reward.totalWeights(19889));
    }

    function convertLiskToBeddows(uint256 lisk) internal pure returns (uint256) {
        return lisk * 10 ** 18;
    }
}
