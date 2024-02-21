// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ISemver } from "../utils/ISemver.sol";

/// @title IL2LiskToken
/// @notice Interface for the L2LiskToken contract.
interface IL2LiskToken {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @title IVotingPowerContract
/// @notice Interface for the VotingPowerContract contract.
interface IVotingPowerContract {
    function adjustVotingPower(
        address ownerAddress,
        LockingPosition memory positionBefore,
        LockingPosition memory positionAfter
    )
        external;
}

/// @title LockingPosition
/// @notice Struct for locking position.
struct LockingPosition {
    uint256 amount;
    uint256 unlockingDuration;
    uint256 expDate;
}

/// @title L2Staking
/// @notice This contract handles the staking functionality for the L2 network.
contract L2Staking is Initializable, OwnableUpgradeable, UUPSUpgradeable, ISemver {
    /// @notice Struct for locking position.
    struct Lock {
        address ownerAddress;
        uint256 amount;
        uint256 unlockingPeriod;
        uint256 expDate;
        uint256 lastClaimDate;
    }

    /// @notice Maximum possible unlocking period (in days).
    uint256 public constant MAX_UNLOCKING_PERIOD = 730; // 2 years

    /// @notice Minimum possible unlocking period (in days).
    uint8 public constant MIN_UNLOCKING_PERIOD = 14;

    /// @notice Total rewards attributed in a year.
    uint256 public constant YEARLY_REWARDS_AMOUNT = 6_000_000 * 10 ** 18; // 6M LSK

    /// @notice Duration to wait if a user unlocks a stake early.
    uint256 public constant EARLY_EXPIRY_PERIOD = 14; // 14 days

    /// @notice The headstart value of stake weight as a linear function of remaining stake duration.
    uint256 public constant HEADSTART = 150;

    /// @notice Total weight of all active staking positions.
    uint256 public totalWeight;

    /// @notice Total amount locked from all active staking positions.
    uint256 public totalAmountLocked;

    /// @notice Total amount requested to unlock (i.e., unlocking period has started).
    uint256 public pendingUnlockAmount;

    /// @notice Date of the last user-made action that caused the update of global variables.
    uint256 public lastTxDate;

    /// @notice Next available lock position index;
    uint32 public lockNonce;

    /// @notice Mapping of staking positions by Id.
    mapping(uint256 => Lock) public locks;

    /// @notice Storing the total weight of all stakes for the end of each day since the beginning of the staking
    ///         process.
    mapping(uint256 => uint256) public totalWeights;

    /// @notice Storing the total amount of the staked tokens for the end of each day since the beginning of the staking
    ///         process.
    mapping(uint256 => uint256) public totalAmountsLocked;

    /// @notice Storing the total amount expiring per day for next MAX_UNLOCKING_PERIOD days.
    mapping(uint256 => uint256) public totalUnlocked;

    /// @notice  Address of the voting power contract.
    address public votingPowerContract;

    /// @notice  Address of the rewards contract.
    address public rewardsContract;

    /// @notice  Address of the L2LiskToken contract.
    address public l2TokenContract;

    /// @notice  Address of the DAO contract.
    address public daoContract;

    /// @notice Semantic version of the contract.
    string public version;

    /// @notice Event emitted when a user tries to claim rewards before the locking period ends.
    event LockingPeriodNotEnded();

    /// @notice Disabling initializers on implementation contract to prevent misuse.
    constructor() {
        _disableInitializers();
    }

    /// @notice Setting global params.
    /// @param _l2TokenContract The address of the L2LiskToken contract.
    /// @param _daoContract The address of the DAO contract.
    function initialize(address _l2TokenContract, address _daoContract) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        l2TokenContract = _l2TokenContract;
        daoContract = _daoContract;
        lastTxDate = todayDay();
        version = "1.0.0";
    }

    /// @notice Ensures that only the owner can authorize a contract upgrade. It reverts if called by any address other
    ///         than the contract owner.
    /// @param _newImplementation The address of the new contract implementation to which the proxy will be upgraded.
    function _authorizeUpgrade(address _newImplementation) internal virtual override onlyOwner { }

