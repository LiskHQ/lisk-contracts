// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ISemver } from "../utils/ISemver.sol";
import { IL2LockingPosition } from "../interfaces/L2/IL2LockingPosition.sol";
import { IL2Staking } from "../interfaces/L2/IL2Staking.sol";
import { IL2LiskToken } from "../interfaces/L2/IL2LiskToken.sol";

/// @title L2Reward
/// @notice This contract manages and handles L2 Staking Rewards.
contract L2Reward is Initializable, Ownable2StepUpgradeable, UUPSUpgradeable, ISemver {
    /// @notice The offset value of stake weight as a liner function of remaining stake duration.
    uint256 public constant OFFSET = 150;

    /// @notice The default duration in days for which the rewards are added.
    uint16 public constant REWARD_DURATION = 30;

    /// @notice The default delay in days when adding rewards.
    uint16 public constant REWARD_DURATION_DELAY = 1;

    /// @notice Total of weights of all stakes for each day.
    mapping(uint256 => uint256) public totalWeights;

    /// @notice Total of amount expiring for each day.
    mapping(uint256 => uint256) public dailyUnlockedAmounts;

    /// @notice Total of rewards provided for each day.
    mapping(uint256 => uint256) public dailyRewards;

    /// @notice Maintains the date of the last reward date for each locking position.
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

    /// @notice Aggregation of surplus rewards.
    uint256 public rewardsSurplus;

    /// @notice Address of the staking contract.
    address public stakingContract;

    /// @notice Address of the locking position contract.
    address public lockingPositionContract;

    /// @notice Address of the L2 token contract.
    address public l2TokenContract;

    /// @notice Emitted when rewards are added.
    event RewardsAdded(uint256 indexed amount, uint256 indexed duration, uint256 indexed delay);

    /// @notice Emitted when the L2LiskToken contract address is changed.
    event LiskTokenContractAddressChanged(address indexed oldAddress, address indexed newAddress);

    /// @notice Emitted when the Stakin contract address is changed.
    event StakingContractAddressChanged(address indexed oldAddress, address indexed newAddress);

    /// @notice Emitted when the Locking Position contract address is changed.
    event LockingPositionContractAddressChanged(address indexed oldAddress, address indexed newAddress);

    /// @notice Emitted when a position is rewarded.
    event RewardsClaimed(uint256 lockID, uint256 amount);

    /// @notice Represents duration extension for a position.
    struct ExtendedDuration {
        uint256 lockID;
        uint256 durationExtension;
    }

    /// @notice Represents increased lock amount for a position.
    struct IncreasedAmount {
        uint256 lockID;
        uint256 amountIncrease;
    }

    constructor() {
        _disableInitializers();
    }

    /// @notice Ensures that only the owner can authorize a contract upgrade. It reverts if called by any address other
    ///         than the contract owner.
    /// @param _newImplementation The address of the new contract implementation to which the proxy will be upgraded.
    function _authorizeUpgrade(address _newImplementation) internal virtual override onlyOwner { }

    /// @notice Initializes the contract.
    /// @param _l2LiskTokenContract The address of the L2LiskToken contract.
    function initialize(address _l2LiskTokenContract) public initializer {
        require(_l2LiskTokenContract != address(0), "L2Reward: LSK token contract address can not be zero");
        __Ownable2Step_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        l2TokenContract = _l2LiskTokenContract;
        lastTrsDate = todayDay();
        version = "1.0.0";
        emit LiskTokenContractAddressChanged(address(0x0), _l2LiskTokenContract);
    }

    /// @notice Updates global state against user actions.
    /// @dev It is the first call in every public function.
    function updateGlobalState() internal virtual {
        uint256 today = todayDay();

        uint256 d = lastTrsDate;
        if (today <= d) return;

        uint256 cappedRewards;

        for (; d < today; d++) {
            totalWeights[d] = totalWeight;

            cappedRewards = totalAmountLocked / 365;

            // capping in rewards
            if (dailyRewards[d] > cappedRewards) {
                rewardsSurplus += dailyRewards[d] - cappedRewards;
                dailyRewards[d] = cappedRewards;
            }

            // update total weights due to unlockable and pending unlocks
            totalWeight -= pendingUnlockAmount;
            totalWeight -= OFFSET * dailyUnlockedAmounts[d + 1];

            // the amount getting unlocked for a day should not be considered staked anymore
            totalAmountLocked -= dailyUnlockedAmounts[d + 1];
            pendingUnlockAmount -= dailyUnlockedAmounts[d + 1];
        }

        lastTrsDate = today;
    }

    /// @notice Creates a locking position.
    /// @param amount Amount to be locked.
    /// @param duration Duration of the locking position in days.
    /// @return  The ID of the newly created locking position.
    function createPosition(uint256 amount, uint256 duration) public virtual returns (uint256) {
        updateGlobalState();

        // create a new position
        IL2LiskToken(l2TokenContract).transferFrom(msg.sender, address(this), amount);
        IL2LiskToken(l2TokenContract).approve(stakingContract, amount);
        uint256 id = IL2Staking(stakingContract).lockAmount(msg.sender, amount, duration);
        uint256 today = todayDay();
        lastClaimDate[id] = today;

        // update total weight and amount
        totalWeight += amount * (duration + OFFSET);
        totalAmountLocked += amount;
        dailyUnlockedAmounts[today + duration] += amount;
        pendingUnlockAmount += amount;

        return id;
    }

    /// @notice Deletes multiple locking positions.
    /// @param lockIDs The IDs of locking positions.
    function deletePositions(uint256[] memory lockIDs) public virtual {
        updateGlobalState();

        for (uint8 i = 0; i < lockIDs.length; i++) {
            require(
                IL2LockingPosition(lockingPositionContract).ownerOf(lockIDs[i]) == msg.sender,
                "L2Reward: msg.sender does not own the locking position"
            );

            _deletePosition(lockIDs[i]);
        }
    }

    /// @notice Deletes a locking position.
    /// @param lockID The ID of the locking position.
    function _deletePosition(uint256 lockID) internal virtual {
        // claim rewards and updates staking contract
        _claimReward(lockID);
        IL2Staking(stakingContract).unlock(lockID);

        delete lastClaimDate[lockID];
    }

    /// @notice Initiates fast unlock of multiple locking positions.
    /// @param lockIDs The IDs of locking positions.
    function initiateFastUnlock(uint256[] memory lockIDs) public virtual {
        updateGlobalState();

        for (uint8 i = 0; i < lockIDs.length; i++) {
            require(
                IL2LockingPosition(lockingPositionContract).ownerOf(lockIDs[i]) == msg.sender,
                "L2Reward: msg.sender does not own the locking position"
            );

            _initiateFastUnlock(lockIDs[i]);
        }
    }

    /// @notice Initiates a fast unlock of the locking position.
    /// @param lockID The ID of the locking position.
    function _initiateFastUnlock(uint256 lockID) internal virtual {
        // claim rewards and inform staking contract
        _claimReward(lockID);
        IL2LockingPosition.LockingPosition memory lockingPositionBeforeInitiatingFastUnlock =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);
        uint256 penalty = IL2Staking(stakingContract).initiateFastUnlock(lockID);

        // add penalty amout to future rewards
        _addRewards(penalty, REWARD_DURATION, REWARD_DURATION_DELAY);

        uint256 today = todayDay();
        uint256 fastUnlockDuration = IL2Staking(stakingContract).FAST_UNLOCK_DURATION();
        uint256 remainingDuration;

        // update global variables and arrays
        if (lockingPositionBeforeInitiatingFastUnlock.pausedLockingDuration == 0) {
            // removing previous expiration date
            remainingDuration = lockingPositionBeforeInitiatingFastUnlock.expDate - today;
            dailyUnlockedAmounts[lockingPositionBeforeInitiatingFastUnlock.expDate] -=
                lockingPositionBeforeInitiatingFastUnlock.amount;
            pendingUnlockAmount -= lockingPositionBeforeInitiatingFastUnlock.amount;
        } else {
            remainingDuration = lockingPositionBeforeInitiatingFastUnlock.pausedLockingDuration;
        }

        totalWeight -= (remainingDuration + OFFSET) * lockingPositionBeforeInitiatingFastUnlock.amount;
        totalWeight += (fastUnlockDuration + OFFSET) * (lockingPositionBeforeInitiatingFastUnlock.amount - penalty);

        // setting new expiration date
        dailyUnlockedAmounts[today + fastUnlockDuration] += lockingPositionBeforeInitiatingFastUnlock.amount - penalty;
        pendingUnlockAmount += lockingPositionBeforeInitiatingFastUnlock.amount - penalty;
        totalAmountLocked -= penalty;
    }

    /// @notice Calculate rewards of a locking position.
    /// @param lockID The ID of the locking position.
    /// @return uint256 Rewards amount.
    function calculateRewards(uint256 lockID) public view virtual returns (uint256) {
        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        uint256 today = todayDay();
        uint256 rewardableDuration;
        uint256 lastRewardDay;
        uint256 weight;

        if (lockingPosition.pausedLockingDuration == 0) {
            // If rewards are claimed against an expired position that was already claimed after expiry period,
            // rewardableDuration is zero
            (, rewardableDuration) = Math.trySub(lockingPosition.expDate, lastClaimDate[lockID]);

            lastRewardDay = Math.min(lockingPosition.expDate, today);
        } else {
            rewardableDuration = lockingPosition.pausedLockingDuration;
            lastRewardDay = today;
        }

        uint256 reward;

        if (rewardableDuration > 0) {
            weight = lockingPosition.amount * (rewardableDuration + OFFSET);
        } else {
            return reward;
        }

        for (uint256 d = lastClaimDate[lockID]; d < lastRewardDay; d++) {
            reward += (weight * dailyRewards[d]) / totalWeights[d];

            if (lockingPosition.pausedLockingDuration == 0) {
                // unlocking period is active, weight is decreasing
                weight -= lockingPosition.amount;
            }
        }

        return reward;
    }

    /// @notice Claim rewards against multiple locking position.
    /// @param lockIDs The IDs of locking position.
    function claimRewards(uint256[] memory lockIDs) public virtual {
        updateGlobalState();

        for (uint8 i = 0; i < lockIDs.length; i++) {
            require(
                IL2LockingPosition(lockingPositionContract).ownerOf(lockIDs[i]) == msg.sender,
                "L2Reward: msg.sender does not own the locking position"
            );

            _claimReward(lockIDs[i]);
        }
    }

    /// @notice Claim rewards against a locking position.
    /// @param lockID The ID of the locking position.
    function _claimReward(uint256 lockID) internal virtual {
        require(lastClaimDate[lockID] != 0, "L2Reward: Locking position does not exist");

        uint256 today = todayDay();
        uint256 reward;

        if (this.lastClaimDate(lockID) >= today) {
            emit RewardsClaimed(lockID, 0);

            return;
        }

        reward = calculateRewards(lockID);
        emit RewardsClaimed(lockID, reward);

        lastClaimDate[lockID] = today;

        if (reward != 0) {
            IL2LiskToken(l2TokenContract).transfer(msg.sender, reward);
        }
    }

    /// @notice Increases locked amount against multiple locking positions.
    /// @param locks The IDs of locking positions.
    function increaseLockingAmount(IncreasedAmount[] memory locks) public virtual {
        updateGlobalState();

        for (uint8 i = 0; i < locks.length; i++) {
            require(
                IL2LockingPosition(lockingPositionContract).ownerOf(locks[i].lockID) == msg.sender,
                "L2Reward: msg.sender does not own the locking position"
            );

            require(locks[i].amountIncrease > 0, "L2Reward: Increased amount should be greater than zero");

            _increaseLockingAmount(locks[0].lockID, locks[0].amountIncrease);
        }
    }

    /// @notice Increases locked amount against a locking position.
    /// @param lockID The ID of the locking position.
    /// @param amountIncrease The amount to be increased.
    function _increaseLockingAmount(uint256 lockID, uint256 amountIncrease) internal virtual {
        // claim rewards and update staking contract
        _claimReward(lockID);
        IL2LiskToken(l2TokenContract).transferFrom(msg.sender, address(this), amountIncrease);
        IL2LiskToken(l2TokenContract).approve(stakingContract, amountIncrease);
        IL2Staking(stakingContract).increaseLockingAmount(lockID, amountIncrease);

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        uint256 today = todayDay();

        // update globals
        totalAmountLocked += amountIncrease;

        if (lockingPosition.pausedLockingDuration == 0) {
            // duration for active position => lockingPosition.expDate - today;
            totalWeight += amountIncrease * (lockingPosition.expDate - today + OFFSET);
            dailyUnlockedAmounts[lockingPosition.expDate] += amountIncrease;
            pendingUnlockAmount += amountIncrease;
        } else {
            // duration for paused position => lockingPosition.pausedLockingDuration
            totalWeight += amountIncrease * (lockingPosition.pausedLockingDuration + OFFSET);
        }
    }

    /// @notice Extends duration of multiple locking positions.
    /// @param locks The IDs of locking positions and their extended duration.
    function extendDuration(ExtendedDuration[] memory locks) public virtual {
        updateGlobalState();

        for (uint8 i = 0; i < locks.length; i++) {
            require(
                IL2LockingPosition(lockingPositionContract).ownerOf(locks[i].lockID) == msg.sender,
                "L2Reward: msg.sender does not own the locking position"
            );

            require(locks[i].durationExtension > 0, "L2Reward: Extended duration should be greater than zero");

            _extendDuration(locks[i].lockID, locks[i].durationExtension);
        }
    }

    /// @notice Extends duration of a locking position.
    /// @param lockID The ID of the locking position.
    /// @param durationExtension The duration to be extended in days.
    function _extendDuration(uint256 lockID, uint256 durationExtension) internal virtual {
        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        // claim rewards and update staking contract
        _claimReward(lockID);
        IL2Staking(stakingContract).extendLockingDuration(lockID, durationExtension);

        // update globals
        totalWeight += lockingPosition.amount * durationExtension;

        if (lockingPosition.pausedLockingDuration == 0) {
            // locking period has not finished
            if (lockingPosition.expDate > todayDay()) {
                dailyUnlockedAmounts[lockingPosition.expDate] -= lockingPosition.amount;
            }
            // locking period has expired, re-lock amount
            else {
                totalAmountLocked += lockingPosition.amount;
                pendingUnlockAmount += lockingPosition.amount;
                totalWeight += lockingPosition.amount * OFFSET;
            }

            dailyUnlockedAmounts[lockingPosition.expDate + durationExtension] += lockingPosition.amount;
        }
    }

    /// @notice Pauses unlocking of multiple locking positions.
    /// @param lockIDs The IDs of locking positions.
    function pauseUnlocking(uint256[] memory lockIDs) public virtual {
        updateGlobalState();

        for (uint8 i = 0; i < lockIDs.length; i++) {
            require(
                IL2LockingPosition(lockingPositionContract).ownerOf(lockIDs[i]) == msg.sender,
                "L2Reward: msg.sender does not own the locking position"
            );

            _pauseUnlocking(lockIDs[i]);
        }
    }

    /// @notice Pauses unlocking of a locking position.
    /// @param lockID The ID of the locking position.
    function _pauseUnlocking(uint256 lockID) internal virtual {
        // claim rewards and update staking contract
        _claimReward(lockID);
        IL2Staking(stakingContract).pauseRemainingLockingDuration(lockID);

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        // update globals
        pendingUnlockAmount -= lockingPosition.amount;
        dailyUnlockedAmounts[lockingPosition.expDate] -= lockingPosition.amount;
    }

    /// @notice Resumes unlocking of multiple locking positions.
    /// @param lockIDs The IDs of locking positions.
    function resumeUnlockingCountdown(uint256[] memory lockIDs) public virtual {
        updateGlobalState();

        for (uint8 i = 0; i < lockIDs.length; i++) {
            require(
                IL2LockingPosition(lockingPositionContract).ownerOf(lockIDs[i]) == msg.sender,
                "L2Reward: msg.sender does not own the locking position"
            );

            _resumeUnlockingCountdown(lockIDs[i]);
        }
    }

    /// @notice Resumes unlocking of a locking position.
    /// @param lockID The ID of the locking position.
    function _resumeUnlockingCountdown(uint256 lockID) internal virtual {
        // claim rewards and update staking contract
        _claimReward(lockID);
        IL2Staking(stakingContract).resumeCountdown(lockID);

        IL2LockingPosition.LockingPosition memory lockingPosition =
            IL2LockingPosition(lockingPositionContract).getLockingPosition(lockID);

        // update globals
        pendingUnlockAmount += lockingPosition.amount;
        dailyUnlockedAmounts[lockingPosition.expDate] += lockingPosition.amount;
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
        for (uint256 d = today + delay; d < endDate; d++) {
            dailyRewards[d] += dailyReward;
        }
    }

    /// @notice Redistribute unused rewards.
    /// @param amount Amount to be added to daily rewards.
    /// @param duration Duration in days for which the daily rewards is to be added.
    /// @param delay Determines the start day from today till duration from which rewards should be added.
    function addUnusedRewards(uint256 amount, uint16 duration, uint16 delay) public virtual onlyOwner {
        require(delay > 0, "L2Reward: Rewards can only be added from next day or later");
        require(amount <= rewardsSurplus, "L2Reward: Reward amount should not exceed available surplus funds");

        _addRewards(amount, duration, delay);

        rewardsSurplus -= amount;

        emit RewardsAdded(amount, duration, delay);
    }

    /// @notice Adds new daily rewards between provided duration.
    /// @param amount Amount to be added to daily rewards.
    /// @param duration Duration in days for which the daily rewards is to be added.
    /// @param delay Determines the start day from today till duration for which rewards should be added.
    function fundStakingRewards(uint256 amount, uint16 duration, uint16 delay) public virtual onlyOwner {
        require(delay > 0, "L2Reward: Funding should start from next day or later");

        IL2LiskToken(l2TokenContract).transferFrom(msg.sender, address(this), amount);

        _addRewards(amount, duration, delay);

        emit RewardsAdded(amount, duration, delay);
    }

    /// @notice Initializes the LockingPosition address.
    /// @param _lockingPositionContract Address of the locking position contract.
    function initializeLockingPosition(address _lockingPositionContract) public onlyOwner {
        require(lockingPositionContract == address(0), "L2Reward: LockingPosition contract is already initialized");
        require(_lockingPositionContract != address(0), "L2Reward: LockingPosition contract address can not be zero");

        lockingPositionContract = _lockingPositionContract;

        emit LockingPositionContractAddressChanged(address(0x0), lockingPositionContract);
    }

    /// @notice Initializes the L2Staking address.
    /// @param _stakingContract Address of the staking contract.
    function initializeStaking(address _stakingContract) public onlyOwner {
        require(stakingContract == address(0), "L2Reward: Staking contract is already initialized");
        require(_stakingContract != address(0), "L2Reward: Staking contract address can not be zero");

        stakingContract = _stakingContract;

        emit StakingContractAddressChanged(address(0x0), stakingContract);
    }

    /// @notice Returns the current day.
    /// @return The current day.
    function todayDay() public view virtual returns (uint256) {
        return block.timestamp / 1 days;
    }
}
