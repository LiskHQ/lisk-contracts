// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

interface IL2Staking {
    error AddressEmptyCode(address target);
    error ERC1967InvalidImplementation(address implementation);
    error ERC1967NonPayable();
    error FailedInnerCall();
    error InvalidInitialization();
    error NotInitializing();
    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);
    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    event AllowedCreatorAdded(address indexed creator);
    event AllowedCreatorRemoved(address indexed creator);
    event DaoTreasuryAddressChanged(address indexed oldAddress, address indexed newAddress);
    event EmergencyExitEnabledChanged(bool indexed oldEmergencyExitEnabled, bool indexed newEmergencyExitEnabled);
    event Initialized(uint64 version);
    event LiskTokenContractAddressChanged(address indexed oldAddress, address indexed newAddress);
    event LockingPositionContractAddressChanged(address indexed oldAddress, address indexed newAddress);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Upgraded(address indexed implementation);

    function FAST_UNLOCK_DURATION() external view returns (uint32);
    function MAX_LOCKING_DURATION() external view returns (uint32);
    function MIN_LOCKING_AMOUNT() external view returns (uint256);
    function MIN_LOCKING_DURATION() external view returns (uint32);
    function PENALTY_DENOMINATOR() external view returns (uint32);
    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);
    function acceptOwnership() external;
    function addCreator(address newCreator) external;
    function allowedCreators(address) external view returns (bool);
    function daoTreasury() external view returns (address);
    function emergencyExitEnabled() external view returns (bool);
    function extendLockingDuration(uint256 lockId, uint256 extendDays) external;
    function increaseLockingAmount(uint256 lockId, uint256 amountIncrease) external;
    function initialize(address _l2LiskTokenContract) external;
    function initializeDaoTreasury(address _daoTreasury) external;
    function initializeLockingPosition(address _lockingPositionContract) external;
    function initiateFastUnlock(uint256 lockId) external returns (uint256);
    function l2LiskTokenContract() external view returns (address);
    function lockAmount(address lockOwner, uint256 amount, uint256 lockingDuration) external returns (uint256);
    function lockingPositionContract() external view returns (address);
    function owner() external view returns (address);
    function pauseRemainingLockingDuration(uint256 lockId) external;
    function pendingOwner() external view returns (address);
    function proxiableUUID() external view returns (bytes32);
    function removeCreator(address creator) external;
    function renounceOwnership() external;
    function resumeCountdown(uint256 lockId) external;
    function setEmergencyExitEnabled(bool _emergencyExitEnabled) external;
    function transferOwnership(address newOwner) external;
    function unlock(uint256 lockId) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function version() external view returns (string memory);
}
