// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC721Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";
import { ERC721EnumerableUpgradeable } from
    "@openzeppelin-upgradeable/contracts/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

/// @title LockingPosition
/// @notice Struct for locking position.
struct LockingPosition {
    uint256 amount;
    uint256 expDate;
    uint256 pausedLockingDuration;
}

contract L2LockingPosition is Initializable, OwnableUpgradeable, UUPSUpgradeable, ERC721EnumerableUpgradeable {
    uint256 private newPositionId;

    mapping(uint256 => LockingPosition) private lockingPositions;

    address public stakingContract;

    modifier onlyStaking() {
        require(msg.sender == stakingContract, "L2LockingPosition: only Staking contract can call this function");
        _;
    }

    function initialize(address _stakingContract) public initializer {
        require(_stakingContract != address(0), "L2LockingPosition: staking contract address is required");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ERC721_init("Lisk Locking Position", "LLP");
        newPositionId = 1;
        stakingContract = _stakingContract;
    }

    function _authorizeUpgrade(address) internal virtual override onlyOwner { }

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
        // TODO: remove voting power for an old owner

        // add voting power for a new owner
        // TODO: add voting power for a new owner
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
        // TODO: remove voting power for an old owner

        // add voting power for a new owner
        // TODO: add voting power for a new owner
    }

    function createLockingPosition(
        address account,
        uint256 _amount,
        uint256 _expDate,
        uint256 _pausedLockingDuration
    )
        public
        virtual
        onlyStaking
    {
        _mint(account, newPositionId);

        lockingPositions[newPositionId] =
            LockingPosition({ amount: _amount, expDate: _expDate, pausedLockingDuration: _pausedLockingDuration });

        newPositionId++;
    }

    function removeLockingPosition(uint256 positionId) public virtual onlyStaking {
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
