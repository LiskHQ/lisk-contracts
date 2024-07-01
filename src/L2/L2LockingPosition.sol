// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC721Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import { ERC721EnumerableUpgradeable } from
    "@openzeppelin-upgradeable/contracts/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import { IL2LockingPosition } from "../interfaces/L2/IL2LockingPosition.sol";
import { IL2VotingPower } from "../interfaces/L2/IL2VotingPower.sol";

/// @title L2LockingPosition
/// @notice Contract for locking positions. It allows creating, modifying, and removing locking positions. It also
///         allows querying locking positions for a given owner. It is also responsible for minting and burning NFT
///         tokens for each locking position. It also interacts with the Voting Power contract to adjust the voting
///         power of the owner of the locking position.
contract L2LockingPosition is Initializable, Ownable2StepUpgradeable, UUPSUpgradeable, ERC721EnumerableUpgradeable {
    /// @notice Next id for the locking position to be created.
    uint256 private nextId;

    /// @notice Mapping of locking position ID to LockingPosition entity.
    // slither-disable-next-line uninitialized-state
    mapping(uint256 => IL2LockingPosition.LockingPosition) public lockingPositions;

    /// @notice Address of the Staking contract.
    address public stakingContract;

    /// @notice Address of the Voting Power contract.
    address public votingPowerContract;

    /// @notice Event emitted when Staking contract address is changed.
    event StakingContractAddressChanged(address indexed oldAddress, address indexed newAddress);

    /// @notice Event emitted when Voting Power contract address is changed.
    event VotingPowerContractAddressChanged(address indexed oldAddress, address indexed newAddress);

    /// @notice Event emitted when a new locking position is created.
    event LockingPositionCreated(
        uint256 indexed positionId,
        address indexed creator,
        address indexed lockOwner,
        uint256 amount,
        uint256 lockingDuration
    );

    /// @notice Event emitted when a locking position is modified.
    event LockingPositionModified(
        uint256 indexed positionId, uint256 amount, uint256 expDate, uint256 pausedLockingDuration
    );

    /// @notice Event emitted when a locking position is removed.
    event LockingPositionRemoved(uint256 indexed positionId);

    /// @notice Modifier to allow only Staking contract to call the function.
    modifier onlyStaking() {
        require(msg.sender == stakingContract, "L2LockingPosition: only Staking contract can call this function");
        _;
    }

    /// @notice Disabling initializers on implementation contract to prevent misuse.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initialize the contract.
    /// @param _stakingContract Address of the Staking contract.
    function initialize(address _stakingContract) public initializer {
        require(_stakingContract != address(0), "L2LockingPosition: Staking contract address cannot be zero");
        __Ownable2Step_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ERC721_init("Lisk Locking Position", "LLP");
        nextId = 1;
        stakingContract = _stakingContract;
        emit StakingContractAddressChanged(address(0), stakingContract);
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
    function isLockingPositionNull(IL2LockingPosition.LockingPosition memory position)
        internal
        view
        virtual
        returns (bool)
    {
        // We are using == to compare with 0 because we want to check if the fields are initialized to 0 or address(0).
        // slither-disable-next-line incorrect-equality
        return position.creator == address(0) && position.amount == 0 && position.expDate == 0
            && position.pausedLockingDuration == 0;
    }

    /// @notice Initializes the Voting Power contract address.
    /// @param _votingPowerContract Address of the Voting Power contract.
    function initializeVotingPower(address _votingPowerContract) external virtual onlyOwner {
        require(votingPowerContract == address(0), "L2LockingPosition: Voting Power contract is already initialized");
        require(_votingPowerContract != address(0), "L2LockingPosition: Voting Power contract address can not be zero");
        votingPowerContract = _votingPowerContract;
        emit VotingPowerContractAddressChanged(address(0), votingPowerContract);
    }

    /// @notice Change owner of the locking position and adjust voting power.
    /// @param from Address of the current owner of the locking position.
    /// @param to Address of the new owner of the locking position.
    /// @param tokenId ID of the locking position.
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    )
        public
        virtual
        override(ERC721Upgradeable, IERC721)
    {
        require(!isLockingPositionNull(lockingPositions[tokenId]), "L2LockingPosition: locking position does not exist");

        super.transferFrom(from, to, tokenId);

        // remove voting power for an old owner
        IL2VotingPower(votingPowerContract).adjustVotingPower(
            from, lockingPositions[tokenId], IL2LockingPosition.LockingPosition(address(0), 0, 0, 0)
        );

        // add voting power to a new owner
        IL2VotingPower(votingPowerContract).adjustVotingPower(
            to, IL2LockingPosition.LockingPosition(address(0), 0, 0, 0), lockingPositions[tokenId]
        );
    }

    /// @notice Creates a new locking position.
    /// @param creator Address of the creator of the locking position.
    /// @param lockOwner Address of the owner of the locking position.
    /// @param amount Amount to be locked.
    /// @param lockingDuration Duration for which the amount should be locked (in days).
    /// @return ID of the created locking position.
    function createLockingPosition(
        address creator,
        address lockOwner,
        uint256 amount,
        uint256 lockingDuration
    )
        external
        virtual
        onlyStaking
        returns (uint256)
    {
        require(creator != address(0), "L2LockingPosition: creator address is required");
        require(lockOwner != address(0), "L2LockingPosition: lockOwner address is required");
        require(amount > 0, "L2LockingPosition: amount should be greater than 0");
        require(lockingDuration > 0, "L2LockingPosition: locking duration should be greater than 0");

        // mint a new NFT token
        _mint(lockOwner, nextId);

        // create entry for this locking position
        lockingPositions[nextId] = IL2LockingPosition.LockingPosition({
            creator: creator,
            amount: amount,
            expDate: todayDay() + lockingDuration,
            pausedLockingDuration: 0
        });

        // call Voting Power contract to set voting power
        // reentrancy won't be an issue here because the Voting Power contract is trusted and managed by the team
        // slither-disable-next-line reentrancy-no-eth
        IL2VotingPower(votingPowerContract).adjustVotingPower(
            lockOwner, IL2LockingPosition.LockingPosition(address(0), 0, 0, 0), lockingPositions[nextId]
        );

        // emit event
        emit LockingPositionCreated(nextId, creator, lockOwner, amount, lockingDuration);

        // update nextID and return the created locking position ID
        nextId++;
        return nextId - 1;
    }

    /// @notice Modifies the locking position.
    /// @param positionId ID of the locking position to be modified.
    /// @param amount New amount for the locking position.
    /// @param expDate New expiration date for the locking position.
    /// @param pausedLockingDuration New paused locking duration for the locking position.
    function modifyLockingPosition(
        uint256 positionId,
        uint256 amount,
        uint256 expDate,
        uint256 pausedLockingDuration
    )
        external
        virtual
        onlyStaking
    {
        require(amount > 0, "L2LockingPosition: amount should be greater than 0");
        require(
            expDate >= todayDay() || pausedLockingDuration > 0,
            "L2LockingPosition: expDate should be greater than or equal to today or pausedLockingDuration > 0"
        );
        require(
            !isLockingPositionNull(lockingPositions[positionId]), "L2LockingPosition: locking position does not exist"
        );
        require(
            expDate >= todayDay() || lockingPositions[positionId].expDate == expDate,
            "L2LockingPosition: can not modify past expiration dates"
        );

        IL2LockingPosition.LockingPosition memory oldPosition = lockingPositions[positionId];
        lockingPositions[positionId] = IL2LockingPosition.LockingPosition({
            creator: oldPosition.creator,
            amount: amount,
            expDate: expDate,
            pausedLockingDuration: pausedLockingDuration
        });

        // call Voting Power contract to update voting power
        IL2VotingPower(votingPowerContract).adjustVotingPower(
            ownerOf(positionId), oldPosition, lockingPositions[positionId]
        );

        // emit event
        emit LockingPositionModified(positionId, amount, expDate, pausedLockingDuration);
    }

    /// @notice Removes the locking position.
    /// @param positionId ID of the locking position to be removed.
    function removeLockingPosition(uint256 positionId) external virtual onlyStaking {
        require(
            !isLockingPositionNull(lockingPositions[positionId]), "L2LockingPosition: locking position does not exist"
        );

        // inform Voting Power contract
        // reentrancy won't be an issue here because the Voting Power contract is trusted and managed by the team
        // slither-disable-next-line reentrancy-no-eth
        IL2VotingPower(votingPowerContract).adjustVotingPower(
            ownerOf(positionId), lockingPositions[positionId], IL2LockingPosition.LockingPosition(address(0), 0, 0, 0)
        );

        // burn the NFT token
        // reentrancy won't be an issue here because the ERC721Upgradable contract is trusted
        // slither-disable-next-line reentrancy-events
        _burn(positionId);

        // remove the locking position
        delete lockingPositions[positionId];

        // emit event
        emit LockingPositionRemoved(positionId);
    }

    /// @notice Returns the locking position for the given position ID.
    /// @param positionId ID of the locking position.
    /// @return Locking position for the given position ID.
    function getLockingPosition(uint256 positionId)
        public
        view
        virtual
        returns (IL2LockingPosition.LockingPosition memory)
    {
        return lockingPositions[positionId];
    }

    /// @notice Returns all locking positions for the given owner.
    /// @param lockOwner Owner address.
    /// @return All locking positions for the given owner.
    function getAllLockingPositionsByOwner(address lockOwner)
        public
        view
        virtual
        returns (IL2LockingPosition.LockingPosition[] memory)
    {
        uint256 tokenCount = balanceOf(lockOwner);
        IL2LockingPosition.LockingPosition[] memory result = new IL2LockingPosition.LockingPosition[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            result[i] = lockingPositions[tokenOfOwnerByIndex(lockOwner, i)];
        }
        return result;
    }
}
