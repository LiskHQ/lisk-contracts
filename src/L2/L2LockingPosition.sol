// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC721Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import { ERC721EnumerableUpgradeable } from
    "@openzeppelin-upgradeable/contracts/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

/// @title IL2VotingPower
/// @notice Interface for the L2VotingPower contract.
interface IL2VotingPower {
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
    address creator;
    uint256 amount;
    uint256 expDate;
    uint256 pausedLockingDuration;
}

contract L2LockingPosition is Initializable, OwnableUpgradeable, UUPSUpgradeable, ERC721EnumerableUpgradeable {
    /// @notice Next id for the locking position to be created.
    uint256 private nextId;

    /// @notice Mapping of locking position ID to LockingPosition entity.
    mapping(uint256 => LockingPosition) public lockingPositions;

    /// @notice Address of the Staking contract.
    address public stakingContract;

    /// @notice Address of the Power Voting contract.
    address public powerVotingContract;

    /// @notice Modifier to allow only Staking contract to call the function.
    modifier onlyStaking() {
        require(msg.sender == stakingContract, "L2LockingPosition: only Staking contract can call this function");
        _;
    }

    /// @notice Initialize the contract.
    /// @param _stakingContract Address of the Staking contract.
    /// @param _powerVotingContract Address of the Power Voting contract.
    function initialize(address _stakingContract, address _powerVotingContract) public initializer {
        require(_stakingContract != address(0), "L2LockingPosition: Staking contract address is required");
        require(_powerVotingContract != address(0), "L2LockingPosition: Power Voting contract address is required");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ERC721_init("Lisk Locking Position", "LLP");
        nextId = 1;
        stakingContract = _stakingContract;
        powerVotingContract = _powerVotingContract;
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
        IL2VotingPower(powerVotingContract).adjustVotingPower(
            from, lockingPositions[tokenId], LockingPosition(address(0), 0, 0, 0)
        );

        // add voting power to a new owner
        IL2VotingPower(powerVotingContract).adjustVotingPower(
            to, LockingPosition(address(0), 0, 0, 0), lockingPositions[tokenId]
        );
    }

    /// @notice Safetly change owner of the locking position and adjust voting power.
    /// @param from Address of the current owner of the locking position.
    /// @param to Address of the new owner of the locking position.
    /// @param tokenId ID of the locking position.
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    )
        public
        virtual
        override(ERC721Upgradeable, IERC721)
    {
        super.safeTransferFrom(from, to, tokenId, data);
        // check if locking position exists is done in transferFrom because it is called by safeTransferFrom
        // voting power is adjusted in transferFrom because it is called by safeTransferFrom
    }

    /// @notice Creates a new locking position.
    /// @param creator Address of the creator of the locking position.
    /// @param owner Address of the owner of the locking position.
    /// @param amount Amount to be locked.
    /// @param lockingDuration Duration for which the amount should be locked.
    /// @return ID of the created locking position.
    function createLockingPosition(
        address creator,
        address owner,
        uint256 amount,
        uint256 lockingDuration
    )
        public
        virtual
        onlyStaking
        returns (uint256)
    {
        require(owner != address(0), "L2LockingPosition: owner address is required");
        require(amount > 0, "L2LockingPosition: amount should be greater than 0");
        require(lockingDuration > 0, "L2LockingPosition: locking duration should be greater than 0");

        // mint a new NFT token
        _mint(owner, nextId);

        // create entry for this locking position
        lockingPositions[nextId] = LockingPosition({
            creator: creator,
            amount: amount,
            expDate: todayDay() + lockingDuration,
            pausedLockingDuration: 0
        });

        // call Voting Power contract to set voting power
        IL2VotingPower(powerVotingContract).adjustVotingPower(
            owner, LockingPosition(address(0), 0, 0, 0), lockingPositions[nextId]
        );

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
        public
        virtual
        onlyStaking
    {
        require(
            !isLockingPositionNull(lockingPositions[positionId]), "L2LockingPosition: locking position does not exist"
        );

        LockingPosition memory oldPosition = lockingPositions[positionId];
        lockingPositions[positionId] = LockingPosition({
            creator: oldPosition.creator,
            amount: amount,
            expDate: expDate,
            pausedLockingDuration: pausedLockingDuration
        });

        // call Voting Power contract to update voting power
        IL2VotingPower(powerVotingContract).adjustVotingPower(
            ownerOf(positionId), oldPosition, lockingPositions[positionId]
        );
    }

    /// @notice Removes the locking position.
    /// @param positionId ID of the locking position to be removed.
    function removeLockingPosition(uint256 positionId) public virtual onlyStaking {
        require(
            !isLockingPositionNull(lockingPositions[positionId]), "L2LockingPosition: locking position does not exist"
        );

        // inform Voting Power contract
        IL2VotingPower(powerVotingContract).adjustVotingPower(
            ownerOf(positionId), lockingPositions[positionId], LockingPosition(address(0), 0, 0, 0)
        );

        // burn the NFT token
        _burn(positionId);

        // remove the locking position
        delete lockingPositions[positionId];
    }

    /// @notice Returns the locking position for the given position ID.
    /// @param positionId ID of the locking position.
    /// @return Locking position for the given position ID.
    function getLockingPosition(uint256 positionId) public view virtual returns (LockingPosition memory) {
        return lockingPositions[positionId];
    }

    /// @notice Returns all locking positions for the given owner.
    /// @param owner Owner address.
    /// @return All locking positions for the given owner.
    function getAllLockingPositionsByOwner(address owner) public view virtual returns (LockingPosition[] memory) {
        uint256 tokenCount = balanceOf(owner);
        LockingPosition[] memory result = new LockingPosition[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            result[i] = lockingPositions[tokenOfOwnerByIndex(owner, i)];
        }
        return result;
    }
}