    /// @notice Returns the current day.
    /// @return The current day.
    function todayDay() internal view virtual returns (uint256) {
        return block.timestamp / 1 days;
    }

    /// @notice Calculates key of a locking postion.
    /// @return Unique ID of the locking postion.
    function getLockID() internal virtual returns (uint32) {
        lockNonce++;

        return lockNonce;
    }

    /// @notice Whenever a user-made action occurs (lock/unlock/edit) the global state of the contract needs to be
    ///         updated.
    /// @dev This function is called before any state-changing function to update the global state of the contract.
    function updateGlobalState() internal virtual {
        uint256 today = todayDay();

        if (today > lastTxDate) {
            for (uint256 d = lastTxDate; d < today; d++) {
                totalWeights[d] = totalWeight;
                totalAmountsLocked[d] = totalAmountLocked;
                // update total weight due to unlockable and pending unlocks
                totalWeight -= pendingUnlockAmount + HEADSTART * totalUnlocked[d + 1];
                // the amount getting unlocked during the day should not be considered staked anymore
                totalAmountLocked -= totalUnlocked[d + 1];
                pendingUnlockAmount -= totalUnlocked[d + 1];
            }
            lastTxDate = today;
        }
    }

    /// @notice Calculates the rewards for a given staking position.
    /// @param lockId The ID of the staking position.
    /// @return The rewards for the staking position.
    function calculateRewards(uint256 lockId) internal view virtual returns (uint256) {
        Lock memory lockObj = locks[lockId];
        require(lockObj.ownerAddress != address(0x0), "L2Staking: Lock does not exist");

        uint256 duration = 0;
        uint256 lastRewardDay = 0;
        uint256 today = todayDay();

        if (lockObj.unlockingPeriod == 0) {
            // unlock request has been made
            duration = lockObj.expDate - lockObj.lastClaimDate;
            lastRewardDay = Math.min(lockObj.expDate, today);
        } else {
            duration = lockObj.unlockingPeriod;
            lastRewardDay = today;
        }

        uint256 weight = lockObj.amount * (duration > 0 ? duration + HEADSTART : 0);
        uint256 reward = 0;

        for (uint256 d = lockObj.lastClaimDate; d < lastRewardDay; d++) {
            reward += (weight / totalWeights[d]) * dailyReward(d);
            if (lockObj.unlockingPeriod == 0) {
                // unlocking period active,  weight decreasing
                weight -= lockObj.amount;
            }
        }

        return reward;
    }

    /// @notice Claims the rewards for a given staking position.
    /// @param lockId      The ID of the staking position.
    /// @param lockRewards Whether the rewards should be locked or not.
    function claimRewards(uint256 lockId, bool lockRewards) internal virtual {
        Lock memory lockObj = locks[lockId];
        require(lockObj.ownerAddress != address(0x0), "L2Staking: Lock does not exist");

        updateGlobalState();

        uint256 today = todayDay();

        if (lockObj.lastClaimDate >= today) {
            return;
        }

        uint256 reward = calculateRewards(lockId);
        lockObj.lastClaimDate = today;

        // update expiration date
        if (lockObj.unlockingPeriod > 0) {
            lockObj.expDate = today + lockObj.unlockingPeriod;
        }

        if (reward == 0) {
            return;
        }

        // send reward amount to lock.ownerAddress
        IL2LiskToken(l2TokenContract).transfer(lockObj.ownerAddress, reward);

        if (lockRewards == true) { // note that staking position has not expired
                // TODO implemented by Hassaan increaseAmount(stake, reward)
        }
    }

    /// @notice Calculates the penalty for a given staking position.
    /// @param stakeAmount   The amount of the staking position.
    /// @param stakeExpDate  The expiration date of the staking position.
    /// @return The penalty for the staking position.
    function calculatePenalty(uint256 stakeAmount, uint256 stakeExpDate) internal view virtual returns (uint256) {
        uint256 penaltyFactorDuration = ((stakeExpDate - todayDay()) / 2) / MAX_UNLOCKING_PERIOD;
        return stakeAmount * penaltyFactorDuration;
    }

