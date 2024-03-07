// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
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
contract L2Staking is Initializable, OwnableUpgradeable, UUPSUpgradeable, ISemver {
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

    /// @notice Address of the Locking position contract.
    address public lockingPositionContract;

    /// @notice Address of the DAO contract.
    address public daoContract;

    /// @notice Semantic version of the contract.
    string public version;

    /// @notice Event emitted when a user tries to unlock a staking position before the locking period ends.
    event LockingPeriodNotEnded();

    /// @notice Disabling initializers on implementation contract to prevent misuse.
    constructor() {
        _disableInitializers();
    }

    /// @notice Setting global params.
    /// @param _l2LiskTokenContract The address of the L2LiskToken contract.
    /// @param _lockingPositionContract The address of the L2LockingPosition contract.
    /// @param _daoContract The address of the DAO contract.
    function initialize(
        address _l2LiskTokenContract,
        address _lockingPositionContract,
        address _daoContract
    )
        public
        initializer
    {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        l2LiskTokenContract = _l2LiskTokenContract;
        lockingPositionContract = _lockingPositionContract;
        daoContract = _daoContract;
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
        return position.creator == address(0) && position.amount == 0 && position.expDate == 0
            && position.pausedLockingDuration == 0;
    }

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

    function calculatePenalty(uint256 amount, uint256 expDate) internal view virtual returns (uint256) {
        uint256 penaltyFraction = (expDate - todayDay()) / (MAX_LOCKING_DURATION * PENALTY_DENOMINATOR);
        return amount * penaltyFraction;
    }

    function addCreator(address newCreator) public virtual onlyOwner {
        allowedCreators[newCreator] = true;
    }

    function removeCreator(address creator) public virtual onlyOwner {
        allowedCreators[creator] = false;
    }

    function lockAmount(address owner, uint256 amount, uint256 lockingDuration) public virtual returns (uint256) {
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
        }

        bool success = IL2LiskToken(l2LiskTokenContract).transferFrom(owner, address(this), amount);
        require(success, "L2Staking: LSK token transfer from owner to Staking contract failed");

        uint256 lockId =
            (IL2LockingPosition(lockingPositionContract)).createLockingPosition(creator, owner, amount, lockingDuration);

        return lockId;
    }

    function unlock(uint256 lockId) public virtual {
        LockingPosition memory lock = (IL2LockingPosition(lockingPositionContract)).getLockingPosition(lockId);
        require(isLockingPositionNull(lock) == false, "L2Staking: locking position does not exist");
        require(canLockingPositionBeModified(lockId, lock), "L2Staking: only owner or creator can call this function");

        if (lock.expDate <= todayDay() && lock.pausedLockingDuration == 0) {
            (IL2LockingPosition(lockingPositionContract)).removeLockingPosition(lockId);
            address ownerOfLock = (IL2LockingPosition(lockingPositionContract)).ownerOf(lockId);
            bool success = IL2LiskToken(l2LiskTokenContract).transfer(ownerOfLock, lock.amount);
            require(success, "L2Staking: LSK token transfer from Staking contract to owner failed");
        } else {
            emit LockingPeriodNotEnded();
        }
    }

    function fastUnlock(uint256 lockId) public virtual {
        LockingPosition memory lock = (IL2LockingPosition(lockingPositionContract)).getLockingPosition(lockId);
        require(isLockingPositionNull(lock) == false, "L2Staking: locking position does not exist");
        require(canLockingPositionBeModified(lockId, lock), "L2Staking: only owner or creator can call this function");

        uint256 today = todayDay();
        require(lock.expDate - today > FAST_UNLOCK_DURATION, "L2Staking: less than 3 days until unlock");

        // calculate penalty
        uint256 penalty = calculatePenalty(lock.amount, lock.expDate);

        uint256 amount = lock.amount - penalty;
        uint256 expDate = today + FAST_UNLOCK_DURATION;

        // update locking position
        (IL2LockingPosition(lockingPositionContract)).modifyLockingPosition(lockId, amount, expDate, 0);

        if (lock.creator == address(this)) {
            // send penalty amount to the DAO contract
            bool success = IL2LiskToken(l2LiskTokenContract).transfer(daoContract, penalty);
            require(success, "L2Staking: LSK token transfer from Staking contract to DAO failed");
        } else {
            // send penalty amount to the creator
            bool success = IL2LiskToken(l2LiskTokenContract).transfer(lock.creator, penalty);
            require(success, "L2Staking: LSK token transfer from Staking contract to creator failed");
        }
    }

    function increaseLockingAmount(uint256 lockId, uint256 amountIncrease) public virtual {
        LockingPosition memory lock = (IL2LockingPosition(lockingPositionContract)).getLockingPosition(lockId);
        require(isLockingPositionNull(lock) == false, "L2Staking: locking position does not exist");
        require(canLockingPositionBeModified(lockId, lock), "L2Staking: only owner or creator can call this function");
        require(amountIncrease > 0, "L2Staking: increased amount should be greater than zero");
        require(
            lock.pausedLockingDuration > 0 || lock.expDate > todayDay(),
            "L2Staking: can not increase amount for expired locking position"
        );

        // update locking position
        (IL2LockingPosition(lockingPositionContract)).modifyLockingPosition(
            lockId, lock.amount + amountIncrease, lock.expDate, lock.pausedLockingDuration
        );
    }

    function extendLockingDuration(uint256 lockId, uint256 extendDays) public virtual {
        LockingPosition memory lock = (IL2LockingPosition(lockingPositionContract)).getLockingPosition(lockId);
        require(isLockingPositionNull(lock) == false, "L2Staking: locking position does not exist");
        require(canLockingPositionBeModified(lockId, lock), "L2Staking: only owner or creator can call this function");
        require(extendDays > 0, "L2Staking: extendDays should be greater than zero");

        if (lock.pausedLockingDuration > 0) {
            // remaining duration is paused
            lock.pausedLockingDuration += extendDays;
        } else {
            // remaining duration not paused, if expired, assume expDate is today
            lock.expDate += Math.max(lock.expDate, todayDay()) + extendDays;
        }

        // update locking position
        (IL2LockingPosition(lockingPositionContract)).modifyLockingPosition(
            lockId, lock.amount, lock.expDate, lock.pausedLockingDuration
        );
    }

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

    function resumeCountdown(uint256 lockId) public virtual {
        LockingPosition memory lock = (IL2LockingPosition(lockingPositionContract)).getLockingPosition(lockId);
        require(isLockingPositionNull(lock) == false, "L2Staking: locking position does not exist");
        require(canLockingPositionBeModified(lockId, lock), "L2Staking: only owner or creator can call this function");
        require(lock.pausedLockingDuration > 0, "L2Staking: remaining duration is not paused");

        // update locking position
        lock.expDate = todayDay() + lock.pausedLockingDuration;
        lock.pausedLockingDuration = 0;
        (IL2LockingPosition(lockingPositionContract)).modifyLockingPosition(lockId, lock.amount, lock.expDate, 0);
    }
}
