// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Test, console2, stdStorage, StdStorage } from "forge-std/Test.sol";
import { L2AirdropV2 } from "src/L2/L2AirdropV2.sol";
import { L2Claim } from "src/L2/L2Claim.sol";
import { L2LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { L2Staking } from "src/L2/L2Staking.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";
import { Utils } from "script/contracts/Utils.sol";

contract L2AirdropV2Test is Test {
    using stdStorage for StdStorage;

    L2LiskToken public l2LiskToken;
    address public remoteToken;
    address public bridge;
    L2Claim public l2Claim;
    L2Staking public l2Staking;
    L2Staking public l2StakingImplementation;
    L2VotingPower public l2VotingPower;
    L2VotingPower public l2VotingPowerImplementation;
    L2LockingPosition public l2LockingPosition;
    L2LockingPosition public l2LockingPositionImplementation;
    L2AirdropV2 public l2AirdropV2;

    address ecosystemFundWalletAddress;
    address alice;
    bytes20 aliceLSKAddress;
    address bob;
    address charlie;

    function setUp() public {
        ecosystemFundWalletAddress = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);
        alice = address(0x1);
        aliceLSKAddress = bytes20(alice);
        bob = address(0x2);
        charlie = address(0x3);

        bridge = vm.addr(uint256(bytes32("bridge")));
        remoteToken = vm.addr(uint256(bytes32("remoteToken")));

        // deploy L2LiskToken contract
        // msg.sender and tx.origin needs to be the same for the contract to be able to call initialize()
        vm.prank(address(this), address(this));
        l2LiskToken = new L2LiskToken(remoteToken);
        l2LiskToken.initialize(bridge);
        vm.stopPrank();
        assert(address(l2LiskToken) != address(0x0));

        // deploy L2Claim contract
        l2Claim = new L2Claim();

        // deploy L2Staking implementation contract
        l2StakingImplementation = new L2Staking();

        // deploy L2Staking contract via proxy and initialize it at the same time
        l2Staking = L2Staking(
            address(
                new ERC1967Proxy(
                    address(l2StakingImplementation),
                    abi.encodeWithSelector(l2Staking.initialize.selector, address(l2LiskToken))
                )
            )
        );
        assert(address(l2Staking) != address(0x0));
        assert(l2Staking.l2LiskTokenContract() == address(l2LiskToken));

        // deploy L2LockingPosition implementation contract
        l2LockingPositionImplementation = new L2LockingPosition();

        // deploy L2LockingPosition contract via proxy and initialize it at the same time
        l2LockingPosition = L2LockingPosition(
            address(
                new ERC1967Proxy(
                    address(l2LockingPositionImplementation),
                    abi.encodeWithSelector(l2LockingPosition.initialize.selector, address(l2Staking))
                )
            )
        );
        assert(address(l2LockingPosition) != address(0x0));
        assert(l2LockingPosition.stakingContract() == address(l2Staking));

        // deploy L2VotingPower implementation contract
        l2VotingPowerImplementation = new L2VotingPower();

        // deploy L2VotingPower contract via proxy and initialize it at the same time
        l2VotingPower = L2VotingPower(
            address(
                new ERC1967Proxy(
                    address(l2VotingPowerImplementation),
                    abi.encodeWithSelector(l2VotingPower.initialize.selector, address(l2LockingPosition))
                )
            )
        );
        assert(address(l2VotingPower) != address(0x0));
        assert(l2VotingPower.lockingPositionAddress() == address(l2LockingPosition));

        // initialize VotingPower contract inside L2LockingPosition contract
        l2LockingPosition.initializeVotingPower(address(l2VotingPower));
        assertEq(l2LockingPosition.votingPowerContract(), address(l2VotingPower));

        // initialize LockingPosition contract inside L2Staking contract
        l2Staking.initializeLockingPosition(address(l2LockingPosition));
        assert(l2Staking.lockingPositionContract() == address(l2LockingPosition));

        // TODO make sure we dont need this part
        // initialize Lisk DAO Treasury contract inside L2Staking contract
        //l2Staking.initializeDaoTreasury(ecosystemFundWalletAddress);
        //assert(l2Staking.daoTreasury() == ecosystemFundWalletAddress);

        // deploy L2AirdropV2 contract
        l2AirdropV2 = new L2AirdropV2(
            address(l2LiskToken), address(l2Claim), address(l2LockingPosition), ecosystemFundWalletAddress
        );
        assert(address(l2AirdropV2) != address(0x0));
        assertEq(l2AirdropV2.l2LiskTokenAddress(), address(l2LiskToken));
        assertEq(l2AirdropV2.l2ClaimAddress(), address(l2Claim));
        assertEq(l2AirdropV2.l2LockingPositionAddress(), address(l2LockingPosition));
        assertEq(l2AirdropV2.ecosystemFundAddress(), ecosystemFundWalletAddress);

        // set merkle root for L2Airdrop contract
        bytes32 merkleRoot = bytes32(0x316c2913f708e37fde39213df4870754d85af50c5ee5670b6f1e97cd3cfdcac5);
        l2AirdropV2.setMerkleRoot(merkleRoot);
        assertEq(l2AirdropV2.merkleRoot(), merkleRoot);

        // fund L2AirdropV2 with 10_000 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(address(l2AirdropV2), 10000 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(address(l2AirdropV2)), 10000 * 10 ** 18);

        // fund alice with 200 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(alice, 200 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 200 * 10 ** 18);

        // fund bob with 100 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(bob, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(bob), 100 * 10 ** 18);

        // fund charlie with 100 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(charlie, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(charlie), 100 * 10 ** 18);

        // approve L2Staking to spend alice's 200 L2LiskToken
        vm.prank(alice);
        l2LiskToken.approve(address(l2Staking), 200 * 10 ** 18);
        assertEq(l2LiskToken.allowance(alice, address(l2Staking)), 200 * 10 ** 18);

        // approve L2Staking to spend bob's 100 L2LiskToken
        vm.prank(bob);
        l2LiskToken.approve(address(l2Staking), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(bob, address(l2Staking)), 100 * 10 ** 18);

        // approve L2Staking to spend charlie's 100 L2LiskToken
        vm.prank(charlie);
        l2LiskToken.approve(address(l2Staking), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(charlie, address(l2Staking)), 100 * 10 ** 18);

        // alice has already claimed LSK tokens
        stdstore.target(address(l2Claim)).sig("claimedTo(bytes20)").with_key(aliceLSKAddress).checked_write(alice);
        assertEq(l2Claim.claimedTo(aliceLSKAddress), alice);
    }

    function test_Constructor_ZeroL2LiskTokenAddress() public {
        vm.expectRevert("L2AirdropV2: L2 Lisk Token contract address can not be zero");
        new L2AirdropV2(address(0x0), address(l2Claim), address(l2LockingPosition), ecosystemFundWalletAddress);
    }

    function test_Constructor_ZeroL2ClaimAddress() public {
        vm.expectRevert("L2AirdropV2: L2 Claim contract address can not be zero");
        new L2AirdropV2(address(l2LiskToken), address(0x0), address(l2LockingPosition), ecosystemFundWalletAddress);
    }

    function test_Constructor_ZeroL2LockingPositionAddress() public {
        vm.expectRevert("L2AirdropV2: L2 Locking Position contract address can not be zero");
        new L2AirdropV2(address(l2LiskToken), address(l2Claim), address(0x0), ecosystemFundWalletAddress);
    }

    function test_Constructor_ZeroEcosystemFundWalletAddress() public {
        vm.expectRevert("L2AirdropV2: Ecosystem Fund wallet address can not be zero");
        new L2AirdropV2(address(l2LiskToken), address(l2Claim), address(l2LockingPosition), address(0x0));
    }

    function test_SetMerkleRoot() public {
        bytes32 merkleRoot = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);

        // re-deploy L2AirdropV2 contract because merkle root is already set in setup
        l2AirdropV2 = new L2AirdropV2(
            address(l2LiskToken), address(l2Claim), address(l2LockingPosition), ecosystemFundWalletAddress
        );

        // check that the MerkleRootSet event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2AirdropV2.MerkleRootSet(merkleRoot);
        l2AirdropV2.setMerkleRoot(merkleRoot);
        assertEq(l2AirdropV2.merkleRoot(), merkleRoot);
    }

    function test_SetMerkleRoot_ZeroMerkleRoot() public {
        bytes32 merkleRoot = bytes32(0x0);
        vm.expectRevert("L2AirdropV2: Merkle root can not be zero");
        l2AirdropV2.setMerkleRoot(merkleRoot);
    }

    function test_SetMerkleRoot_AlreadySet() public {
        bytes32 merkleRoot = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
        vm.expectRevert("L2AirdropV2: Merkle root already set");
        l2AirdropV2.setMerkleRoot(merkleRoot);
    }

    function test_SetMerkleRoot_OnlyOwner() public {
        bytes32 merkleRoot = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        l2AirdropV2.setMerkleRoot(merkleRoot);
    }

    function test_SendLSKToEcosystemFundWallet() public {
        // proceed time to HODLER_AIRDROPV2_DURATION + 1 so that airdrop period is over
        vm.warp(block.timestamp + l2AirdropV2.HODLER_AIRDROPV2_DURATION() * 1 days + 1);

        // check that the LSKSentToEcosystemWallet event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2AirdropV2.LSKSentToEcosystemWallet(ecosystemFundWalletAddress, 10000 * 10 ** 18);

        // send all L2LiskToken to Airdrop wallet
        l2AirdropV2.sendLSKToEcosystemWallet();
        assertEq(l2LiskToken.balanceOf(address(l2AirdropV2)), 0);
        assertEq(l2LiskToken.balanceOf(ecosystemFundWalletAddress), 10000 * 10 ** 18);
    }

    function test_SendLSKToEcosystemFundWallet_AirdropV2HasNotStarted() public {
        // re-deploy L2AirdropV2 contract because merkle root is already set in setup
        l2AirdropV2 = new L2AirdropV2(
            address(l2LiskToken), address(l2Claim), address(l2LockingPosition), ecosystemFundWalletAddress
        );

        // Merkle root is not set so airdrop has not started yet
        vm.expectRevert("L2AirdropV2: airdrop has not started yet");
        l2AirdropV2.sendLSKToEcosystemWallet();
    }

    function test_SendLSKToEcosystemFundWallet_AirdropV2PeriodNotOver() public {
        // proceed time to HODLER_AIRDROPV2_DURATION so that airdrop period is not over
        vm.warp(block.timestamp + l2AirdropV2.HODLER_AIRDROPV2_DURATION() * 1 days);

        vm.expectRevert("L2AirdropV2: airdrop is not over yet");
        l2AirdropV2.sendLSKToEcosystemWallet();
    }

    function test_SendLSKToEcosystemFundWallet_OnlyOwner() public {
        // alice tries to send all L2LiskToken to Ecosystem Fund wallet
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        l2AirdropV2.sendLSKToEcosystemWallet();
    }

    function aliceSatifiesStakingTier1() internal {
        // alice stakes 30 and 50 L2LiskToken for minimum and minumum plus 1 days respectively in two positions
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2AirdropV2.MIN_STAKING_DURATION_TIER_1());
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2AirdropV2.MIN_STAKING_DURATION_TIER_1() + 1);
        vm.stopPrank();

        // maximum staking tier 1 airdrop amount for alice is 80 L2LiskToken
        assertEq(l2AirdropV2.satisfiesStakingTier1(alice, 80 * 10 ** 18), true);

        // check that bigger amount than 80 L2LiskToken does not satisfy staking tier 1
        assertEq(l2AirdropV2.satisfiesStakingTier1(alice, (80 * 10 ** 18) + 1), false);
    }

    function test_SatisfiesStakingTier1() public {
        // check that alice satisfies staking tier 1
        aliceSatifiesStakingTier1();
    }

    function test_SatisfiesStakingTier1_AllLockingPositionsSatisfy_PausedPositions() public {
        // alice stakes 30 L2LiskToken for minimum days in one position
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2AirdropV2.MIN_STAKING_DURATION_TIER_1());
        // and 50 L2LiskToken for minimum plus 1 days in another position
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2AirdropV2.MIN_STAKING_DURATION_TIER_1() + 1);
        vm.stopPrank();
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2VotingPower.balanceOf(alice), 80 * 10 ** 18);

        // pause both locking positions
        vm.startPrank(alice);
        l2Staking.pauseRemainingLockingDuration(1);
        l2Staking.pauseRemainingLockingDuration(2);
        vm.stopPrank();
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 90);
        assertEq(l2LockingPosition.getLockingPosition(2).pausedLockingDuration, 91);

        // proceed time to MIN_STAKING_DURATION_TIER_1 + 100 days so that both positions would not satisfy staking tier
        // 1 if positions were not paused
        vm.warp((l2AirdropV2.MIN_STAKING_DURATION_TIER_1() + 100) * 1 days);

        // check that alice satisfy staking tier 1 because both positions are paused
        assertEq(l2AirdropV2.satisfiesStakingTier1(alice, 80 * 10 ** 18), true);
    }

    function test_SatisfiesStakingTier1_NotAllLockingPositionsSatisfy_TooSmallDuration() public {
        // alice stakes 30 L2LiskToken for minimum days in one position
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2AirdropV2.MIN_STAKING_DURATION_TIER_1());
        // and 50 L2LiskToken for less than minimum staking duration in another position
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2AirdropV2.MIN_STAKING_DURATION_TIER_1() - 1);
        vm.stopPrank();
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2VotingPower.balanceOf(alice), 80 * 10 ** 18);

        // check that alice does not satisfy staking tier 1 because second position is not staked for
        // MIN_STAKING_DURATION_TIER_1 days or more
        assertEq(l2AirdropV2.satisfiesStakingTier1(alice, 80 * 10 ** 18), false);
    }

    function test_SatisfiesStakingTier1_NotAllLockingPositionsSatisfy_PositionExpired() public {
        // alice stakes 30 L2LiskToken for minimum + 20 days in one position
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2AirdropV2.MIN_STAKING_DURATION_TIER_1() + 20);
        // and 50 L2LiskToken for minimum + 40 days in another position
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2AirdropV2.MIN_STAKING_DURATION_TIER_1() + 40);
        vm.stopPrank();
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2VotingPower.balanceOf(alice), 80 * 10 ** 18);

        // proceed time to MIN_STAKING_DURATION_TIER_1 + 30 days so that first position does not satisfy staking tier 1
        vm.warp((l2AirdropV2.MIN_STAKING_DURATION_TIER_1() + 30) * 1 days);

        // check that alice does not satisfy staking tier 1 because first position already expired
        assertEq(l2AirdropV2.satisfiesStakingTier1(alice, 80 * 10 ** 18), false);
    }

    function test_SatisfiesStakingTier1_ZeroRecipientAddress() public {
        vm.expectRevert("L2AirdropV2: recipient is the zero address");
        l2AirdropV2.satisfiesStakingTier1(address(0x0), 0);
    }

    function test_SatisfiesStakingTier1_ZeroAmount() public {
        vm.expectRevert("L2AirdropV2: airdrop amount is zero");
        l2AirdropV2.satisfiesStakingTier1(alice, 0);
    }

    function aliceSatifiesStakingTier2() internal {
        // alice stakes 30 and 50 L2LiskToken for minimum and minumum plus 1 days respectively in two positions
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2AirdropV2.MIN_STAKING_DURATION_TIER_2());
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2AirdropV2.MIN_STAKING_DURATION_TIER_2() + 1);
        vm.stopPrank();

        // maximum staking tier 2 airdrop amount for alice is 80 L2LiskToken
        assertEq(l2AirdropV2.satisfiesStakingTier2(alice, 80 * 10 ** 18), true);

        // check that bigger amount than 80 L2LiskToken does not satisfy staking tier 2
        assertEq(l2AirdropV2.satisfiesStakingTier2(alice, (80 * 10 ** 18) + 1), false);
    }

    function test_SatisfiesStakingTier2() public {
        // check that alice satisfies staking tier 2
        aliceSatifiesStakingTier2();
    }

    function test_SatisfiesStakingTier2_NotAllLockingPositionsSatisfy_TooSmallDuration() public {
        // alice stakes 30 L2LiskToken for minimum days in one position
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2AirdropV2.MIN_STAKING_DURATION_TIER_2());
        // and 50 L2LiskToken for less than minimum staking duration in another position
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2AirdropV2.MIN_STAKING_DURATION_TIER_2() - 1);
        vm.stopPrank();
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2VotingPower.balanceOf(alice), 80 * 10 ** 18);

        // check that alice does not satisfy staking tier 2 because second position is not staked for
        // MIN_STAKING_DURATION_TIER_2 days or more
        assertEq(l2AirdropV2.satisfiesStakingTier2(alice, 80 * 10 ** 18), false);
    }

    function test_SatisfiesStakingTier2_NotAllLockingPositionsSatisfy_PositionExpired() public {
        // alice stakes 30 L2LiskToken for minimum + 20 days in one position
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2AirdropV2.MIN_STAKING_DURATION_TIER_2() + 20);
        // and 50 L2LiskToken for minimum + 40 days in another position
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2AirdropV2.MIN_STAKING_DURATION_TIER_2() + 40);
        vm.stopPrank();
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2VotingPower.balanceOf(alice), 80 * 10 ** 18);

        // proceed time to MIN_STAKING_DURATION_TIER_2 + 30 days so that first position does not satisfy staking tier 2
        vm.warp((l2AirdropV2.MIN_STAKING_DURATION_TIER_2() + 30) * 1 days);

        // check that alice does not satisfy staking tier 2 because first position already expired
        assertEq(l2AirdropV2.satisfiesStakingTier2(alice, 80 * 10 ** 18), false);
    }

    function test_SatisfiesStakingTier2_ZeroRecipientAddress() public {
        vm.expectRevert("L2AirdropV2: recipient is the zero address");
        l2AirdropV2.satisfiesStakingTier2(address(0x0), 0);
    }

    function test_SatisfiesStakingTier2_ZeroAmount() public {
        vm.expectRevert("L2AirdropV2: airdrop amount is zero");
        l2AirdropV2.satisfiesStakingTier2(alice, 0);
    }

    function aliceClaimAirdropForStakingTier1() internal {
        // alice satisfies staking tier 1 condition
        aliceSatifiesStakingTier1();

        // alice did not claim airdrop for staking tier 1 condition
        assertEq(l2AirdropV2.claimedStakingTier1(aliceLSKAddress), false);

        // claim airdrop for alice (only staking tier 1 condition is satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        merkleProof[0] = bytes32(0xf0df3dcda05b4fbd9c655cde3d5ceb211e019e72ec816e127a59e7195f2cd7f5);
        l2AirdropV2.claimAirdrop(aliceLSKAddress, 80 * 10 ** 18, merkleProof);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 40 * 10 ** 18); // 4 L2LiskToken airdrop

        // check that alice has claimed airdrop for staking tier 1 condition
        assertEq(l2AirdropV2.claimedStakingTier1(aliceLSKAddress), true);
    }

    function test_ClaimAirdrop_StakingTier1() public {
        // check that alice can claim airdrop for staking tier 1 condition
        aliceClaimAirdropForStakingTier1();
    }

    function aliceClaimAirdropForStakingTier2() internal {
        // alice satisfies staking tier 2 condition
        aliceSatifiesStakingTier2();

        // alice did not claim airdrop for staking tier 2 condition
        assertEq(l2AirdropV2.claimedStakingTier2(aliceLSKAddress), false);

        // claim airdrop for alice (only staking tier 2 condition is satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        merkleProof[0] = bytes32(0xf0df3dcda05b4fbd9c655cde3d5ceb211e019e72ec816e127a59e7195f2cd7f5);
        l2AirdropV2.claimAirdrop(aliceLSKAddress, 80 * 10 ** 18, merkleProof);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 40 * 10 ** 18); // 4 L2LiskToken airdrop

        // check that alice has claimed airdrop for staking tier 2 condition
        assertEq(l2AirdropV2.claimedStakingTier2(aliceLSKAddress), true);
    }

    function test_ClaimAirdrop_StakingTier2() public {
        // first alice will claim airdrop for staking tier 1 condition that only staking tier 2 condition will be left
        aliceClaimAirdropForStakingTier1();

        // check that alice can claim airdrop for staking tier 2 condition
        aliceClaimAirdropForStakingTier2();
    }
}