    /// @notice Adjusts the voting power for a given staking position.
    /// @param ownerAddress   The address of the staking position owner.
    /// @param positionBefore The staking position before the adjustment.
    /// @param positionAfter  The staking position after the adjustment.
    function adjustVotingPower(
        address ownerAddress,
        LockingPosition memory positionBefore,
        LockingPosition memory positionAfter
    )
        internal
        onlyOwner
    {
        if (votingPowerContract != address(0)) {
            IVotingPowerContract(votingPowerContract).adjustVotingPower(ownerAddress, positionBefore, positionAfter);
        }
    }

    function initializeVotingPower(address _votingPowerContract) public virtual {
        votingPowerContract = _votingPowerContract;
    }

    /// @notice Locks a staking position.
    /// @param amount The amount to be locked.
    /// @param unlockingPeriod The duration of the locking postion.
    function lockAmount(uint256 amount, uint256 unlockingPeriod) public virtual returns (uint32) {
        require(
            unlockingPeriod >= MIN_UNLOCKING_PERIOD,
            "L2Staking: unlockingPeriod should be at least MIN_UNLOCKING_PEROID"
        );
        require(
            unlockingPeriod <= MAX_UNLOCKING_PERIOD,
            "L2Staking: unlockingPeriod can not be greater than MAX_UNLOCKING_PERIOD"
        );
        updateGlobalState();

        IL2LiskToken(l2TokenContract).transferFrom(msg.sender, address(this), amount);

        Lock memory lockObj = Lock(msg.sender, amount, unlockingPeriod, 0, todayDay());

        totalWeight += amount * (HEADSTART + unlockingPeriod);
        totalAmountLocked += amount;

        adjustVotingPower(
            lockObj.ownerAddress,
            LockingPosition(0, 0, 0),
            LockingPosition(lockObj.amount, lockObj.unlockingPeriod, lockObj.expDate)
        );

        uint32 lockID = getLockID();
        locks[lockID] = lockObj;

        return lockID;
    }

    /// @notice Increase locked amount for an exisiting locking postion.
    /// @param lockId  The ID of the staking position.
    /// @param amountIncrease Increased amount.
    /// @param lockUnclaimedRewards Whether the unclaimed rewards should be locked or not.
    function increaseLockingAmount(uint32 lockId, uint256 amountIncrease, bool lockUnclaimedRewards) public virtual {
        Lock memory lockObj = locks[lockId];
        require(lockObj.ownerAddress != address(0x0), "L2Staking: Lock does not exist");
        require(msg.sender == lockObj.ownerAddress, "L2Staking: Only owner can unlock");
        require(amountIncrease > 0, "L2Staking: Increased amout should be greater than zero");
        require(lockObj.expDate == 0 || lockObj.expDate > todayDay(), "L2Staking: Locking position is already expired");

        if (lockObj.lastClaimDate < todayDay()) {
            claimRewards(lockId, lockUnclaimedRewards);
        }

        increaseAmount(lockId, amountIncrease);
    }

    function increaseAmount(uint32 lockId, uint256 amountIncrease) private {
        Lock memory lockObj = locks[lockId];

        IL2LiskToken(l2TokenContract).transferFrom(lockObj.ownerAddress, address(this), amountIncrease);

        LockingPosition memory previousLocking =
            LockingPosition(lockObj.amount, lockObj.unlockingPeriod, lockObj.expDate);

        lockObj.amount += amountIncrease;

        totalAmountLocked += amountIncrease;

        uint256 duration;

        if (lockObj.expDate == 0) {
            duration = lockObj.unlockingPeriod;
        } else {
            duration = lockObj.expDate - todayDay();
        }

        totalWeight += amountIncrease + (duration + HEADSTART);

        if (lockObj.unlockingPeriod == 0) {
            pendingUnlockAmount += amountIncrease;
            totalUnlocked[lockObj.expDate] += amountIncrease;
        }

        adjustVotingPower(
            lockObj.ownerAddress,
            previousLocking,
            LockingPosition(lockObj.amount, lockObj.unlockingPeriod, lockObj.expDate)
        );
    }

