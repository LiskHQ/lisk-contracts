// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ISemver } from "../utils/ISemver.sol";

/// @title IL2LiskToken
/// @notice Interface for the L2LiskToken contract.
interface IL2LiskToken {
    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);
}

/// @title IL2LiskToken
/// @notice Interface for the L2LiskToken contract.
interface IL2Staking {
    function lockAmount(address account, uint256 amount, uint256 duration) external returns (uint256);

    function unlock(uint256 lockID) external;

    function initiateFastUnlock(uint256 lockID) external returns (uint256);

    function increaseAmount(uint256 lockID, uint256 reward) external;

    function increaseLockingAmount(uint256 lockID, uint256 amountIncrease) external;

    function extendLockingDuration(uint256 lockID, uint256 durationExtension) external;

    function pauseRemainingLockingDuration(uint256 lockID) external;

    function resumeCountdown(uint256 lockID) external;

    function calculatePenalty(uint256 lockID) external returns (uint256);

    function FAST_UNLOCK_DURATION() external returns (uint256);
}

/// @title IL2LockingPosition
/// @notice Interface for the L2LockingPosition contract.
interface IL2LockingPosition {
    ///  @title LockingPosition
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
contract L2Reward is Initializable, Ownable2StepUpgradeable, UUPSUpgradeable, ISemver {
    /// @notice The offset value of stake weight as a liner function of remaining stake duration.
    uint256 public constant OFFSET = 150;

    /// @notice The factor by which weight is maintained.
    uint256 public constant WEIGHT_FACTOR = 10 ** 16;

    /// @notice The default duration in days for which the rewards are added.
    uint16 public constant REWARD_DURATION = 30;

    /// @notice The default delay in days when adding rewards.
    uint16 public constant REWARD_DURATION_DELAY = 1;

    /// @notice Total of weights of all stakes for each day.
    mapping(uint256 => uint256) public totalWeights;

    /// @notice Total of staked amount for each day.
    mapping(uint256 => uint256) public totalLockedAmounts;

    /// @notice Total of amount expiring for each day.
    mapping(uint256 => uint256) public dailyUnlockedAmounts;

    /// @notice Total of rewards provided for each day.
    mapping(uint256 => uint256) public dailyRewards;

    /// @notice Maintains locking positions.
    mapping(uint256 => uint256) public lastClaimDate;

    /// @notice Total weight of all active locking positions.
    uint256 public totalWeight;

    /// @notice Total amount locked from all active locking positions.
    uint256 public totalAmountLocked;

    /// @notice Total amount for staking positions with active locking duration (i.e. countdown is not paused)
    uint256 public pendingUnlockAmount;

    /// @notice Date of the last user-made action that updated the global variables.
    uint256 public lastTrsDate;

    /// @notice Semantic version of the contract.
    string public version;

    /// @notice Reward cap.
    uint256 public cappedRewards;

    /// @notice Aggregation of surplus rewards.
    uint256 public rewardsSurplus;

    /// @notice Address of the staking contract.
    address public stakingContract;

    /// @notice Address of the locking position contract.
    address public lockingPositionContract;

    /// @notice Address of the DAO contract.
    address public daoTreasury;

    /// @notice Address of the L2 token contract.
    address public l2TokenContract;

    constructor() {
        _disableInitializers();
    }

    /// @notice Ensures that only the owner can authorize a contract upgrade. It reverts if called by any address other
    ///         than the contract owner.
    /// @param _newImplementation The address of the new contract implementation to which the proxy will be upgraded.
    function _authorizeUpgrade(address _newImplementation) internal virtual override onlyOwner { }

    function initialize(address _l2LiskTokenContract) public initializer {
        require(_l2LiskTokenContract != address(0), "L2Reward: LSK token contract address can not be zero");
        __Ownable2Step_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        l2TokenContract = _l2LiskTokenContract;
        lastTrsDate = todayDay();
    }

    /// @notice Updates global state against user actions.
    /// @dev It is the first call in every public function.
    function updateGlobalState() internal virtual {
        uint256 today = todayDay();

        uint256 d = lastTrsDate;
        if (today > d) {
            for (; d < today; d++) {
                totalWeights[d] = totalWeight;
                totalLockedAmounts[d] = totalAmountLocked;

                cappedRewards = totalAmountLocked / 365;

                if (dailyRewards[d] > cappedRewards) {
                    rewardsSurplus += dailyRewards[d] - cappedRewards;
                    dailyRewards[d] = cappedRewards;
                }

                totalWeight -= pendingUnlockAmount / WEIGHT_FACTOR;
                totalWeight -= (OFFSET * dailyUnlockedAmounts[d + 1]) / WEIGHT_FACTOR;

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
    function createPosition(uint256 amount, uint256 duration) public virtual returns (uint256) {
        updateGlobalState();

        IL2LiskToken(l2TokenContract).transferFrom(msg.sender, address(this), amount);
        IL2LiskToken(l2TokenContract).approve(stakingContract, amount);

        uint256 ID = IL2Staking(stakingContract).lockAmount(msg.sender, amount, duration);
        uint256 today = todayDay();
        uint256 start = Math.max(today, lastTrsDate);

        lastClaimDate[ID] = start;

        totalWeight += (amount * (duration + OFFSET)) / WEIGHT_FACTOR;
        totalAmountLocked += amount;
        dailyUnlockedAmounts[lastTrsDate + duration] += amount;
        pendingUnlockAmount += amount;

        return ID;
    }

    /// @notice Deletes a locking position.
    /// @param lockID The ID of the locking position.
    function deletePosition(uint256 lockID) public virtual {
        updateGlobalState();
        require(
            IL2LockingPosition(lockingPositionContract).ownerOf(lockID) == msg.sender,
            "L2Reward: msg.sender does not own the locking position"
        );

        _claimReward(lockID);

        IL2Staking(stakingContract).unlock(lockID);

        delete lastClaimDate[lockID];
    }

    /// @notice Pauses the locking position.
    /// @param lockID The ID of the locking position.
    function fastUnlock(uint256 lockID) public virtual {
        updateGlobalState();

        require(
            IL2LockingPosition(lockingPositionContract).ownerOf(lockID) == msg.sender,
            "L2Reward: msg.sender does not own the locking position"
        );

        _claimReward(lockID);

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        uint256 penalty = IL2Staking(stakingContract).initiateFastUnlock(lockID);

        _addRewards(penalty, REWARD_DURATION, REWARD_DURATION_DELAY);

        uint256 today = todayDay();

        uint256 fastUnlockDuration = IL2Staking(stakingContract).FAST_UNLOCK_DURATION();

        dailyUnlockedAmounts[lockingPosition.expDate] -= lockingPosition.amount;

        dailyUnlockedAmounts[today + fastUnlockDuration] += lockingPosition.amount - penalty;

        totalWeight -= (lockingPosition.amount * (lockingPosition.expDate - today + OFFSET)) / WEIGHT_FACTOR;

        totalWeight += ((fastUnlockDuration + OFFSET) * (lockingPosition.amount - penalty)) / WEIGHT_FACTOR;

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
            weight = (lockingPosition.amount * (remainingLockingDuration + OFFSET)) / WEIGHT_FACTOR;
        }

        uint256 reward = 0;

        for (uint256 d = lastClaimDate[lockID]; d < lastRewardDay; d++) {
            reward += (weight * dailyRewards[d]) / totalWeights[d];

            if (lockingPosition.pausedLockingDuration == 0) {
                weight -= lockingPosition.amount / WEIGHT_FACTOR;
            }
        }

        return reward;
    }

    /// @notice Claim rewards against multiple locking position.
    /// @param lockIDs The IDs of locking position.
    function claimRewards(uint256[] memory lockIDs) public virtual returns (uint256[] memory) {
        updateGlobalState();

        uint256[] memory rewards = new uint256[](lockIDs.length);

        for (uint8 i = 0; i < lockIDs.length; i++) {
            require(
                IL2LockingPosition(lockingPositionContract).ownerOf(lockIDs[i]) == msg.sender,
                "L2Reward: msg.sender does not own the locking position"
            );

            rewards[i] = _claimReward(lockIDs[i]);
        }

        return rewards;
    }

    function _claimReward(uint256 lockID) internal virtual returns (uint256) {
        require(this.lastClaimDate(lockID) != 0, "L2Reward: Locking position does not exist");

        uint256 today = todayDay();
        uint256 reward;

        if (this.lastClaimDate(lockID) >= today) {
            return reward;
        }

        reward = calculateRewards(lockID);

        lastClaimDate[lockID] = today;

        if (reward != 0) {
            IL2LiskToken(l2TokenContract).transfer(msg.sender, reward);
        }

        return reward;
    }

    /// @notice Increases locked amount against a locking position.
    /// @param lockID The ID of the locking position.
    /// @param amountIncrease The amount to be increased.
    /// @return uint256 Rewards amount.
    function increaseLockingAmount(uint256 lockID, uint256 amountIncrease) public virtual returns (uint256) {
        updateGlobalState();

        require(
            IL2LockingPosition(lockingPositionContract).ownerOf(lockID) == msg.sender,
            "L2Reward: msg.sender does not own the locking position"
        );

        require(amountIncrease >= 10 ** 16, "L2Reward: Increased amount should be greater than or equal to 10^16");

        uint256 reward = _claimReward(lockID);

        IL2LiskToken(l2TokenContract).transferFrom(msg.sender, address(this), amountIncrease);
        IL2LiskToken(l2TokenContract).approve(stakingContract, amountIncrease);

        IL2Staking(stakingContract).increaseLockingAmount(lockID, amountIncrease);

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        uint256 today = todayDay();

        if (lockingPosition.pausedLockingDuration == 0) {
            // duration for active position => lockingPosition.expDate - today;
            totalWeight += (amountIncrease * (lockingPosition.expDate - today + OFFSET)) / WEIGHT_FACTOR;
            dailyUnlockedAmounts[lockingPosition.expDate] += amountIncrease;
            pendingUnlockAmount += amountIncrease;
        } else {
            // duration for paused position => lockingPosition.pausedLockingDuration
            totalWeight += (amountIncrease * (lockingPosition.pausedLockingDuration + OFFSET)) / WEIGHT_FACTOR;
        }

        return reward;
    }

    /// @notice Extends duration of a locking position.
    /// @param lockID The ID of the locking position.
    /// @param durationExtension The duration to be extended in days.
    /// @return uint256 Rewards amount.
    function extendDuration(uint256 lockID, uint256 durationExtension) public virtual returns (uint256) {
        updateGlobalState();

        require(
            IL2LockingPosition(lockingPositionContract).ownerOf(lockID) == msg.sender,
            "L2Reward: msg.sender does not own the locking position"
        );

        require(durationExtension > 0, "L2Reward: Extended duration should be greater than zero");

        uint256 reward = _claimReward(lockID);

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        IL2Staking(stakingContract).extendLockingDuration(lockID, durationExtension);

        totalWeight += (lockingPosition.amount * durationExtension) / WEIGHT_FACTOR;

        if (lockingPosition.pausedLockingDuration == 0) {
            if (lockingPosition.expDate > todayDay()) {
                dailyUnlockedAmounts[lockingPosition.expDate] -= lockingPosition.amount;
            } else {
                totalAmountLocked += lockingPosition.amount;
                pendingUnlockAmount += lockingPosition.amount;
            }
        }

        dailyUnlockedAmounts[lockingPosition.expDate + durationExtension] += lockingPosition.amount;

        return reward;
    }

    /// @notice Pauses unlocking of a locking position.
    /// @param lockID The ID of the locking position.
    /// @return Reward amount against the locking position.
    function pauseUnlocking(uint256 lockID) public virtual returns (uint256) {
        updateGlobalState();

        require(
            IL2LockingPosition(lockingPositionContract).ownerOf(lockID) == msg.sender,
            "L2Reward: msg.sender does not own the locking position"
        );

        uint256 reward = _claimReward(lockID);

        IL2Staking(stakingContract).pauseRemainingLockingDuration(lockID);

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        pendingUnlockAmount -= lockingPosition.amount;
        dailyUnlockedAmounts[lockingPosition.expDate] -= lockingPosition.amount;

        return reward;
    }

    /// @notice Resumes unlocking of a locking position.
    /// @param lockID The ID of the locking position.
    /// @return Reward amount against the locking position.
    function resumeUnlockingCountdown(uint256 lockID) public virtual returns (uint256) {
        updateGlobalState();

        require(
            IL2LockingPosition(lockingPositionContract).ownerOf(lockID) == msg.sender,
            "L2Reward: msg.sender does not own the locking position"
        );

        uint256 reward = _claimReward(lockID);

        IL2Staking(stakingContract).resumeCountdown(lockID);

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        pendingUnlockAmount += lockingPosition.amount;
        dailyUnlockedAmounts[lockingPosition.expDate] += lockingPosition.amount;

        return reward;
    }

    /// @notice Adds daily rewards between provided duration.
    /// @param amount Amount to be added to daily rewards.
    /// @param duration Duration in days for which the daily rewards is to be added.
    /// @param delay Determines the start day from today till duration for whom rewards should be added.
    function _addRewards(uint256 amount, uint16 duration, uint16 delay) internal virtual {
        require(delay > 0, "Funding should start from next day or later");

        uint256 dailyReward = amount / duration;
        uint256 today = todayDay();
        uint256 endDate = today + delay + duration;
        for (uint256 d = today + delay; d < endDate; d += delay) {
            dailyRewards[d] += dailyReward;
        }
    }

    /// @notice Adds daily rewards between provided duration and resets surplus rewards.
    /// @param amount Amount to be added to daily rewards.
    /// @param duration Duration in days for which the daily rewards is to be added.
    /// @param delay Determines the start day from today till duration from whom rewards should be added.
    function addRewards(uint256 amount, uint16 duration, uint16 delay) public virtual {
        require(msg.sender == daoTreasury, "L2Reward: Rewards can only be added by DAO treasury");
        require(delay > 0, "L2Reward: Rewards can only be added from next day or later");

        require(amount > rewardsSurplus, "L2Reward: Reward amount should exceed available surplus funds");

        _addRewards(amount, duration, delay);

        rewardsSurplus = 0;
    }

    /// @notice Adds new daily rewards between provided duration.
    /// @param amount Amount to be added to daily rewards.
    /// @param duration Duration in days for which the daily rewards is to be added.
    /// @param delay Determines the start day from today till duration for whom rewards should be added.
    function fundStakingRewards(uint256 amount, uint16 duration, uint16 delay) public virtual {
        require(msg.sender == daoTreasury, "L2Reward: Funds can only be added by DAO treasury");
        require(delay > 0, "L2Reward: Funding should start from next day or later");

        IL2LiskToken(l2TokenContract).transferFrom(msg.sender, address(this), amount);

        _addRewards(amount, duration, delay);
    }

    /// @notice Initializes the Lisk DAO Treasury address.
    /// @param _daoTreasury The treasury address of the Lisk DAO.
    function initializeDaoTreasury(address _daoTreasury) public onlyOwner {
        require(daoTreasury == address(0), "L2Reward: Lisk DAO Treasury contract is already initialized");
        require(_daoTreasury != address(0), "L2Reward: Lisk DAO Treasury contract address can not be zero");

        daoTreasury = _daoTreasury;
    }

    /// @notice Initializes the LockingPosition address.
    /// @param _lockingPositionContract Address of the locking position contract.
    function initializeLockingPosition(address _lockingPositionContract) public onlyOwner {
        require(lockingPositionContract == address(0), "L2Reward: LockingPosition contract is already initialized");
        require(_lockingPositionContract != address(0), "L2Reward: LockingPosition contract address can not be zero");

        lockingPositionContract = _lockingPositionContract;
    }

    /// @notice Initializes the L2Staking address.
    /// @param _stakingContract Address of the staking contract.
    function initializeStaking(address _stakingContract) public onlyOwner {
        require(stakingContract == address(0), "L2Reward: Staking contract is already initialized");
        require(_stakingContract != address(0), "L2Reward: Staking contract address can not be zero");

        stakingContract = _stakingContract;
    }

    /// @notice Returns the current day.
    /// @return The current day.
    function todayDay() public view virtual returns (uint256) {
        return block.timestamp / 1 days;
    }
}
