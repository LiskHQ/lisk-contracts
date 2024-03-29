// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { LockingPosition } from "./L2LockingPosition.sol";

/// @title IL2LiskToken
/// @notice Interface for the L2LiskToken contract.
interface IL2LiskToken {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
}

/// @title IL2LockingPosition
/// @notice Interface for the L2LockingPosition contract.
interface IL2LockingPosition {
    function getLockingPosition(uint256 positionId) external view returns (LockingPosition memory);
    function getAllLockingPositionsByOwner(address lockOwner) external view returns (LockingPosition[] memory);
}

/// @title IL2Claim
/// @notice Interface for the L2Claim contract.
interface IL2Claim {
    function claimedTo(bytes20 liskAddress) external view returns (address);
}

/// @title IL2VotingPower
/// @notice Interface for the L2VotingPower contract.
interface IL2VotingPower {
    function delegates(address account) external view returns (address);
}

/// @title L2Airdrop
/// @notice L2Airdrop is an implementation of the Lisk v4 migration airdrop on L2. It is responsible for the airdrop
///         computation and distribution of LSK tokens to the recipient's accounts that have migrated to L2. The airdrop
///         computation is based on the following conditions:
///         1. Min ETH: The recipient must have at least MIN_ETH ETH on L2.
///         2. Delegating: The recipient must have delegated in Lisk DAO.
///         3. Staking Tier 1: The recipient must have staked at least MIN_STAKING_AMOUNT_MULTIPLIER * airdropAmount for
///                            at least MIN_STAKING_DURATION_TIER_1.
///         4. Staking Tier 2: The recipient must have staked at least MIN_STAKING_AMOUNT_MULTIPLIER * airdropAmount for
///                            at least MIN_STAKING_DURATION_TIER_2.
///         The airdrop amount is capped at WHALE_CAP LSK tokens. The airdrop amount is distributed to the recipient's
///         L2LiskToken contract. The airdrop status for each recipient is stored in a mapping. The airdrop status
///         includes the status of each of the airdrop conditions.
contract L2Airdrop is Ownable2Step {
    /// @notice The total amount of LSK tokens to be given away in the migration airdrop.
    uint256 public constant MIGRATION_AIRDROP_AMOUNT = 3_000_000 * 10 ** 18; // 3 million LSK tokens

    /// @notice Cap on the token amount of a single Lisk v4 account to be used for the airdrop computation.
    uint256 public constant WHALE_CAP = 500_000 * 10 ** 18; // 500 thousand LSK tokens

    /// @notice Minimal amount of LSK required to participate in the migration airdrop.
    uint256 public constant CUTOFF_AMOUNT = 50 * 10 ** 18; // 50 LSK tokens

    /// @notice The required ETH amount on Lisk L2 to satisfy min ETH requirement.
    uint256 public constant MIN_ETH = 10 ** 16; // 0.01 ETH

    /// @notice Minimal staking duration to satisfy the staking requirement of tier 1.
    uint32 public constant MIN_STAKING_DURATION_TIER_1 = 30; // 1 month

    /// @notice Minimal staking duration to satisfy the staking requirement of tier 2.
    uint32 public constant MIN_STAKING_DURATION_TIER_2 = 90; // 3 months

    /// @notice Airdrop amount with this multiplier defines the minimum staking amount that must be staked at least for
    ///         MIN_STAKING_DURATION to satisfy the staking requirement. This multiplier should incentivize staking of
    ///         50% of the migrated whale capped amount.
    uint8 public constant MIN_STAKING_AMOUNT_MULTIPLIER = 5;

    /// @notice Merkle Root for the airdrop process.
    bytes32 public merkleRoot;

    /// @notice Mapping of the airdrop status for each Lisk v4 address. In particular, for each of the airdrop
    ///         conditions (min ETH, delegating, staking tier 1, staking tier 2).
    mapping(bytes20 => uint8) public airdropStatus;

    // Airdrop status bits
    // bit 0: min ETH
    uint8 public constant MIN_ETH_BIT = 0x01;
    // bit 1: delegating
    uint8 public constant DELEGATING_BIT = 0x02;
    // bit 2: staking tier 1
    uint8 public constant STAKING_TIER_1_BIT = 0x04;
    // bit 3: staking tier 2
    uint8 public constant STAKING_TIER_2_BIT = 0x08;
    // full airdrop claimed
    uint8 public constant FULL_AIRDROP_CLAIMED = 0x0F;

    /// @notice Address of the L2LiskToken contract.
    address public l2LiskTokenAddress;

    /// @notice Address of the L2Claim contract.
    address public l2ClaimAddress;

    /// @notice Address of the L2LockingPosition contract.
    address public l2LockingPositionAddress;

    /// @notice Address of the L2VotingPower contract.
    address public l2VotingPowerAddress;

    /// @notice The treasury address of the Lisk DAO.
    address public daoTreasuryAddress;

    /// @notice Constructs the L2Airdrop contract.
    /// @param _l2LiskTokenAddress Address of the L2LiskToken contract.
    /// @param _l2ClaimAddress Address of the L2Claim contract.
    /// @param _l2LockingPositionAddress Address of the L2LockingPosition contract.
    /// @param _l2VotingPowerAddress Address of the L2VotingPower contract.
    /// @param _daoTreasuryAddress The treasury address of the Lisk DAO.
    constructor(
        address _l2LiskTokenAddress,
        address _l2ClaimAddress,
        address _l2LockingPositionAddress,
        address _l2VotingPowerAddress,
        address _daoTreasuryAddress
    )
        Ownable(msg.sender)
    {
        require(_l2LiskTokenAddress != address(0), "L2Airdrop: L2 Lisk Token contract address can not be zero");
        require(_l2ClaimAddress != address(0), "L2Airdrop: L2 Claim contract address can not be zero");
        require(
            _l2LockingPositionAddress != address(0), "L2Airdrop: L2 Locking Position contract address can not be zero"
        );
        require(_l2VotingPowerAddress != address(0), "L2Airdrop: L2 Voting Power contract address can not be zero");
        require(_daoTreasuryAddress != address(0), "L2Airdrop: DAO treasury address can not be zero");
        l2LiskTokenAddress = _l2LiskTokenAddress;
        l2LockingPositionAddress = _l2LockingPositionAddress;
        l2ClaimAddress = _l2ClaimAddress;
        l2VotingPowerAddress = _l2VotingPowerAddress;
        daoTreasuryAddress = _daoTreasuryAddress;
    }

    /// @notice Set Merkle root for the airdrop process.
    /// @param _merkleRoot Merkle root for the airdrop process.
    /// @dev Only the owner can set the Merkle root.
    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        require(_merkleRoot != 0, "L2Airdrop: Merkle root can not be zero");
        require(merkleRoot == 0, "L2Airdrop: Merkle root already set");
        merkleRoot = _merkleRoot;
    }

    /// @notice Send the remaining LSK tokens to the Lisk DAO treasury.
    /// @dev Only the owner can send the remaining LSK tokens to the Lisk DAO treasury.
    function sendLSKToDaoTreasury() public onlyOwner {
        uint256 balance = IL2LiskToken(l2LiskTokenAddress).balanceOf(address(this));
        bool status = IL2LiskToken(l2LiskTokenAddress).transfer(daoTreasuryAddress, balance);
        require(status, "L2Airdrop: LSK token transfer to DAO failed");
    }

    /// @notice Check if the Lisk v4 address has claimed the airdrop for min ETH.
    /// @param liskAddress The Lisk v4 address to check if it has claimed the airdrop for min ETH.
    /// @return True if the Lisk v4 address has claimed the airdrop for min ETH, False otherwise.
    function claimedMinEth(bytes20 liskAddress) public view returns (bool) {
        return (airdropStatus[liskAddress] & MIN_ETH_BIT) != 0;
    }

    /// @notice Check if the Lisk v4 address has claimed the airdrop for delegating.
    /// @param liskAddress The Lisk v4 address to check if it has claimed the airdrop for delegating.
    /// @return True if the Lisk v4 address has claimed the airdrop for delegating, False otherwise.
    function claimedDelegating(bytes20 liskAddress) public view returns (bool) {
        return (airdropStatus[liskAddress] & DELEGATING_BIT) != 0;
    }

    /// @notice Check if the Lisk v4 address has claimed the airdrop for staking tier 1.
    /// @param liskAddress The Lisk v4 address to check if it has claimed the airdrop for staking tier 1.
    /// @return True if the Lisk v4 address has claimed the airdrop for staking tier 1, False otherwise.
    function claimedStakingTier1(bytes20 liskAddress) public view returns (bool) {
        return (airdropStatus[liskAddress] & STAKING_TIER_1_BIT) != 0;
    }

    /// @notice Check if the Lisk v4 address has claimed the airdrop for staking tier 2.
    /// @param liskAddress The Lisk v4 address to check if it has claimed the airdrop for staking tier 2.
    /// @return True if the Lisk v4 address has claimed the airdrop for staking tier 2, False otherwise.
    function claimedStakingTier2(bytes20 liskAddress) public view returns (bool) {
        return (airdropStatus[liskAddress] & STAKING_TIER_2_BIT) != 0;
    }

    /// @notice Check if the Lisk v4 address has claimed the full airdrop.
    /// @param liskAddress The Lisk v4 address to check if it has claimed the full airdrop.
    /// @return True if the Lisk v4 address has claimed the full airdrop, False otherwise.
    function claimedFullAirdrop(bytes20 liskAddress) public view returns (bool) {
        return (airdropStatus[liskAddress] & FULL_AIRDROP_CLAIMED) == FULL_AIRDROP_CLAIMED;
    }

    /// @notice Check if the recipient satisfies the min ETH requirement.
    /// @param recipient The recipient address to check if it satisfies the min ETH requirement.
    /// @return True if the recipient satisfies the min ETH requirement, False otherwise.
    function satisfiesMinEth(address recipient) public view returns (bool) {
        require(recipient != address(0), "L2Airdrop: recipient is the zero address");

        return recipient.balance >= MIN_ETH;
    }

    /// @notice Check if the recipient satisfies the delegating requirement.
    /// @param recipient The recipient address to check if it satisfies the delegating requirement.
    /// @return True if the recipient has delegated in Lisk DAO, False otherwise.
    function satisfiesDelegating(address recipient) public view returns (bool) {
        require(recipient != address(0), "L2Airdrop: recipient is the zero address");

        IL2VotingPower l2VotingPower = IL2VotingPower(l2VotingPowerAddress);
        return l2VotingPower.delegates(recipient) != address(0);
    }

    /// @notice Check if the recipient satisfies the staking requirement of tier 1.
    /// @param recipient The recipient address to check if it satisfies the staking requirement of tier 1.
    /// @return True if recipient has staked at least minStakingAmount for at least MIN_STAKING_DURATION_TIER_1, False
    ///         otherwise.
    function satisfiesStakingTier1(address recipient, uint256 airdropAmount) public view returns (bool) {
        require(recipient != address(0), "L2Airdrop: recipient is the zero address");
        require(airdropAmount > 0, "L2Airdrop: airdrop amount is zero");

        // get all locking positions of the recipient
        IL2LockingPosition l2LockingPosition = IL2LockingPosition(l2LockingPositionAddress);
        LockingPosition[] memory lockingPositions = l2LockingPosition.getAllLockingPositionsByOwner(recipient);

        // check if the recipient has staked at least minStakingAmount for at least MIN_STAKING_DURATION_TIER_1
        uint256 totalStakedAmount = 0;
        for (uint256 i = 0; i < lockingPositions.length; i++) {
            LockingPosition memory lockingPosition = lockingPositions[i];
            // is the locking position expired?
            if (lockingPosition.expDate < (block.timestamp / 1 days)) {
                continue;
            }
            if (lockingPosition.expDate - (block.timestamp / 1 days) >= MIN_STAKING_DURATION_TIER_1) {
                totalStakedAmount += lockingPosition.amount;
            }
        }

        uint256 minStakingAmount = MIN_STAKING_AMOUNT_MULTIPLIER * airdropAmount;

        return totalStakedAmount >= minStakingAmount;
    }

    /// @notice Check if the recipient satisfies the staking requirement of tier 2.
    /// @param recipient The recipient address to check if it satisfies the staking requirement of tier 2.
    /// @return True if recipient has staked at least minStakingAmount for at least MIN_STAKING_DURATION_TIER_2, False
    ///         otherwise.
    function satisfiesStakingTier2(address recipient, uint256 airdropAmount) public view returns (bool) {
        require(recipient != address(0), "L2Airdrop: recipient is the zero address");
        require(airdropAmount > 0, "L2Airdrop: airdrop amount is zero");

        // get all locking positions of the recipient
        IL2LockingPosition l2LockingPosition = IL2LockingPosition(l2LockingPositionAddress);
        LockingPosition[] memory lockingPositions = l2LockingPosition.getAllLockingPositionsByOwner(recipient);

        // check if the recipient has staked at least minStakingAmount for at least MIN_STAKING_DURATION_TIER_2
        uint256 totalStakedAmount = 0;
        for (uint256 i = 0; i < lockingPositions.length; i++) {
            LockingPosition memory lockingPosition = lockingPositions[i];
            // is the locking position expired?
            if (lockingPosition.expDate < (block.timestamp / 1 days)) {
                continue;
            }
            if (lockingPosition.expDate - (block.timestamp / 1 days) >= MIN_STAKING_DURATION_TIER_2) {
                totalStakedAmount += lockingPosition.amount;
            }
        }

        uint256 minStakingAmount = MIN_STAKING_AMOUNT_MULTIPLIER * airdropAmount;

        return totalStakedAmount >= minStakingAmount;
    }

    /// @notice Claim the airdrop for the recipient.
    /// @param liskAddress The Lisk v4 address to claim the airdrop for.
    /// @param amount The amount of LSK tokens to claim the airdrop for.
    /// @param merkleProof The Merkle proof for the liskAddress and amount against the stored merkleRoot.
    /// @param recipient The recipient address to claim the airdrop for.
    function claimAirdrop(
        bytes20 liskAddress,
        uint256 amount,
        bytes32[] memory merkleProof,
        address recipient
    )
        public
    {
        require(merkleRoot != 0, "L2Airdrop: airdrop has not started yet");
        require(amount > 0, "L2Airdrop: amount is zero");
        require(merkleProof.length > 0, "L2Airdrop: Merkle proof is empty");
        require(recipient != address(0), "L2Airdrop: recipient is the zero address");

        // TODO require merkleProof be a correct proof for liskv4Address and amount against stored merkleRoot
        require(IL2Claim(l2ClaimAddress).claimedTo(liskAddress) == recipient, "L2Airdrop: invalid recipient");
        require(
            (airdropStatus[liskAddress] & FULL_AIRDROP_CLAIMED) != FULL_AIRDROP_CLAIMED,
            "L2Airdrop: full airdrop claimed"
        );

        uint256 airdropAmount = 0;

        if (claimedMinEth(liskAddress) == false) {
            if (satisfiesMinEth(recipient)) {
                airdropAmount += amount / 4;
                airdropStatus[liskAddress] |= MIN_ETH_BIT;
            }
        }

        if (claimedDelegating(liskAddress) == false) {
            if (satisfiesDelegating(recipient)) {
                airdropAmount += amount / 4;
                airdropStatus[liskAddress] |= DELEGATING_BIT;
            }
        }

        if (claimedStakingTier1(liskAddress) == false) {
            if (satisfiesStakingTier1(recipient, amount)) {
                airdropAmount += amount / 4;
                airdropStatus[liskAddress] |= STAKING_TIER_1_BIT;
            }
        }

        if (claimedStakingTier2(liskAddress) == false) {
            if (satisfiesStakingTier2(recipient, amount)) {
                airdropAmount += amount / 4;
                airdropStatus[liskAddress] |= STAKING_TIER_2_BIT;
            }
        }

        // transfer airdropAmount of LSK to recipient
        bool status = IL2LiskToken(l2LiskTokenAddress).transfer(recipient, airdropAmount);
        require(status, "L2Airdrop: L2LiskToken transfer failed");
    }
}
