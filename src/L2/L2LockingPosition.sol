// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC721EnumerableUpgradeable } from
    "@openzeppelin-upgradeable/contracts/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

/// @title LockingPosition
/// @notice Struct for locking position.
struct LockingPosition {
    uint256 amount;
    uint256 expDate;
    uint256 pausedLockingDuration;
}
// uint256 lastClaimDate;

contract L2LockingPosition is Initializable, OwnableUpgradeable, UUPSUpgradeable, ERC721EnumerableUpgradeable {
    uint256 private newTokenId = 1;

    mapping(uint256 => LockingPosition) private lockingPositions;

    address public stakingContract;

    modifier onlyStaking() {
        require(msg.sender == stakingContract, "L2LockingPosition: only Staking contract can call this function");
        _;
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ERC721_init("Lisk Locking Position", "LLP");
    }

    function _authorizeUpgrade(address) internal override onlyOwner { }

    function createLockingPosition(
        address account,
        uint256 _amount,
        uint256 _expDate,
        uint256 _pausedLockingDuration
    )
        public
        onlyStaking
    {
        _mint(account, newTokenId);
        newTokenId++;

        lockingPositions[newTokenId] =
            LockingPosition({ amount: _amount, expDate: _expDate, pausedLockingDuration: _pausedLockingDuration });
        //lastClaimDate: 0
    }

    function getLockingPosition(uint256 tokenId) public view returns (LockingPosition memory) {
        return lockingPositions[tokenId];
    }

    function getAllLockingPositionsByOwner(address owner) public view returns (LockingPosition[] memory) {
        uint256 tokenCount = balanceOf(owner);
        LockingPosition[] memory result = new LockingPosition[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            result[i] = lockingPositions[tokenOfOwnerByIndex(owner, i)];
        }
        return result;
    }
}
