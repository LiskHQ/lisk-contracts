// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IL2LiskToken } from "../interfaces/L2/IL2LiskToken.sol";
import { IL2LockingPosition } from "../interfaces/L2/IL2LockingPosition.sol";
import { IL2VotingPower } from "../interfaces/L2/IL2VotingPower.sol";

/// @title L2AirdropV2
/// @notice L2AirdropV2 distributes the remaining LSK tokens of the Hodlerdrop.
///         It distributes LSK tokens to eligible users based on their previous claims in L2Airdrop.
///         Each user's claim amount is proportional to their share of the total claimed amount in L2Airdrop,
///         applied to the remaining unclaimed balance. The distribution eligibility is determined by the
///         following staking conditions:
///         1. Staking Tier 1: A user is required to stake the same amount they received
///                            in the Hodlerdrop for a period of time (3 months).
///         2. Staking Tier 2: This condition is analogous to the previous, but a user is required
///                            to stake the same amount for twice as long (6months).
///         The airdrop amount is distributed to the recipient's address in L2LiskToken contract. The airdrop status for
///         each recipient is stored in a mapping. The airdrop status includes the status of each of the airdrop
///         conditions.
///         Any remaining amount left in the contract will be moved to the Ecosystem Fund.
contract L2AirdropV2 is Ownable2Step {
    /// @notice Minimal staking duration to satisfy the staking requirement of tier 1.
    uint32 public constant MIN_STAKING_DURATION_TIER_1 = 90; // 3 month

    /// @notice Minimal staking duration to satisfy the staking requirement of tier 2.
    uint32 public constant MIN_STAKING_DURATION_TIER_2 = 180; // 6 months

    /// @notice The period of time starting from the setting of the Merkle root, during which the airdrop can be
    ///         claimed.
    ///         All LSK tokens should be transferable to the Lisk Ecosystem funds afterwards.
    uint32 public constant HODLERDROP_REDISTRIBUTION_DURATION = 180; // 6 months

    /// @notice Merkle root for the airdrop process.
    bytes32 public merkleRoot;

    /// @notice Start time of the hodlerdrop. AirdropV2 is considered started once the Merkle root is set.
    uint256 public airdropStartTime;

    /// @notice Mapping of the airdropV2 status for each recipient address. In particular, for each of the airdrop
    ///         conditions (staking tier 1, staking tier 2).
    mapping(address => uint8) public airdropStatus;

    // Airdrop status bits
    // bit 0: staking tier 1
    uint8 public constant STAKING_TIER_1_BIT = 0x01;
    // bit 1: staking tier 2
    uint8 public constant STAKING_TIER_2_BIT = 0x02;
    // full airdrop claimed
    uint8 public constant FULL_AIRDROP_CLAIMED = 0x03;

    /// @notice Address of the L2LiskToken contract.
    address public immutable l2LiskTokenAddress;

    /// @notice Address of the L2LockingPosition contract.
    address public immutable l2LockingPositionAddress;

    /// @notice Address of the Ecosystem Fund wallet where the remaining LSK tokens are sent to after the airdrop is
    ///         completed.
    address public immutable ecosystemFundAddress;

    /// @notice Emitted when the Merkle root is set.
    event MerkleRootSet(bytes32 merkleRoot);

    /// @notice Emitted when the remaining LSK tokens are sent to the Ecosystem Fund wallet.
    event LSKSentToEcosystemWallet(address indexed ecosystemWalletAddress, uint256 amount);

    /// @notice Emitted when the airdrop is (partially) claimed for the recipient.
    event AirdropClaimed(uint256 amount, address indexed recipient, uint8 airdropStatus);

    /// @notice Constructs the L2AirdropV2 contract.
    /// @param _l2LiskTokenAddress Address of the L2LiskToken contract.
    /// @param _l2LockingPositionAddress Address of the L2LockingPosition contract.
    /// @param _ecosystemFundAddress Address of the Ecosystem Fund wallet.
    constructor(
        address _l2LiskTokenAddress,
        address _l2LockingPositionAddress,
        address _ecosystemFundAddress
    )
        Ownable(msg.sender)
    {
        require(_l2LiskTokenAddress != address(0), "L2AirdropV2: L2 Lisk Token contract address can not be zero");
        require(
            _l2LockingPositionAddress != address(0), "L2AirdropV2: L2 Locking Position contract address can not be zero"
        );
        require(_ecosystemFundAddress != address(0), "L2AirdropV2: Ecosystem Fund wallet address can not be zero");
        l2LiskTokenAddress = _l2LiskTokenAddress;
        l2LockingPositionAddress = _l2LockingPositionAddress;
        ecosystemFundAddress = _ecosystemFundAddress;
    }

    /// @notice Check if the recipient satisfies the staking requirement of the provided tier.
    /// @param recipient The recipient address to check if it satisfies the staking requirement of the provided tier.
    /// @param airdropAmount The amount of LSK tokens to claim the airdrop for.
    /// @param tierDuration The duration of the staking requirement for the provided tier.
    /// @return True if recipient has staked at least airdropAmount for at least MIN_STAKING_DURATION_TIER_1 or
    ///         MIN_STAKING_DURATION_TIER_2 (depending on the tier), False otherwise.
    function satisfiesStakingTier(
        address recipient,
        uint256 airdropAmount,
        uint32 tierDuration
    )
        private
        view
        returns (bool)
    {
        require(recipient != address(0), "L2AirdropV2: recipient is the zero address");
        require(airdropAmount > 0, "L2AirdropV2: airdrop amount is zero");

        // get all locking positions of the recipient
        IL2LockingPosition l2LockingPosition = IL2LockingPosition(l2LockingPositionAddress);
        IL2LockingPosition.LockingPosition[] memory lockingPositions =
            l2LockingPosition.getAllLockingPositionsByOwner(recipient);

        // check if the recipient has staked at least airdropAmount for at least tierDuration
        uint256 totalStakedAmount = 0;
        for (uint256 i = 0; i < lockingPositions.length; i++) {
            IL2LockingPosition.LockingPosition memory lockingPosition = lockingPositions[i];
            if (lockingPosition.pausedLockingDuration > 0 /* locking position is paused */ ) {
                if (lockingPosition.pausedLockingDuration >= tierDuration /* satisfies duration */ ) {
                    totalStakedAmount += lockingPosition.amount;
                }
            } /* locking position is not paused */ else {
                if (lockingPosition.expDate < (block.timestamp / 1 days) /* position expired */ ) {
                    continue; /* needed to prevent underflow in the next lines */
                }
                if (lockingPosition.expDate - (block.timestamp / 1 days) >= tierDuration /* satisfies duration */ ) {
                    totalStakedAmount += lockingPosition.amount;
                }
            }
        }

        return totalStakedAmount >= airdropAmount;
    }

    /// @notice Set Merkle root for the airdrop process.
    /// @param _merkleRoot Merkle root for the airdrop process.
    /// @dev Only the owner can set the Merkle root.
    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        require(_merkleRoot != 0, "L2AirdropV2: Merkle root can not be zero");
        require(merkleRoot == 0, "L2AirdropV2: Merkle root already set");
        merkleRoot = _merkleRoot;
        airdropStartTime = block.timestamp;
        emit MerkleRootSet(merkleRoot);
    }

    /// @notice Send the remaining LSK tokens to the Ecosystem Fund wallet.
    /// @dev Only the owner can send the remaining LSK tokens to the Ecosystem Fund wallet.
    function sendLSKToEcosystemWallet() public onlyOwner {
        require(merkleRoot != 0, "L2AirdropV2: airdrop has not started yet");
        require(
            airdropStartTime + (HODLERDROP_REDISTRIBUTION_DURATION * 1 days) < block.timestamp,
            "L2AirdropV2: airdrop is not over yet"
        );
        uint256 balance = IL2LiskToken(l2LiskTokenAddress).balanceOf(address(this));
        // reentrancy won't be an issue here because the L2 Lisk Token contract is trusted and managed by the team
        // slither-disable-next-line reentrancy-no-eth
        // slither-disable-next-line reentrancy-events
        bool status = IL2LiskToken(l2LiskTokenAddress).transfer(ecosystemFundAddress, balance);
        require(status, "L2AirdropV2: LSK token transfer to the Ecosystem Fund wallet failed");
        emit LSKSentToEcosystemWallet(ecosystemFundAddress, balance);
    }

    /// @notice Check if the address has claimed the airdrop for staking tier 1.
    /// @param recipient The Lisk v4 address to check if it has claimed the airdrop for staking tier 1.
    /// @return True if the Lisk v4 address has claimed the airdrop for staking tier 1, False otherwise.
    function claimedStakingTier1(address recipient) public view returns (bool) {
        return (airdropStatus[recipient] & STAKING_TIER_1_BIT) != 0;
    }

    /// @notice Check if the Lisk v4 address has claimed the airdrop for staking tier 2.
    /// @param recipient The Lisk v4 address to check if it has claimed the airdrop for staking tier 2.
    /// @return True if the Lisk v4 address has claimed the airdrop for staking tier 2, False otherwise.
    function claimedStakingTier2(address recipient) public view returns (bool) {
        return (airdropStatus[recipient] & STAKING_TIER_2_BIT) != 0;
    }

    /// @notice Check if the Lisk v4 address has claimed the full airdrop.
    /// @param recipient The Lisk v4 address to check if it has claimed the full airdrop.
    /// @return True if the Lisk v4 address has claimed the full airdrop, False otherwise.
    function claimedFullAirdrop(address recipient) public view returns (bool) {
        return (airdropStatus[recipient] & FULL_AIRDROP_CLAIMED) == FULL_AIRDROP_CLAIMED;
    }

    /// @notice Check if the recipient satisfies the staking requirement of tier 1.
    /// @param recipient The recipient address to check if it satisfies the staking requirement of tier 1.
    /// @param airdropAmount The amount of LSK tokens to claim the airdrop for.
    /// @return True if recipient has staked at least airdropAmount for at least MIN_STAKING_DURATION_TIER_1, False
    ///         otherwise.
    function satisfiesStakingTier1(address recipient, uint256 airdropAmount) public view returns (bool) {
        return satisfiesStakingTier(recipient, airdropAmount, MIN_STAKING_DURATION_TIER_1);
    }

    /// @notice Check if the recipient satisfies the staking requirement of tier 2.
    /// @param recipient The recipient address to check if it satisfies the staking requirement of tier 2.
    /// @param airdropAmount The amount of LSK tokens to claim the airdrop for.
    /// @return True if recipient has staked at least airdropAmount for at least MIN_STAKING_DURATION_TIER_2, False
    ///         otherwise.
    function satisfiesStakingTier2(address recipient, uint256 airdropAmount) public view returns (bool) {
        return satisfiesStakingTier(recipient, airdropAmount, MIN_STAKING_DURATION_TIER_2);
    }

    /// @notice Claim the airdrop for the recipient.
    /// @param recipient The recipient address to claim the airdrop for.
    /// @param amount The amount of LSK tokens to claim the airdrop for.
    /// @param merkleProof The Merkle proof for the address and the amount against the stored merkleRoot.
    function claimAirdrop(address recipient, uint256 amount, bytes32[] memory merkleProof) public {
        require(merkleRoot != 0, "L2AirdropV2: airdrop has not started yet");
        require(
            block.timestamp <= airdropStartTime + (HODLERDROP_REDISTRIBUTION_DURATION * 1 days),
            "L2AirdropV2: airdrop period is over"
        );
        require(recipient != address(0), "L2AirdropV2: recipient is the zero address");
        require(amount > 0, "L2AirdropV2: amount is zero");
        require(merkleProof.length > 0, "L2AirdropV2: Merkle proof is empty");
        // require merkleProof be a correct proof for liskv4Address and amount against stored merkleRoot
        require(
            MerkleProof.verify(
                merkleProof, merkleRoot, keccak256(bytes.concat(keccak256(abi.encode(recipient, amount))))
            ),
            "L2AirdropV2: invalid Merkle proof"
        );
        require(
            (airdropStatus[recipient] & FULL_AIRDROP_CLAIMED) != FULL_AIRDROP_CLAIMED,
            "L2AirdropV2: full airdrop claimed"
        );

        uint256 airdropAmount = 0;
        uint8 claimStatus = 0;

        if (claimedStakingTier1(recipient) == false) {
            if (satisfiesStakingTier1(recipient, amount)) {
                airdropAmount += amount / 2;
                airdropStatus[recipient] |= STAKING_TIER_1_BIT;
                claimStatus |= STAKING_TIER_1_BIT;
            }
        }

        if (claimedStakingTier2(recipient) == false) {
            if (satisfiesStakingTier2(recipient, amount)) {
                airdropAmount += amount / 2;
                airdropStatus[recipient] |= STAKING_TIER_2_BIT;
                claimStatus |= STAKING_TIER_2_BIT;
            }
        }

        if (claimStatus != 0) {
            // transfer airdropAmount of LSK to recipient
            // reentrancy won't be an issue here because the L2 Lisk Token contract is trusted and managed by the team
            // slither-disable-next-line reentrancy-no-eth
            // slither-disable-next-line reentrancy-events
            bool status = IL2LiskToken(l2LiskTokenAddress).transfer(recipient, airdropAmount);
            require(status, "L2AirdropV2: L2LiskToken transfer failed");

            emit AirdropClaimed(airdropAmount, recipient, claimStatus);
        }
    }
}
