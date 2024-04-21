// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

interface IL2Reward {
    struct ExtendedDuration {
        uint256 lockID;
        uint256 durationExtension;
    }

    struct IncreasedAmount {
        uint256 lockID;
        uint256 amountIncrease;
    }

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

    event Initialized(uint64 version);
    event LiskTokenContractAddressChanged(address indexed oldAddress, address indexed newAddress);
    event LockingPositionContractAddressChanged(address indexed oldAddress, address indexed newAddress);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event RewardsAdded(uint256 indexed amount, uint256 indexed duration, uint256 indexed delay);
    event RewardsClaimed(uint256 lockID, uint256 amount);
    event StakingContractAddressChanged(address indexed oldAddress, address indexed newAddress);
    event Upgraded(address indexed implementation);

    function OFFSET() external view returns (uint256);
    function REWARD_DURATION() external view returns (uint16);
    function REWARD_DURATION_DELAY() external view returns (uint16);
    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);
    function acceptOwnership() external;
    function addUnusedRewards(uint256 amount, uint16 duration, uint16 delay) external;
    function calculateRewards(uint256 lockID) external view returns (uint256);
    function claimRewards(uint256[] memory lockIDs) external;
    function createPosition(uint256 amount, uint256 duration) external returns (uint256);
    function dailyRewards(uint256) external view returns (uint256);
    function dailyUnlockedAmounts(uint256) external view returns (uint256);
    function deletePositions(uint256[] memory lockIDs) external;
    function extendDuration(ExtendedDuration[] memory locks) external;
    function fundStakingRewards(uint256 amount, uint16 duration, uint16 delay) external;
    function increaseLockingAmount(IncreasedAmount[] memory locks) external;
    function initialize(address _l2LiskTokenContract) external;
    function initializeLockingPosition(address _lockingPositionContract) external;
    function initializeStaking(address _stakingContract) external;
    function initiateFastUnlock(uint256[] memory lockIDs) external;
    function l2TokenContract() external view returns (address);
    function lastClaimDate(uint256) external view returns (uint256);
    function lastTrsDate() external view returns (uint256);
    function lockingPositionContract() external view returns (address);
    function owner() external view returns (address);
    function pauseUnlocking(uint256[] memory lockIDs) external;
    function pendingOwner() external view returns (address);
    function pendingUnlockAmount() external view returns (uint256);
    function proxiableUUID() external view returns (bytes32);
    function renounceOwnership() external;
    function resumeUnlockingCountdown(uint256[] memory lockIDs) external;
    function rewardsSurplus() external view returns (uint256);
    function stakingContract() external view returns (address);
    function todayDay() external view returns (uint256);
    function totalAmountLocked() external view returns (uint256);
    function totalWeight() external view returns (uint256);
    function totalWeights(uint256) external view returns (uint256);
    function transferOwnership(address newOwner) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function version() external view returns (string memory);
}
