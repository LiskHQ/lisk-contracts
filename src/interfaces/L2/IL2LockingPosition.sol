// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

interface IL2LockingPosition {
    /// @title LockingPosition
    /// @notice Struct for locking position.
    struct LockingPosition {
        /// @notice This can be, for instance, the staking contract or the rewards contract. The staking contract - the
        ///         only contract allowed to modify a position - uses this property to determine who should be allowed
        ///         to trigger a modification.
        address creator;
        /// @notice Amount to be locked.
        uint256 amount;
        /// @notice The expiration date, i.e., the day when locked amount would be claimable from the user.
        uint256 expDate;
        /// @notice The remaining locking duration (in days). It is used only when the unlocking countdown is paused,
        ///         otherwise it is set to 0.
        uint256 pausedLockingDuration;
    }

    error AddressEmptyCode(address target);
    error ERC1967InvalidImplementation(address implementation);
    error ERC1967NonPayable();
    error ERC721EnumerableForbiddenBatchMint();
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);
    error ERC721InsufficientApproval(address operator, uint256 tokenId);
    error ERC721InvalidApprover(address approver);
    error ERC721InvalidOperator(address operator);
    error ERC721InvalidOwner(address owner);
    error ERC721InvalidReceiver(address receiver);
    error ERC721InvalidSender(address sender);
    error ERC721NonexistentToken(uint256 tokenId);
    error ERC721OutOfBoundsIndex(address owner, uint256 index);
    error FailedInnerCall();
    error InvalidInitialization();
    error NotInitializing();
    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);
    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    event Initialized(uint64 version);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event StakingContractAddressChanged(address indexed oldAddress, address indexed newAddress);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Upgraded(address indexed implementation);
    event VotingPowerContractAddressChanged(address indexed oldAddress, address indexed newAddress);

    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);
    function acceptOwnership() external;
    function approve(address to, uint256 tokenId) external;
    function balanceOf(address owner) external view returns (uint256);
    function createLockingPosition(
        address creator,
        address lockOwner,
        uint256 amount,
        uint256 lockingDuration
    )
        external
        returns (uint256);
    function getAllLockingPositionsByOwner(address lockOwner) external view returns (LockingPosition[] memory);
    function getApproved(uint256 tokenId) external view returns (address);
    function getLockingPosition(uint256 positionId) external view returns (LockingPosition memory);
    function initialize(address _stakingContract) external;
    function initializeVotingPower(address _votingPowerContract) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function lockingPositions(uint256)
        external
        view
        returns (address creator, uint256 amount, uint256 expDate, uint256 pausedLockingDuration);
    function modifyLockingPosition(
        uint256 positionId,
        uint256 amount,
        uint256 expDate,
        uint256 pausedLockingDuration
    )
        external;
    function name() external view returns (string memory);
    function owner() external view returns (address);
    function ownerOf(uint256 tokenId) external view returns (address);
    function pendingOwner() external view returns (address);
    function proxiableUUID() external view returns (bytes32);
    function removeLockingPosition(uint256 positionId) external;
    function renounceOwnership() external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external;
    function setApprovalForAll(address operator, bool approved) external;
    function stakingContract() external view returns (address);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function symbol() external view returns (string memory);
    function tokenByIndex(uint256 index) external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function transferOwnership(address newOwner) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function votingPowerContract() external view returns (address);
}
