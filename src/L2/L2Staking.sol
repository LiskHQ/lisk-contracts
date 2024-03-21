// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { LockingPosition } from "./L2LockingPosition.sol";
import { ISemver } from "../utils/ISemver.sol";

/// @title IL2LiskToken
/// @notice Interface for the L2LiskToken contract.
interface IL2LiskToken {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

/// @title IL2LockingPosition
/// @notice Interface for the L2LockingPosition contract.
interface IL2LockingPosition {
    function createLockingPosition(
        address creator,
        address owner,
        uint256 amount,
        uint256 lockingDuration
    )
        external
        returns (uint256);
    function modifyLockingPosition(
        uint256 positionId,
        uint256 amount,
        uint256 expDate,
        uint256 pausedLockingDuration
    )
        external;
    function removeLockingPosition(uint256 positionId) external;
    function getLockingPosition(uint256 positionId) external view returns (LockingPosition memory);
    function getAllLockingPositionsByOwner(address owner) external view returns (LockingPosition[] memory);
    function ownerOf(uint256 tokenId) external view returns (address);
}

/// @title L2Staking
/// @notice This contract handles the staking functionality for the L2 network.
contract L2Staking is Initializable, Ownable2StepUpgradeable, UUPSUpgradeable, ISemver {
    /// @notice Minimum possible locking duration (in days).
    uint32 public constant MIN_LOCKING_DURATION = 14;

    /// @notice Maximum possible locking duration (in days).
    uint32 public constant MAX_LOCKING_DURATION = 730; // 2 years

    /// @notice Emergency locking duration to enable fast unlock option (in days).
    uint32 public constant FAST_UNLOCK_DURATION = 3;

    /// @notice Specifies the part of the locked amount that is subject to penalty in case of fast unlock.
    uint32 public constant PENALTY_DENOMINATOR = 2;

    /// @notice Mapping of addresses to boolean values indicating whether the address is allowed to create locking
    ///         positions.
    mapping(address => bool) public allowedCreators;

    /// @notice  Address of the L2LiskToken contract.
    address public l2LiskTokenContract;

    /// @notice Address of the Locking Position contract.
    address public lockingPositionContract;

    /// @notice The treasury address of the Lisk DAO.
    address public daoTreasury;

    /// @notice Semantic version of the contract.
    string public version;

    /// @notice Disabling initializers on implementation contract to prevent misuse.
    constructor() {
        _disableInitializers();
    }

    /// @notice Setting global params.
    /// @param _l2LiskTokenContract The address of the L2LiskToken contract.
    function initialize(address _l2LiskTokenContract) public initializer {
        require(_l2LiskTokenContract != address(0), "L2Staking: LSK token contract address can not be zero");
        __Ownable2Step_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        l2LiskTokenContract = _l2LiskTokenContract;
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

    /// @notice Returns whether the given locking position is null. Locking position is null if all its fields are
    ///         initialized to 0 or address(0).
    /// @param position Locking position to be checked.
    /// @return Whether the given locking position is null.
    function isLockingPositionNull(LockingPosition memory position) internal view virtual returns (bool) {
        // We are using == to compare with 0 because we want to check if the fields are initialized to 0 or address(0).
        // slither-disable-next-line incorrect-equality
        return position.creator == address(0) && position.amount == 0 && position.expDate == 0
            && position.pausedLockingDuration == 0;
    }

    /// @notice Returns whether the locking position can be modified by the caller. A position can only be modified by
    ///         the owner if the staking contract is the creator. If the position was not created by the staking
    ///         contract, it can only be modified by the creator.
    /// @param lockId The ID of the locking position.
    /// @param lock The locking position to be checked.
    /// @return Whether the locking position can be modified by the caller.
    function canLockingPositionBeModified(
        uint256 lockId,
        LockingPosition memory lock
    )
        internal
        view
        virtual
        returns (bool)
    {
        address ownerOfLock = (IL2LockingPosition(lockingPositionContract)).ownerOf(lockId);
        bool condition1 = allowedCreators[msg.sender] && lock.creator == msg.sender;
        bool condition2 = ownerOfLock == msg.sender && lock.creator == address(this);

        if (condition1 || condition2) {
            return true;
        }
        return false;
    }

    /// @notice Calculates the penalty for the given amount and expiration date.
    /// @param amount The amount for which the penalty is calculated.
    /// @param expDate The expiration date for which the penalty is calculated.
    /// @return The penalty for the given amount and expiration date.
    function calculatePenalty(uint256 amount, uint256 expDate) internal view virtual returns (uint256) {
        uint256 today = todayDay();
        if (expDate <= today) {
            return 0;
        }
        return (amount * (expDate - today)) / (MAX_LOCKING_DURATION * PENALTY_DENOMINATOR);
    }

    /// @notice Returns the remaining locking duration for the given locking position.
    /// @param lock The locking position for which the remaining locking duration is returned.
    /// @return The remaining locking duration for the given locking position.
    function remainingLockingDuration(LockingPosition memory lock) internal view virtual returns (uint256) {
        if (lock.pausedLockingDuration == 0) {
            uint256 today = todayDay();
            if (lock.expDate <= today) {
                return 0;
            } else {
                return lock.expDate - today;
            }
        } else {
            return lock.pausedLockingDuration;
        }
    }

    /// @notice Initializes the L2LockingPosition contract address.
    /// @param _lockingPositionContract The address of the L2LockingPosition contract.
    function initializeLockingPosition(address _lockingPositionContract) public onlyOwner {
        require(lockingPositionContract == address(0), "L2Staking: Locking Position contract is already initialized");
        require(_lockingPositionContract != address(0), "L2Staking: Locking Position contract address can not be zero");
        lockingPositionContract = _lockingPositionContract;
    }

    /// @notice Initializes the Lisk DAO Treasury address.
    /// @param _daoTreasury The treasury address of the Lisk DAO.
    function initializeDaoTreasury(address _daoTreasury) public onlyOwner {
        require(daoTreasury == address(0), "L2Staking: Lisk DAO Treasury contract is already initialized");
        require(_daoTreasury != address(0), "L2Staking: Lisk DAO Treasury contract address can not be zero");
        daoTreasury = _daoTreasury;
    }

    /// @notice Adds a new creator to the list of allowed creators.
    /// @param newCreator The address of the new creator to be added.
    /// @dev Only the owner can call this function.
    function addCreator(address newCreator) public virtual onlyOwner {
        require(newCreator != address(this), "L2Staking: Staking contract can not be added as a creator");
        allowedCreators[newCreator] = true;
    }

    /// @notice Removes a creator from the list of allowed creators.
    /// @param creator The address of the creator to be removed.
    /// @dev Only the owner can call this function.
    function removeCreator(address creator) public virtual onlyOwner {
        delete allowedCreators[creator];
    }

    /// @notice Locks the given amount for the given owner for the given locking duration and creates a new locking
    ///         position and returns its ID.
    /// @param lockOwner The address of the owner for whom the amount is locked.
    /// @param amount The amount to be locked.
    /// @param lockingDuration The duration for which the amount is locked (in days).
    /// @return The ID of the newly created locking position.
    function lockAmount(address lockOwner, uint256 amount, uint256 lockingDuration) public virtual returns (uint256) {
        require(
            lockingDuration >= MIN_LOCKING_DURATION,
            "L2Staking: lockingDuration should be at least MIN_LOCKING_DURATION"
        );
        require(
            lockingDuration <= MAX_LOCKING_DURATION,
            "L2Staking: lockingDuration can not be greater than MAX_LOCKING_DURATION"
        );

        address creator = address(0);
        if (allowedCreators[msg.sender]) {
            creator = msg.sender;
        } else {
            creator = address(this);
            require(
                msg.sender == lockOwner,
                "L2Staking: owner different than message sender, can not create locking position"
            );
        }

        // We assume that the owner has already approved the Staking contract to transfer the amount and in most cases
        // increaseLockingAmount will be called from a smart contract, so msg.sender will NOT be an address from which
        // the amount will be transferred. That's why we use lockOwner as the sender for the transferFrom function.
        // slither-disable-next-line arbitrary-send-erc20
        bool success = IL2LiskToken(l2LiskTokenContract).transferFrom(lockOwner, address(this), amount);
        require(success, "L2Staking: LSK token transfer from owner to Staking contract failed");

        uint256 lockId = (IL2LockingPosition(lockingPositionContract)).createLockingPosition(
            creator, lockOwner, amount, lockingDuration
        );

        return lockId;
    }

    /// @notice Unlocks the given locking position and transfers the locked amount back to the owner.
    /// @param lockId The ID of the locking position to be unlocked.
    function unlock(uint256 lockId) public virtual {
        LockingPosition memory lock = (IL2LockingPosition(lockingPositionContract)).getLockingPosition(lockId);
        require(isLockingPositionNull(lock) == false, "L2Staking: locking position does not exist");
        require(canLockingPositionBeModified(lockId, lock), "L2Staking: only owner or creator can call this function");

        if (lock.expDate <= todayDay() && lock.pausedLockingDuration == 0) {
            // unlocking is valid
            address ownerOfLock = (IL2LockingPosition(lockingPositionContract)).ownerOf(lockId);
            bool success = IL2LiskToken(l2LiskTokenContract).transfer(ownerOfLock, lock.amount);
            require(success, "L2Staking: LSK token transfer from Staking contract to owner failed");
            (IL2LockingPosition(lockingPositionContract)).removeLockingPosition(lockId);
        } else {
            // stake did not expire
            revert("L2Staking: locking duration active, can not unlock");
        }
    }

    /// @notice Initiates a fast unlock and apply a penalty to the locked amount. Sends the penalty amount to the Lisk
    ///         DAO Treasury or the creator of the locking position.
    /// @param lockId The ID of the locking position to be unlocked.
    function initiateFastUnlock(uint256 lockId) public virtual {
        LockingPosition memory lock = (IL2LockingPosition(lockingPositionContract)).getLockingPosition(lockId);
        require(isLockingPositionNull(lock) == false, "L2Staking: locking position does not exist");
        require(canLockingPositionBeModified(lockId, lock), "L2Staking: only owner or creator can call this function");
        require(remainingLockingDuration(lock) > FAST_UNLOCK_DURATION, "L2Staking: less than 3 days until unlock");

        // calculate penalty
        uint256 penalty = calculatePenalty(lock.amount, lock.expDate);

        uint256 amount = lock.amount - penalty;
        uint256 expDate = todayDay() + FAST_UNLOCK_DURATION;

        // update locking position
        (IL2LockingPosition(lockingPositionContract)).modifyLockingPosition(lockId, amount, expDate, 0);

        if (lock.creator == address(this)) {
            // send penalty amount to the Lisk DAO Treasury contract
            bool success = IL2LiskToken(l2LiskTokenContract).transfer(daoTreasury, penalty);
            require(success, "L2Staking: LSK token transfer from Staking contract to DAO failed");
        } else {
            // send penalty amount to the creator
            bool success = IL2LiskToken(l2LiskTokenContract).transfer(lock.creator, penalty);
            require(success, "L2Staking: LSK token transfer from Staking contract to creator failed");
        }
    }

    /// @notice Increases the amount of the given locking position.
    /// @param lockId The ID of the locking position to be increased.
    /// @param amountIncrease The amount by which the locking position is increased.
    function increaseLockingAmount(uint256 lockId, uint256 amountIncrease) public virtual {
        LockingPosition memory lock = (IL2LockingPosition(lockingPositionContract)).getLockingPosition(lockId);
        require(isLockingPositionNull(lock) == false, "L2Staking: locking position does not exist");
        require(canLockingPositionBeModified(lockId, lock), "L2Staking: only owner or creator can call this function");
        require(amountIncrease > 0, "L2Staking: increased amount should be greater than zero");
        require(
            lock.pausedLockingDuration > 0 || lock.expDate > todayDay(),
            "L2Staking: can not increase amount for expired locking position"
        );

        address ownerOfLock = (IL2LockingPosition(lockingPositionContract)).ownerOf(lockId);
        // We assume that the owner has already approved the Staking contract to transfer the amount and in most cases
        // increaseLockingAmount will be called from a smart contract, so msg.sender will NOT be an address from which
        // the amount will be transferred. That's why we use ownerOfLock as the sender for the transferFrom function.
        // slither-disable-next-line arbitrary-send-erc20
        bool success = IL2LiskToken(l2LiskTokenContract).transferFrom(ownerOfLock, address(this), amountIncrease);
        require(success, "L2Staking: LSK token transfer from owner to Staking contract failed");

        // update locking position
        (IL2LockingPosition(lockingPositionContract)).modifyLockingPosition(
            lockId, lock.amount + amountIncrease, lock.expDate, lock.pausedLockingDuration
        );
    }

    /// @notice Extends the duration of the given locking position.
    /// @param lockId The ID of the locking position to be extended.
    /// @param extendDays The number of days by which the locking position is extended.
    function extendLockingDuration(uint256 lockId, uint256 extendDays) public virtual {
        LockingPosition memory lock = (IL2LockingPosition(lockingPositionContract)).getLockingPosition(lockId);
        require(isLockingPositionNull(lock) == false, "L2Staking: locking position does not exist");
        require(canLockingPositionBeModified(lockId, lock), "L2Staking: only owner or creator can call this function");
        require(extendDays > 0, "L2Staking: extendDays should be greater than zero");
        require(
            remainingLockingDuration(lock) + extendDays <= MAX_LOCKING_DURATION,
            "L2Staking: locking duration can not be extended to more than MAX_LOCKING_DURATION"
        );

        if (lock.pausedLockingDuration > 0) {
            // remaining duration is paused
            lock.pausedLockingDuration += extendDays;
        } else {
            // remaining duration not paused, if expired, assume expDate is today
            lock.expDate = Math.max(lock.expDate, todayDay()) + extendDays;
        }

        // update locking position
        (IL2LockingPosition(lockingPositionContract)).modifyLockingPosition(
            lockId, lock.amount, lock.expDate, lock.pausedLockingDuration
        );
    }

    /// @notice Pauses the countdown of the remaining locking duration of the given locking position.
    /// @param lockId The ID of the locking position for which the remaining locking duration is paused.
    function pauseRemainingLockingDuration(uint256 lockId) public virtual {
        LockingPosition memory lock = (IL2LockingPosition(lockingPositionContract)).getLockingPosition(lockId);
        require(isLockingPositionNull(lock) == false, "L2Staking: locking position does not exist");
        require(canLockingPositionBeModified(lockId, lock), "L2Staking: only owner or creator can call this function");
        require(lock.pausedLockingDuration == 0, "L2Staking: remaining duration is already paused");

        uint256 today = todayDay();
        require(lock.expDate > today, "L2Staking: locking period has ended");

        // update locking position
        lock.pausedLockingDuration = lock.expDate - today;
        (IL2LockingPosition(lockingPositionContract)).modifyLockingPosition(
            lockId, lock.amount, lock.expDate, lock.pausedLockingDuration
        );
    }

    /// @notice Resumes the remaining locking duration of the given locking position.
    /// @param lockId The ID of the locking position for which the remaining locking duration is resumed.
    function resumeCountdown(uint256 lockId) public virtual {
        LockingPosition memory lock = (IL2LockingPosition(lockingPositionContract)).getLockingPosition(lockId);
        require(isLockingPositionNull(lock) == false, "L2Staking: locking position does not exist");
        require(canLockingPositionBeModified(lockId, lock), "L2Staking: only owner or creator can call this function");
        require(lock.pausedLockingDuration > 0, "L2Staking: countdown is not paused");

        // update locking position
        lock.expDate = todayDay() + lock.pausedLockingDuration;
        lock.pausedLockingDuration = 0;
        (IL2LockingPosition(lockingPositionContract)).modifyLockingPosition(
            lockId, lock.amount, lock.expDate, lock.pausedLockingDuration
        );
    }
}