    /// @notice Extends unlocking period for an existing locking position.
    /// @param lockId The ID of the staking position.
    /// @param extendDays The duration by which the staking position is to be extended.
    /// @param lockUnclaimedRewards Whether the unclaimed rewards should be locked or not.
    function extendUnlockingPeriod(uint32 lockId, uint256 extendDays, bool lockUnclaimedRewards) public virtual {
        Lock memory lockObj = locks[lockId];
        require(lockObj.ownerAddress != address(0x0), "L2Staking: Lock does not exist");
        require(msg.sender == lockObj.ownerAddress, "L2Staking: Only owner can unlock");

        claimRewards(lockId, lockUnclaimedRewards);

        LockingPosition memory previousLocking =
            LockingPosition(lockObj.amount, lockObj.unlockingPeriod, lockObj.expDate);

        if (lockObj.expDate == 0) {
            lockObj.unlockingPeriod += extendDays;
        } else {
            if (lockObj.expDate > todayDay()) {
                totalUnlocked[lockObj.expDate] -= lockObj.amount;
            } else {
                totalAmountLocked += lockObj.amount;
            }
        }

        uint256 baseExpiry = Math.max(lockObj.expDate, todayDay());
        lockObj.expDate = baseExpiry + extendDays;

        totalUnlocked[lockObj.expDate] += lockObj.amount;

        totalWeight += extendDays * lockObj.amount;

        adjustVotingPower(
            lockObj.ownerAddress,
            previousLocking,
            LockingPosition(lockObj.amount, lockObj.unlockingPeriod, lockObj.expDate)
        );
    }

    /// @notice Resume locking for an existing staking position.
    /// @param lockId The ID of the staking postion.
    /// @param lockUnclaimedRewards Whether the unclaimed rewards should be locked or not.
    function resumeLocking(uint32 lockId, bool lockUnclaimedRewards) public virtual {
        Lock memory lockObj = locks[lockId];
        require(lockObj.ownerAddress != address(0x0), "L2Staking: Lock does not exist");
        require(msg.sender == lockObj.ownerAddress, "L2Staking: Only owner can unlock");
        require(lockObj.expDate != 0, "L2Staking: Unlocking period has not started");
        require(lockObj.expDate > todayDay(), "L2Staking: Unlocking period has ended, amount unlocked");

        claimRewards(lockId, lockUnclaimedRewards);

        LockingPosition memory previousLocking =
            LockingPosition(lockObj.amount, lockObj.unlockingPeriod, lockObj.expDate);

        lockObj.unlockingPeriod = lockObj.expDate - todayDay();
        lockObj.expDate = 0;

        pendingUnlockAmount -= lockObj.amount;
        totalUnlocked[lockObj.expDate] -= lockObj.amount;

        adjustVotingPower(
            lockObj.ownerAddress,
            previousLocking,
            LockingPosition(lockObj.amount, lockObj.unlockingPeriod, lockObj.expDate)
        );
    }

    /// @notice Returns daily reward for a given day.
    /// @param day The day for which to calculate the reward.
    /// @return The daily reward for the given day.
    function dailyReward(uint256 day) public view virtual returns (uint256) {
        uint256 reward = YEARLY_REWARDS_AMOUNT / 365;
        uint256 cap = totalAmountsLocked[day] / 365;

        return Math.min(reward, cap);
    }

