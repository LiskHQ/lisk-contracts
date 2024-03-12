// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/// @title IL2LiskToken
/// @notice Interface for the L2LiskToken contract.
interface IL2LiskToken {
    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @title IL2LiskToken
/// @notice Interface for the L2LiskToken contract.
interface IL2Staking {
    function lockAmount(address account, uint256 amount, uint256 duration) external returns (uint256);

    function unlock(uint256 lockID) external;

    function fastUnlock(uint256 lockID) external;

    function increaseAmount(uint256 lockID, uint256 reward) external;

    function increaseLockingAmount(uint256 lockID, uint256 amountIncrease) external;

    function extendDuration(uint256 lockID, uint256 durationExtension) external;

    function pauseRemainingLockingDuration(uint256 lockID) external;

    function resumeUnlockingCountdown(uint256 lockID) external;

    function calculatePenalty(uint256 lockID) external returns (uint256);

    function getFastUnlockDuration() external returns (uint256);
}

/// @title IL2LockingPosition
/// @notice Interface for the L2LockingPosition contract.
interface IL2LockingPosition {
    /// @title LockingPosition
    /// @notice Struct for locking position.
    struct LockingPosition {
        address creator;
        uint256 amount;
        uint256 expDate;
        uint256 pausedLockingDuration;
    }

    function ownerOf(uint256 lockID) external returns (address);

