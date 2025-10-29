// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IL2LiskToken } from "../interfaces/L2/IL2LiskToken.sol";
import { IL2LockingPosition } from "../interfaces/L2/IL2LockingPosition.sol";
import { IL2VotingPower } from "../interfaces/L2/IL2VotingPower.sol";

/// @title L2HodlerdropRedistribution
/// @notice L2HodlerdropRedistribution distributes the remaining LSK tokens of the Hodlerdrop.
///         It distributes LSK tokens to eligible users based on their previous claims in L2Airdrop.
///         Each user's claim amount is proportional to their share of the total claimed amount in L2Airdrop,
///         applied to the remaining unclaimed balance. The distribution eligibility is determined by the
///         following staking conditions:
///         1. Staking Tier 1: A user is required to stake at least the same amount that can be claimed here for a
///                            period of time (3 months).
///         2. Staking Tier 2: This condition is analogous to the previous, but a user is required
///                            to stake the same amount for twice as long (6months).
///         The hodlerdrop-redistribution amount is distributed to the recipient's address in L2LiskToken contract. The
///         hodlerdrop-redistribution status for each recipient is stored in a mapping. The hodlerdrop-redistribution
///         status includes the status of each of the hodlerdrop-redistribution conditions.
///         Any remaining amount left in the contract will be moved to the Ecosystem Fund.
contract L2HodlerdropRedistribution is Ownable2Step {
    /// @notice Minimal staking duration to satisfy the staking requirement of tier 1.
    uint32 public constant MIN_STAKING_DURATION_TIER_1 = 90; // 3 month

    /// @notice Minimal staking duration to satisfy the staking requirement of tier 2.
    uint32 public constant MIN_STAKING_DURATION_TIER_2 = 180; // 6 months

    /// @notice The period of time starting from the setting of the Merkle root, during which the
    ///         hodlerdrop-redistribution can be claimed.
    ///         All LSK tokens should be transferable to the Lisk Ecosystem funds afterwards.
    uint32 public constant HODLERDROP_REDISTRIBUTION_DURATION = 180; // 6 months

    /// @notice Merkle root for the hodlerdrop-redistribution process.
    bytes32 public merkleRoot;

    /// @notice Start time of the hodlerdrop-redistribution. L2HodlerdropRedistribution is considered started once the
    ///         Merkle root is set.
    uint256 public startTime;

    /// @notice Mapping of the hodlerdrop-redistribution status for each recipient address. In particular, for each of
    ///         the hodlerdrop-redistribution conditions (staking tier 1, staking tier 2).
    mapping(address => uint8) public status;

    // Hodlerdrop-redistribution status bits
    // bit 0: staking tier 1
    uint8 public constant STAKING_TIER_1_BIT = 0x01;
    // bit 1: staking tier 2
    uint8 public constant STAKING_TIER_2_BIT = 0x02;
    // full hodlerdrop-redistribution claimed
    uint8 public constant FULL_HODLERDROP_REDISTRIBUTION_CLAIMED = 0x03;

    /// @notice Address of the L2LiskToken contract.
    address public immutable l2LiskTokenAddress;

    /// @notice Address of the L2LockingPosition contract.
    address public immutable l2LockingPositionAddress;

    /// @notice Address of the Ecosystem Fund wallet where the remaining LSK tokens are sent to after the
    ///         hodlerdrop-redistribution is completed.
    address public immutable ecosystemFundAddress;

    /// @notice Emitted when the Merkle root is set.
    event MerkleRootSet(bytes32 merkleRoot);

    /// @notice Emitted when the remaining LSK tokens are sent to the Ecosystem Fund wallet.
    event LSKSentToEcosystemWallet(address indexed ecosystemWalletAddress, uint256 amount);

    /// @notice Emitted when the Hodlerdrop-redistribution is (partially) claimed for the recipient.
    event HodlerdropRedistributionClaimed(uint256 amount, address indexed recipient, uint8 status);

    /// @notice Constructs the L2HodlerdropRedistribution contract.
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
        require(
            _l2LiskTokenAddress != address(0),
            "L2HodlerdropRedistribution: L2 Lisk Token contract address can not be zero"
        );
        require(
            _l2LockingPositionAddress != address(0),
            "L2HodlerdropRedistribution: L2 Locking Position contract address can not be zero"
        );
        require(
            _ecosystemFundAddress != address(0),
            "L2HodlerdropRedistribution: Ecosystem Fund wallet address can not be zero"
        );
        l2LiskTokenAddress = _l2LiskTokenAddress;
        l2LockingPositionAddress = _l2LockingPositionAddress;
        ecosystemFundAddress = _ecosystemFundAddress;
    }

    /// @notice Check if the recipient satisfies the staking requirement of the provided tier.
    /// @param recipient The recipient address to check if it satisfies the staking requirement of the provided tier.
    /// @param claimableAmount The amount of LSK tokens to claim the hodlerdrop-redistribution for.
    /// @param tierDuration The duration of the staking requirement for the provided tier.
    /// @return True if recipient has staked at least claimableAmount for at least MIN_STAKING_DURATION_TIER_1 or
    ///         MIN_STAKING_DURATION_TIER_2 (depending on the tier), False otherwise.
    function satisfiesStakingTier(
        address recipient,
        uint256 claimableAmount,
        uint32 tierDuration
    )
        private
        view
        returns (bool)
    {
        require(recipient != address(0), "L2HodlerdropRedistribution: recipient is the zero address");
        require(claimableAmount > 0, "L2HodlerdropRedistribution: claimable amount is zero");

        // get all locking positions of the recipient
        IL2LockingPosition l2LockingPosition = IL2LockingPosition(l2LockingPositionAddress);
        IL2LockingPosition.LockingPosition[] memory lockingPositions =
            l2LockingPosition.getAllLockingPositionsByOwner(recipient);

        // check if the recipient has staked at least claimableAmount for at least tierDuration
        uint256 totalStakedAmount = 0;
        for (uint256 i = 0; i < lockingPositions.length; i++) {
            IL2LockingPosition.LockingPosition memory lockingPosition = lockingPositions[i];
            if (
                lockingPosition.pausedLockingDuration > 0 /* locking position is paused */
            ) {
                if (
                    lockingPosition.pausedLockingDuration >= tierDuration /* satisfies duration */
                ) {
                    totalStakedAmount += lockingPosition.amount;
                }
            } /* locking position is not paused */
            else {
                if (
                    lockingPosition.expDate < (block.timestamp / 1 days) /* position expired */
                ) {
                    continue; /* needed to prevent underflow in the next lines */
                }
                if (
                    lockingPosition.expDate - (block.timestamp / 1 days) >= tierDuration /* satisfies duration */
                ) {
                    totalStakedAmount += lockingPosition.amount;
                }
            }
        }

        return totalStakedAmount >= claimableAmount;
    }

    /// @notice Set Merkle root for the hodlerdrop-redistribution process.
    /// @param _merkleRoot Merkle root for the hodlerdrop-redistribution process.
    /// @dev Only the owner can set the Merkle root.
    function setMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        require(_merkleRoot != 0, "L2HodlerdropRedistribution: Merkle root can not be zero");
        require(merkleRoot == 0, "L2HodlerdropRedistribution: Merkle root already set");
        merkleRoot = _merkleRoot;
        startTime = block.timestamp;
        emit MerkleRootSet(merkleRoot);
    }

    /// @notice Send the remaining LSK tokens to the Ecosystem Fund wallet.
    /// @dev Only the owner can send the remaining LSK tokens to the Ecosystem Fund wallet.
    function sendLSKToEcosystemWallet() public onlyOwner {
        require(merkleRoot != 0, "L2HodlerdropRedistribution: hodlerdrop-redistribution has not started yet");
        require(
            startTime + (HODLERDROP_REDISTRIBUTION_DURATION * 1 days) < block.timestamp,
            "L2HodlerdropRedistribution: hodlerdrop-redistribution is not over yet"
        );
        uint256 balance = IL2LiskToken(l2LiskTokenAddress).balanceOf(address(this));
        // reentrancy won't be an issue here because the L2 Lisk Token contract is trusted and managed by the team
        // slither-disable-next-line reentrancy-no-eth
        // slither-disable-next-line reentrancy-events
        bool transferStatus = IL2LiskToken(l2LiskTokenAddress).transfer(ecosystemFundAddress, balance);
        require(transferStatus, "L2HodlerdropRedistribution: LSK token transfer to the Ecosystem Fund wallet failed");
        emit LSKSentToEcosystemWallet(ecosystemFundAddress, balance);
    }

    /// @notice Check if the recipient address has claimed the hodlerdrop-redistribution for staking tier 1.
    /// @param recipient The address to check if it has claimed the hodlerdrop-redistribution for staking tier 1.
    /// @return True if the recipient address has claimed the hodlerdrop-redistribution for staking tier 1, False
    ///         otherwise.
    function claimedStakingTier1(address recipient) public view returns (bool) {
        return (status[recipient] & STAKING_TIER_1_BIT) != 0;
    }

    /// @notice Check if the recipient address has claimed the hodlerdrop-redistribution for staking tier 2.
    /// @param recipient The address to check if it has claimed the hodlerdrop-redistribution for staking tier 2.
    /// @return True if the recipient address has claimed the hodlerdrop-redistribution for staking tier 2, False
    ///         otherwise.
    function claimedStakingTier2(address recipient) public view returns (bool) {
        return (status[recipient] & STAKING_TIER_2_BIT) != 0;
    }

    /// @notice Check if the recipient address has claimed the full hodlerdrop-redistribution.
    /// @param recipient The address to check if it has claimed the full hodlerdrop-redistribution.
    /// @return True if the recipient address has claimed the full hodlerdrop-redistribution, False otherwise.
    function claimedFullHodlerdropRedistribution(address recipient) public view returns (bool) {
        return (status[recipient] & FULL_HODLERDROP_REDISTRIBUTION_CLAIMED) == FULL_HODLERDROP_REDISTRIBUTION_CLAIMED;
    }

    /// @notice Check if the recipient satisfies the staking requirement of tier 1.
    /// @param recipient The recipient address to check if it satisfies the staking requirement of tier 1.
    /// @param claimableAmount The amount of LSK tokens to claim the hodlerdrop-redistribution for.
    /// @return True if recipient has staked at least claimableAmount for at least MIN_STAKING_DURATION_TIER_1, False
    ///         otherwise.
    function satisfiesStakingTier1(address recipient, uint256 claimableAmount) public view returns (bool) {
        return satisfiesStakingTier(recipient, claimableAmount, MIN_STAKING_DURATION_TIER_1);
    }

    /// @notice Check if the recipient satisfies the staking requirement of tier 2.
    /// @param recipient The recipient address to check if it satisfies the staking requirement of tier 2.
    /// @param claimableAmount The amount of LSK tokens to claim the hodlerdrop-redistribution for.
    /// @return True if recipient has staked at least claimableAmount for at least MIN_STAKING_DURATION_TIER_2, False
    ///         otherwise.
    function satisfiesStakingTier2(address recipient, uint256 claimableAmount) public view returns (bool) {
        return satisfiesStakingTier(recipient, claimableAmount, MIN_STAKING_DURATION_TIER_2);
    }

    /// @notice Claim the Hodlerdrop redistribution for the recipient.
    /// @param recipient The recipient address to claim the hodlerdrop-redistribution for.
    /// @param amount The amount of LSK tokens to claim the hodlerdrop-redistribution for.
    /// @param merkleProof The Merkle proof for the recipient address and the amount against the stored merkleRoot.
    function claimHodlerdropRedistribution(
        address recipient,
        uint256 amount,
        bytes32[] memory merkleProof
    )
        public
    {
        require(merkleRoot != 0, "L2HodlerdropRedistribution: hodlerdrop-redistribution has not started yet");
        require(
            block.timestamp <= startTime + (HODLERDROP_REDISTRIBUTION_DURATION * 1 days),
            "L2HodlerdropRedistribution: hodlerdrop-redistribution period is over"
        );
        require(recipient != address(0), "L2HodlerdropRedistribution: recipient is the zero address");
        require(amount > 0, "L2HodlerdropRedistribution: amount is zero");
        require(merkleProof.length > 0, "L2HodlerdropRedistribution: Merkle proof is empty");
        // require merkleProof be a correct proof for the recipient address and amount against stored merkleRoot
        require(
            MerkleProof.verify(
                merkleProof, merkleRoot, keccak256(bytes.concat(keccak256(abi.encode(recipient, amount))))
            ),
            "L2HodlerdropRedistribution: invalid Merkle proof"
        );
        require(
            (status[recipient] & FULL_HODLERDROP_REDISTRIBUTION_CLAIMED) != FULL_HODLERDROP_REDISTRIBUTION_CLAIMED,
            "L2HodlerdropRedistribution: full hodlerdrop-redistribution claimed"
        );

        uint256 claimableAmount = 0;
        uint8 claimStatus = 0;

        if (claimedStakingTier1(recipient) == false) {
            if (satisfiesStakingTier1(recipient, amount)) {
                claimableAmount += amount / 2;
                status[recipient] |= STAKING_TIER_1_BIT;
                claimStatus |= STAKING_TIER_1_BIT;
            }
        }

        if (claimedStakingTier2(recipient) == false) {
            if (satisfiesStakingTier2(recipient, amount)) {
                claimableAmount += amount / 2;
                status[recipient] |= STAKING_TIER_2_BIT;
                claimStatus |= STAKING_TIER_2_BIT;
            }
        }

        if (claimStatus != 0) {
            // transfer claimableAmount of LSK to recipient
            // reentrancy won't be an issue here because the L2 Lisk Token contract is trusted and managed by the team
            // slither-disable-next-line reentrancy-no-eth
            // slither-disable-next-line reentrancy-events
            bool transferStatus = IL2LiskToken(l2LiskTokenAddress).transfer(recipient, claimableAmount);
            require(transferStatus, "L2HodlerdropRedistribution: L2LiskToken transfer failed");

            emit HodlerdropRedistributionClaimed(claimableAmount, recipient, claimStatus);
        }
    }
}