    /// @notice Unlock a staking position.
    /// @param lockId      The ID of the staking position.
    function unlock(uint32 lockId) public virtual {
        Lock memory lockObj = locks[lockId];
        require(lockObj.ownerAddress != address(0x0), "L2Staking: Lock does not exist");
        require(msg.sender == lockObj.ownerAddress, "L2Staking: Only owner can unlock");

        // assign any unclaimed rewards
        claimRewards(lockId, true);

        // update staking position
        LockingPosition memory previousLocking =
            LockingPosition(lockObj.amount, lockObj.unlockingPeriod, lockObj.expDate);
        lockObj.expDate = todayDay() + lockObj.unlockingPeriod;

        // update global variables and arrays
        pendingUnlockAmount += lockObj.amount;
        totalUnlocked[lockObj.expDate] += lockObj.amount;

        // call voting power contract to update voting power
        LockingPosition memory newLocking = LockingPosition(lockObj.amount, lockObj.unlockingPeriod, lockObj.expDate);
        adjustVotingPower(lockObj.ownerAddress, previousLocking, newLocking);
    }

    /// @notice Claim the unlocked amount of a staking position.
    /// @param lockId      The ID of the staking position.
    function claimUnlockedAmount(uint256 lockId) public virtual {
        Lock memory lockObj = locks[lockId];
        require(lockObj.ownerAddress != address(0x0), "L2Staking: Lock does not exist");
        require(msg.sender == lockObj.ownerAddress, "L2Staking: Only owner can claim");
        require(lockObj.unlockingPeriod == 0, "Unlocking period has not started");

        if (lockObj.expDate <= todayDay()) {
            // unlocking is valid
            claimRewards(lockId, false); // send unclaimed rewards
            LockingPosition memory previousLocking =
                LockingPosition(lockObj.amount, lockObj.unlockingPeriod, lockObj.expDate);

            //remove lock from staking entries data structure;
            delete locks[lockId];

            adjustVotingPower(lockObj.ownerAddress, previousLocking, LockingPosition(0, 0, 0));

            // send lockObj.amount to lock.ownerAddress
            IL2LiskToken(l2TokenContract).transfer(lockObj.ownerAddress, lockObj.amount);
        } else {
            // stake did not expire
            emit LockingPeriodNotEnded();
        }
    }

    /// @notice Claim the rewards for a staking position before the expiration date. Because of the early claim,
    ///         the user will be penalized.
    /// @param lockId      The ID of the staking position.
    function claimBeforeExpiration(uint32 lockId) public virtual {
        Lock memory lockObj = locks[lockId];
        require(lockObj.ownerAddress != address(0x0), "L2Staking: Lock does not exist");
        require(msg.sender == lockObj.ownerAddress, "L2Staking: Only owner can claim before expiration");

        uint256 today = todayDay();

        require(lockObj.expDate == 0, "Unlocking period has not started");
        require(lockObj.expDate - today >= EARLY_EXPIRY_PERIOD, "Less than 14 days until unlock");

        claimRewards(lockId, false);

        //calculate penalty, update global variables and arrays
        uint256 penalty = calculatePenalty(lockObj.amount, lockObj.expDate);
        totalUnlocked[lockObj.expDate] -= lockObj.amount;
        totalUnlocked[today + EARLY_EXPIRY_PERIOD] += lockObj.amount - penalty;
        totalWeight -= ((lockObj.expDate - today) + HEADSTART) * lockObj.amount;
        totalWeight += (EARLY_EXPIRY_PERIOD + HEADSTART) * (lockObj.amount - penalty);
        totalAmountLocked -= penalty;
        pendingUnlockAmount -= penalty;

        //update locking position
        LockingPosition memory previousLocking =
            LockingPosition(lockObj.amount, lockObj.unlockingPeriod, lockObj.expDate);
        lockObj.amount -= penalty;
        lockObj.expDate = today + EARLY_EXPIRY_PERIOD;
        LockingPosition memory newLocking = LockingPosition(lockObj.amount, lockObj.unlockingPeriod, lockObj.expDate);

        //remove voting power
        adjustVotingPower(lockObj.ownerAddress, previousLocking, newLocking);

        //send penalty amount to DAO treasury;
        IL2LiskToken(l2TokenContract).transfer(daoContract, penalty);
    }
}