    function getLockingPosition(uint256 positionId) external returns (LockingPosition memory);
}

/// @title L2Reward
/// @notice This contract manages and handles L2 Staking Rewards.
contract L2Reward {
    /// @notice The offset value of stake weight as a liner function of remaining stake duration.
    uint256 public constant OFFSET = 150;

    /// @notice Total weight of all active locking positions.
    uint256 public totalWeight;

    /// @notice Total amount locked from all active locking positions.
    uint256 public totalAmountLocked;

    /// @notice Total amount for staking positions with active locking duration (i.e. countdown is not paused)
    uint256 public pendingUnlockAmount;

    /// @notice Date of the last user-made action that updated the global variables.
    uint256 public lastTrsDate;

    /// @notice The first date when rewards are provided to users.
    uint256 public startingDate;

    /// @notice Indicates if an initial funding for rewards has been provided.
    bool rewardsEnabled;

    /// @notice Total of weights of all stakes for each day.
    uint256[] public totalWeights;

    /// @notice Total of staked amount for each day.
    uint256[] public totalLockedAmounts;

    /// @notice Total of amount expiring for each day.
    uint256[] public dailyUnlockedAmounts;

    /// @notice Total of rewards provided for each day.
    uint256[] public dailyRewards;

    /// @notice Reward cap.
    uint256 public cappedRewards;

    /// @notice Aggregation of surplus rewards.
    uint256 public rewardsSurplus;

    /// @notice Maintains locking positions.
    mapping(uint256 => uint256) public lastClaimDate;

    /// @notice Address of the staking contract.
    address public stakingContract;

    /// @notice Address of the locking position contract.
    address public lockingPositionContract;

    /// @notice Address of the L2 token contract.
    address public l2TokenContract;

    constructor(address _stakingContract, address _lockingPositionContract, address _l2TokenContract) {
        stakingContract = _stakingContract;
        lockingPositionContract = _lockingPositionContract;
        l2TokenContract = _l2TokenContract;

        startingDate = todayDay();
    }

    /// @notice Updates global state against user actions.
    /// @dev It is the first call in every public function.
    function updateGlobalState() internal virtual {
        uint256 today = todayDay();

        uint256 d = Math.max(lastTrsDate, startingDate);
        if (today > d) {
            for (; d < today; d++) {
                totalWeights[d] = totalWeight;
                totalLockedAmounts[d] = totalAmountLocked;

                cappedRewards = totalAmountLocked / 365;

                if (dailyRewards[d] > cappedRewards) {
                    rewardsSurplus += dailyRewards[d] - cappedRewards;
                    dailyRewards[d] = cappedRewards;
                }

                totalWeight -= pendingUnlockAmount;
                totalWeight -= OFFSET * dailyUnlockedAmounts[d + 1];

                totalAmountLocked -= dailyUnlockedAmounts[d + 1];
                pendingUnlockAmount -= dailyUnlockedAmounts[d + 1];
            }
        }

        lastTrsDate = today;
    }

    /// @notice Creates a locking position.
    /// @param amount Amount to be locked.
    /// @param duration Duration of the locking position in days.
    /// @return  The ID of the newly created locking position.
    function createPostion(uint256 amount, uint256 duration) public virtual returns (uint256) {
        updateGlobalState();

        uint256 ID = IL2Staking(stakingContract).lockAmount(msg.sender, amount, duration);
        uint256 today = todayDay();
        uint256 start = Math.max(today, startingDate);

        lastClaimDate[ID] = start;

        totalWeight += amount * (duration + OFFSET);
        totalAmountLocked += amount;
        dailyUnlockedAmounts[startingDate + duration] += amount;
        pendingUnlockAmount += amount;

        return ID;
    }

    /// @notice Deletes a locking position.
    /// @param lockID The ID of the locking position.
    function deletePosition(uint256 lockID) public virtual {
        updateGlobalState();
        require(
            IL2LockingPosition(lockingPositionContract).ownerOf(lockID) == msg.sender,
            "msg.sender does not own the locking postion"
        );
        require(lastClaimDate[lockID] != 0, "Locking postion does not exist");

        claimReward(lockID, false);

        IL2Staking(stakingContract).unlock(lockID);

        delete lastClaimDate[lockID];
    }

    /// @notice Pauses the locking position.
    /// @param lockID The ID of the locking postion.
    function fastUnlock(uint256 lockID) public virtual {
        updateGlobalState();

        require(
            IL2LockingPosition(lockingPositionContract).ownerOf(lockID) == msg.sender,
            "msg.sender does not own the locking postion"
        );

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        claimReward(lockID, false);

        uint256 penalty = IL2Staking(lockingPositionContract).calculatePenalty(lockID);

        IL2Staking(stakingContract).fastUnlock(lockID);

        addRewards(penalty, 30, 1, true);

        uint256 today = todayDay();

        uint256 fastUnlockDuration = IL2Staking(stakingContract).getFastUnlockDuration();

        dailyUnlockedAmounts[lockingPosition.expDate] -= lockingPosition.amount;

        dailyUnlockedAmounts[today + fastUnlockDuration] += lockingPosition.amount - penalty;

        totalWeight -= lockingPosition.amount * (lockingPosition.expDate - today + OFFSET);

        totalWeight += (fastUnlockDuration + OFFSET) * (lockingPosition.amount - penalty);

        totalAmountLocked -= penalty;

        pendingUnlockAmount -= penalty;
    }

    /// @notice Calculate rewards of a locking position.
    /// @param lockID The ID of the locking position.
    /// @return uint256 Rewards amount.
    function calculateRewards(uint256 lockID) public virtual returns (uint256) {
        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        uint256 today = todayDay();
        uint256 remainingLockingDuration;
        uint256 lastRewardDay;
        uint256 weight;

        if (lockingPosition.pausedLockingDuration == 0) {
            remainingLockingDuration = lockingPosition.expDate - lastClaimDate[lockID];
            lastRewardDay = Math.min(lockingPosition.expDate, today);
        } else {
            remainingLockingDuration = lockingPosition.pausedLockingDuration;
            lastRewardDay = today;
        }

        if (remainingLockingDuration > 0) {
            weight = remainingLockingDuration + OFFSET;
        }

        uint256 reward = 0;

        for (uint256 d = lastClaimDate[lockID]; d < lastRewardDay; d++) {
            reward += (weight / totalWeights[d]) * dailyRewards[d];

            if (lockingPosition.pausedLockingDuration == 0) {
                weight -= lockingPosition.amount;
            }
        }

        return reward;
    }

    /// @notice Claim rewads against multiple locking position.
    /// @param lockIDs The IDs of locking position.
    /// @param lockRewards If rewards are to locked.
    function claimRewards(uint256[] calldata lockIDs, bool lockRewards) public virtual {
        updateGlobalState();

        for (uint8 i = 0; i < lockIDs.length; i++) {
            _claimRewards(lockIDs[i], lockRewards);
        }
    }

    /// @notice Claim reward against a locking position.
    /// @param lockID THe ID of the locking postion.
    function claimReward(uint256 lockID, bool lockRewards) public virtual {
        updateGlobalState();

        _claimRewards(lockID, lockRewards);
    }

    function _claimRewards(uint256 lockID, bool lockRewards) internal virtual {
        require(
            IL2LockingPosition(lockingPositionContract).ownerOf(lockID) == msg.sender,
            "msg.sender does not own the locking postion"
        );

        require(lastClaimDate[lockID] != 0, "Locking postion does not exist");

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        uint256 today = todayDay();
        uint256 reward;

        if (lastClaimDate[lockID] < today) {
            reward = calculateRewards(lockID);

            lastClaimDate[lockID] = today;

            if (reward == 0) {
                return;
            }

            IL2LiskToken(l2TokenContract).transfer(msg.sender, reward);

            // stake is expired
            if (lockingPosition.pausedLockingDuration == 0 && lockingPosition.expDate < today) {
                return;
            }

            if (lockRewards) {
                IL2LiskToken(l2TokenContract).transfer(msg.sender, reward);
            }
        }
    }

    /// @notice Increases locked amount against a locking position.
    /// @param lockID The ID of the locking position.
    /// @param amountIncrease The amount to be increased.
    /// @param restakeUnclaimedRewards If any unclaimed rewards should be restaked.
    function increaseLockingAmount(
        uint256 lockID,
        uint256 amountIncrease,
        bool restakeUnclaimedRewards
    )
        public
        virtual
    {
        updateGlobalState();

        require(
            IL2LockingPosition(lockingPositionContract).ownerOf(lockID) == msg.sender,
            "msg.sender does not own the locking postion"
        );

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        claimReward(lockID, restakeUnclaimedRewards);

        IL2Staking(stakingContract).increaseLockingAmount(lockID, amountIncrease);

        uint256 today = todayDay();

        if (lockingPosition.pausedLockingDuration == 0) {
            // duration = lockingPosition.expDate - today;
            totalWeight += amountIncrease * (lockingPosition.expDate - today + OFFSET);
            dailyUnlockedAmounts[lockingPosition.expDate] += amountIncrease;
            pendingUnlockAmount += amountIncrease;
        } else {
            // duration = lockingPosition.pausedLockingDuration
            totalWeight += amountIncrease * (lockingPosition.pausedLockingDuration + OFFSET);
        }
    }

    /// @notice Extends duration of a locking position.
    /// @param lockID The ID of the locking position.
    /// @param durationExtension The duration to be extended in days.
    /// @param restakeUnclaimedRewards If any unclaimed rewards should be restaked.
    function extendDuration(uint256 lockID, uint256 durationExtension, bool restakeUnclaimedRewards) public virtual {
        updateGlobalState();

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        require(
            IL2LockingPosition(lockingPositionContract).ownerOf(lockID) == msg.sender,
            "msg.sender does not own the locking postion"
        );

        claimReward(lockID, restakeUnclaimedRewards);

        IL2Staking(stakingContract).extendDuration(lockID, durationExtension);

        totalWeight += lockingPosition.amount * durationExtension;

        if (lockingPosition.pausedLockingDuration == 0) {
            if (lockingPosition.expDate > todayDay()) {
                dailyUnlockedAmounts[lockingPosition.expDate] -= lockingPosition.amount;
            } else {
                totalAmountLocked += lockingPosition.amount;
                pendingUnlockAmount += lockingPosition.amount;
            }
        }

        dailyUnlockedAmounts[lockingPosition.expDate + durationExtension] += lockingPosition.amount;
    }

    /// @notice Pauses unlocking of a locking position.
    /// @param lockID The ID of the locking position.
    /// @param restakeUnclaimedRewards If any unclaimed rewards should be restaked.
    function pauseUnlocking(uint256 lockID, bool restakeUnclaimedRewards) public virtual {
        updateGlobalState();

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        require(
            IL2LockingPosition(lockingPositionContract).ownerOf(lockID) == msg.sender,
            "msg.sender does not own the locking postion"
        );

        claimReward(lockID, restakeUnclaimedRewards);

        IL2Staking(stakingContract).pauseRemainingLockingDuration(lockID);

        pendingUnlockAmount -= lockingPosition.amount;
        dailyUnlockedAmounts[lockingPosition.expDate] -= lockingPosition.amount;
    }

    /// @notice Resumes unlocking of a locking position.
    /// @param lockID The ID of the locking position.
    /// @param restakeUnclaimedRewards If any unclaimed rewards should be restaked.
    function resumeUnlockingCountdown(uint256 lockID, bool restakeUnclaimedRewards) public virtual {
        updateGlobalState();

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        require(
            IL2LockingPosition(lockingPositionContract).ownerOf(lockID) == msg.sender,
            "msg.sender does not own the locking postion"
        );

        claimReward(lockID, restakeUnclaimedRewards);

        IL2Staking(stakingContract).resumeUnlockingCountdown(lockID);

        pendingUnlockAmount += lockingPosition.amount;
        dailyUnlockedAmounts[lockingPosition.expDate] += lockingPosition.amount;
    }

    /// @notice Registers existing locking position.
    /// @param lockID The ID of the locking position.
    function registerLockingID(uint256 lockID) public virtual {
        updateGlobalState();

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        require(
            IL2LockingPosition(lockingPositionContract).ownerOf(lockID) == msg.sender,
            "msg.sender does not own the locking postion"
        );

        uint256 today = todayDay();
        uint256 start = Math.max(today, startingDate);
        lastClaimDate[lockID] = start;

        uint256 duration;

        if (lockingPosition.pausedLockingDuration == 0) {
            duration = lockingPosition.expDate - today;
        } else {
            duration = lockingPosition.pausedLockingDuration;
        }

        totalWeight += lockingPosition.amount * (duration + OFFSET);
        totalAmountLocked += lockingPosition.amount;
        dailyUnlockedAmounts[startingDate + duration] += lockingPosition.amount;
        pendingUnlockAmount += lockingPosition.amount;
    }

    /// @notice Adds daily rewards between provided duration.
    /// @param amount Amount to be added to daily rewards.
    /// @param duration Duration in days for which the daily rewards is to be added.
    /// @param delay Determines the start day from today till duration for whom rewards should be added.
    /// @param newReward Whether it is a new reward, updates surplus if not a new reward.
    function addRewards(uint256 amount, uint8 duration, uint16 delay, bool newReward) internal virtual {
        require(delay > 0, "Funding should start from next day or later");

        uint256 dailyReward = amount / duration;

        uint256 today = todayDay();
        uint256 endDate = today + delay + duration;
        for (uint256 d = today + duration; d < endDate; d++) {
            dailyRewards[d] += dailyReward;
        }

        if (!newReward) {
            rewardsSurplus -= amount;
        }
    }

    /// @notice Adds a new daily rewards between provided duration.
    /// @param amount Amount to be added to daily rewards.
    /// @param duration Duration in days for which the daily rewards is to be added.
    /// @param delay Determines the start day from today till duration for whom rewards should be added.
    function fundStakingRewards(uint256 amount, uint8 duration, uint16 delay) public virtual {
        require(delay > 0, "Funding should start from next day or later");

        IL2LiskToken(l2TokenContract).transferFrom(msg.sender, address(this), amount);

        addRewards(amount, duration, delay, true);
    }

    /// @notice Returns the current day.
    /// @return The current day.
    function todayDay() internal view virtual returns (uint256) {
        return block.timestamp / 1 days;
    }
}
