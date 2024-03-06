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
    uint256 private newPositionId;

    mapping(uint256 => LockingPosition) public lockingPositions;

    address public stakingContract;

    address public powerVotingContract;

    modifier onlyStaking() {
        require(msg.sender == stakingContract, "L2LockingPosition: only Staking contract can call this function");
        _;
    }

    function initialize(address _stakingContract, address _powerVotingContract) public initializer {
        require(_stakingContract != address(0), "L2LockingPosition: Staking contract address is required");
        require(_powerVotingContract != address(0), "L2LockingPosition: Power Voting contract address is required");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ERC721_init("Lisk Locking Position", "LLP");
        newPositionId = 1;
        stakingContract = _stakingContract;
        powerVotingContract = _powerVotingContract;
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner { }

    function isLockingPositionNull(LockingPosition memory position) internal view virtual returns (bool) {
        return position.creator == address(0) && position.amount == 0 && position.expDate == 0
            && position.pausedLockingDuration == 0;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    )
        public
        virtual
        override(ERC721Upgradeable, IERC721)
    {
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

        // remove voting power for an old owner
        IL2VotingPower(powerVotingContract).adjustVotingPower(
            from, lockingPositions[tokenId], LockingPosition(address(0), 0, 0, 0)
        );

        // add voting power to a new owner
        IL2VotingPower(powerVotingContract).adjustVotingPower(
            to, LockingPosition(address(0), 0, 0, 0), lockingPositions[tokenId]
        );
    }

    function createLockingPosition(
        address creator,
        address account,
        uint256 amount,
        uint256 expDate,
        uint256 pausedLockingDuration
    )
        public
        virtual
        onlyStaking
        returns (uint256)
    {
        require(account != address(0), "L2LockingPosition: account address is required");
        require(amount > 0, "L2LockingPosition: amount should be greater than 0");

        _mint(account, newPositionId);

        lockingPositions[newPositionId] = LockingPosition({
            creator: creator,
            amount: amount,
            expDate: expDate,
            pausedLockingDuration: pausedLockingDuration
        });

        IL2VotingPower(powerVotingContract).adjustVotingPower(
            account, LockingPosition(address(0), 0, 0, 0), lockingPositions[newPositionId]
        );

        newPositionId++;
        return newPositionId - 1;
    }

    function updateLockingPosition(
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

        IL2VotingPower(powerVotingContract).adjustVotingPower(
            ownerOf(positionId), oldPosition, lockingPositions[positionId]
        );
    }

    function removeLockingPosition(uint256 positionId) public virtual onlyStaking {
        require(
            !isLockingPositionNull(lockingPositions[positionId]), "L2LockingPosition: locking position does not exist"
        );

        IL2VotingPower(powerVotingContract).adjustVotingPower(
            ownerOf(positionId), lockingPositions[positionId], LockingPosition(address(0), 0, 0, 0)
        );

        _burn(positionId);

        delete lockingPositions[positionId];
    }

    function getLockingPosition(uint256 positionId) public view virtual returns (LockingPosition memory) {
        return lockingPositions[positionId];
    }

    function getAllLockingPositionsByOwner(address owner) public view virtual returns (LockingPosition[] memory) {
        uint256 tokenCount = balanceOf(owner);
        LockingPosition[] memory result = new LockingPosition[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            result[i] = lockingPositions[tokenOfOwnerByIndex(owner, i)];
        }
        return result;
    }
}
