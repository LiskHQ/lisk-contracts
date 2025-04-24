// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Test, console2, stdStorage, StdStorage } from "forge-std/Test.sol";
import { L2HodlerdropRedistribution } from "src/L2/L2HodlerdropRedistribution.sol";
import { L2Claim } from "src/L2/L2Claim.sol";
import { L2LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { L2Staking } from "src/L2/L2Staking.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";
import { Utils } from "script/contracts/Utils.sol";

contract L2HodlerdropRedistributionTest is Test {
    using stdStorage for StdStorage;

    L2LiskToken public l2LiskToken;
    address public remoteToken;
    address public bridge;
    L2Staking public l2Staking;
    L2Staking public l2StakingImplementation;
    L2VotingPower public l2VotingPower;
    L2VotingPower public l2VotingPowerImplementation;
    L2LockingPosition public l2LockingPosition;
    L2LockingPosition public l2LockingPositionImplementation;
    L2HodlerdropRedistribution public l2HodlerdropRedistribution;

    address ecosystemFundWalletAddress;
    address alice;
    address bob;
    address charlie;

    function setUp() public {
        ecosystemFundWalletAddress = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);
        alice = address(0x1);
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

        // deploy L2HodlerdropRedistribution contract
        l2HodlerdropRedistribution =
            new L2HodlerdropRedistribution(address(l2LiskToken), address(l2LockingPosition), ecosystemFundWalletAddress);
        assert(address(l2HodlerdropRedistribution) != address(0x0));
        assertEq(l2HodlerdropRedistribution.l2LiskTokenAddress(), address(l2LiskToken));
        assertEq(l2HodlerdropRedistribution.l2LockingPositionAddress(), address(l2LockingPosition));
        assertEq(l2HodlerdropRedistribution.ecosystemFundAddress(), ecosystemFundWalletAddress);

        // set merkle root for L2HodlerdropRedistribution contract
        bytes32 merkleRoot = bytes32(0x05da2740a58e38dd8375b42c4a501bc32d90ba14ebc98da356c822cd24ec9a3a);
        l2HodlerdropRedistribution.setMerkleRoot(merkleRoot);
        assertEq(l2HodlerdropRedistribution.merkleRoot(), merkleRoot);

        // fund L2HodlerdropRedistribution with 10_000 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(address(l2HodlerdropRedistribution), 10000 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(address(l2HodlerdropRedistribution)), 10000 * 10 ** 18);

        // fund alice with 200 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(alice, 200 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 200 * 10 ** 18);

        // fund bob with 100 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(bob, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(bob), 100 * 10 ** 18);

        // fund charlie with 410 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(charlie, 410 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(charlie), 410 * 10 ** 18);

        // approve L2Staking to spend alice's 200 L2LiskToken
        vm.prank(alice);
        l2LiskToken.approve(address(l2Staking), 200 * 10 ** 18);
        assertEq(l2LiskToken.allowance(alice, address(l2Staking)), 200 * 10 ** 18);

        // approve L2Staking to spend bob's 100 L2LiskToken
        vm.prank(bob);
        l2LiskToken.approve(address(l2Staking), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(bob, address(l2Staking)), 100 * 10 ** 18);

        // approve L2Staking to spend charlie's 400 L2LiskToken
        vm.prank(charlie);
        l2LiskToken.approve(address(l2Staking), 400 * 10 ** 18);
        assertEq(l2LiskToken.allowance(charlie, address(l2Staking)), 400 * 10 ** 18);
    }

    function test_Constructor_ZeroL2LiskTokenAddress() public {
        vm.expectRevert("L2HodlerdropRedistribution: L2 Lisk Token contract address can not be zero");
        new L2HodlerdropRedistribution(address(0x0), address(l2LockingPosition), ecosystemFundWalletAddress);
    }

    function test_Constructor_ZeroL2LockingPositionAddress() public {
        vm.expectRevert("L2HodlerdropRedistribution: L2 Locking Position contract address can not be zero");
        new L2HodlerdropRedistribution(address(l2LiskToken), address(0x0), ecosystemFundWalletAddress);
    }

    function test_Constructor_ZeroEcosystemFundWalletAddress() public {
        vm.expectRevert("L2HodlerdropRedistribution: Ecosystem Fund wallet address can not be zero");
        new L2HodlerdropRedistribution(address(l2LiskToken), address(l2LockingPosition), address(0x0));
    }

    function test_SetMerkleRoot() public {
        bytes32 merkleRoot = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);

        // re-deploy L2HodlerdropRedistribution contract because merkle root is already set in setup
        l2HodlerdropRedistribution =
            new L2HodlerdropRedistribution(address(l2LiskToken), address(l2LockingPosition), ecosystemFundWalletAddress);

        // check that the MerkleRootSet event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2HodlerdropRedistribution.MerkleRootSet(merkleRoot);
        l2HodlerdropRedistribution.setMerkleRoot(merkleRoot);
        assertEq(l2HodlerdropRedistribution.merkleRoot(), merkleRoot);
    }

    function test_SetMerkleRoot_ZeroMerkleRoot() public {
        bytes32 merkleRoot = bytes32(0x0);
        vm.expectRevert("L2HodlerdropRedistribution: Merkle root can not be zero");
        l2HodlerdropRedistribution.setMerkleRoot(merkleRoot);
    }

    function test_SetMerkleRoot_AlreadySet() public {
        bytes32 merkleRoot = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
        vm.expectRevert("L2HodlerdropRedistribution: Merkle root already set");
        l2HodlerdropRedistribution.setMerkleRoot(merkleRoot);
    }

    function test_SetMerkleRoot_OnlyOwner() public {
        bytes32 merkleRoot = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        l2HodlerdropRedistribution.setMerkleRoot(merkleRoot);
    }

    function test_SendLSKToEcosystemFundWallet() public {
        // proceed time to HODLERDROP_REDISTRIBUTION_DURATION + 1 so that hodlerdrop period is over
        vm.warp(block.timestamp + l2HodlerdropRedistribution.HODLERDROP_REDISTRIBUTION_DURATION() * 1 days + 1);

        // check that the LSKSentToEcosystemWallet event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2HodlerdropRedistribution.LSKSentToEcosystemWallet(ecosystemFundWalletAddress, 10000 * 10 ** 18);

        // send all L2LiskToken to Airdrop wallet
        l2HodlerdropRedistribution.sendLSKToEcosystemWallet();
        assertEq(l2LiskToken.balanceOf(address(l2HodlerdropRedistribution)), 0);
        assertEq(l2LiskToken.balanceOf(ecosystemFundWalletAddress), 10000 * 10 ** 18);
    }

    function test_SendLSKToEcosystemFundWallet_AirdropV2HasNotStarted() public {
        // re-deploy L2HodlerdropRedistribution contract because merkle root is already set in setup
        l2HodlerdropRedistribution =
            new L2HodlerdropRedistribution(address(l2LiskToken), address(l2LockingPosition), ecosystemFundWalletAddress);

        // Merkle root is not set so hodlerdrop has not started yet
        vm.expectRevert("L2HodlerdropRedistribution: hodlerdrop has not started yet");
        l2HodlerdropRedistribution.sendLSKToEcosystemWallet();
    }

    function test_SendLSKToEcosystemFundWallet_AirdropV2PeriodNotOver() public {
        // proceed time to HODLERDROP_REDISTRIBUTION_DURATION so that hodlerdrop period is not over
        vm.warp(block.timestamp + l2HodlerdropRedistribution.HODLERDROP_REDISTRIBUTION_DURATION() * 1 days);

        vm.expectRevert("L2HodlerdropRedistribution: hodlerdrop is not over yet");
        l2HodlerdropRedistribution.sendLSKToEcosystemWallet();
    }

    function test_SendLSKToEcosystemFundWallet_OnlyOwner() public {
        // alice tries to send all L2LiskToken to Ecosystem Fund wallet
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        l2HodlerdropRedistribution.sendLSKToEcosystemWallet();
    }

    function aliceSatifiesStakingTier1() internal {
        // alice stakes 30 and 50 L2LiskToken for minimum and minumum plus 1 days respectively in two positions
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_1());
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_1() + 1);
        vm.stopPrank();

        // maximum staking tier 1 hodlerdrop amount for alice is 80 L2LiskToken
        assertEq(l2HodlerdropRedistribution.satisfiesStakingTier1(alice, 80 * 10 ** 18), true);

        // check that bigger amount than 80 L2LiskToken does not satisfy staking tier 1
        assertEq(l2HodlerdropRedistribution.satisfiesStakingTier1(alice, (80 * 10 ** 18) + 1), false);
    }

    function test_SatisfiesStakingTier1() public {
        // check that alice satisfies staking tier 1
        aliceSatifiesStakingTier1();
    }

    function test_charlieSatifiesStakingTier1With400LockingPositions() public {
        vm.startPrank(charlie);
        // charlie stakes 1 L2LiskToken for minimum days in 400 positions
        for (uint256 index = 0; index < 400; index++) {
            l2Staking.lockAmount(charlie, 1 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_1());
        }
        vm.stopPrank();

        // maximum staking tier 1 hodlerdrop amount for charlie is 400 L2LiskToken
        assertEq(l2HodlerdropRedistribution.satisfiesStakingTier1(charlie, 400 * 10 ** 18), true);
    }

    function test_SatisfiesStakingTier1_AllLockingPositionsSatisfy_PausedPositions() public {
        // alice stakes 30 L2LiskToken for minimum days in one position
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_1());
        // and 50 L2LiskToken for minimum plus 1 days in another position
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_1() + 1);
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
        vm.warp((l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_1() + 100) * 1 days);

        // check that alice satisfy staking tier 1 because both positions are paused
        assertEq(l2HodlerdropRedistribution.satisfiesStakingTier1(alice, 80 * 10 ** 18), true);
    }

    function test_SatisfiesStakingTier1_NotAllLockingPositionsSatisfy_TooSmallDuration() public {
        // alice stakes 30 L2LiskToken for minimum days in one position
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_1());
        // and 50 L2LiskToken for less than minimum staking duration in another position
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_1() - 1);
        vm.stopPrank();
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2VotingPower.balanceOf(alice), 80 * 10 ** 18);

        // check that alice does not satisfy staking tier 1 because second position is not staked for
        // MIN_STAKING_DURATION_TIER_1 days or more
        assertEq(l2HodlerdropRedistribution.satisfiesStakingTier1(alice, 80 * 10 ** 18), false);
    }

    function test_SatisfiesStakingTier1_NotAllLockingPositionsSatisfy_PositionExpired() public {
        // alice stakes 30 L2LiskToken for minimum + 20 days in one position
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_1() + 20);
        // and 50 L2LiskToken for minimum + 40 days in another position
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_1() + 40);
        vm.stopPrank();
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2VotingPower.balanceOf(alice), 80 * 10 ** 18);

        // proceed time to MIN_STAKING_DURATION_TIER_1 + 30 days so that first position does not satisfy staking tier 1
        vm.warp((l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_1() + 30) * 1 days);

        // check that alice does not satisfy staking tier 1 because first position already expired
        assertEq(l2HodlerdropRedistribution.satisfiesStakingTier1(alice, 80 * 10 ** 18), false);
    }

    function test_SatisfiesStakingTier1_ZeroRecipientAddress() public {
        vm.expectRevert("L2HodlerdropRedistribution: recipient is the zero address");
        l2HodlerdropRedistribution.satisfiesStakingTier1(address(0x0), 0);
    }

    function test_SatisfiesStakingTier1_ZeroAmount() public {
        vm.expectRevert("L2HodlerdropRedistribution: hodlerdrop amount is zero");
        l2HodlerdropRedistribution.satisfiesStakingTier1(alice, 0);
    }

    function aliceSatifiesStakingTier2() internal {
        // alice stakes 30 and 50 L2LiskToken for minimum and minumum plus 1 days respectively in two positions
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_2());
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_2() + 1);
        vm.stopPrank();

        // maximum staking tier 2 hodlerdrop amount for alice is 80 L2LiskToken
        assertEq(l2HodlerdropRedistribution.satisfiesStakingTier2(alice, 80 * 10 ** 18), true);

        // check that bigger amount than 80 L2LiskToken does not satisfy staking tier 2
        assertEq(l2HodlerdropRedistribution.satisfiesStakingTier2(alice, (80 * 10 ** 18) + 1), false);
    }

    function test_SatisfiesStakingTier2() public {
        // check that alice satisfies staking tier 2
        aliceSatifiesStakingTier2();
    }

    function test_SatisfiesStakingTier2_NotAllLockingPositionsSatisfy_TooSmallDuration() public {
        // alice stakes 30 L2LiskToken for minimum days in one position
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_2());
        // and 50 L2LiskToken for less than minimum staking duration in another position
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_2() - 1);
        vm.stopPrank();
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2VotingPower.balanceOf(alice), 80 * 10 ** 18);

        // check that alice does not satisfy staking tier 2 because second position is not staked for
        // MIN_STAKING_DURATION_TIER_2 days or more
        assertEq(l2HodlerdropRedistribution.satisfiesStakingTier2(alice, 80 * 10 ** 18), false);
    }

    function test_SatisfiesStakingTier2_NotAllLockingPositionsSatisfy_PositionExpired() public {
        // alice stakes 30 L2LiskToken for minimum + 20 days in one position
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_2() + 20);
        // and 50 L2LiskToken for minimum + 40 days in another position
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_2() + 40);
        vm.stopPrank();
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2VotingPower.balanceOf(alice), 80 * 10 ** 18);

        // proceed time to MIN_STAKING_DURATION_TIER_2 + 30 days so that first position does not satisfy staking tier 2
        vm.warp((l2HodlerdropRedistribution.MIN_STAKING_DURATION_TIER_2() + 30) * 1 days);

        // check that alice does not satisfy staking tier 2 because first position already expired
        assertEq(l2HodlerdropRedistribution.satisfiesStakingTier2(alice, 80 * 10 ** 18), false);
    }

    function test_SatisfiesStakingTier2_ZeroRecipientAddress() public {
        vm.expectRevert("L2HodlerdropRedistribution: recipient is the zero address");
        l2HodlerdropRedistribution.satisfiesStakingTier2(address(0x0), 0);
    }

    function test_SatisfiesStakingTier2_ZeroAmount() public {
        vm.expectRevert("L2HodlerdropRedistribution: hodlerdrop amount is zero");
        l2HodlerdropRedistribution.satisfiesStakingTier2(alice, 0);
    }

    function aliceClaimAirdropForStakingTier1() internal {
        // alice satisfies staking tier 1 condition
        aliceSatifiesStakingTier1();

        // alice did not claim hodlerdrop for staking tier 1 condition
        assertEq(l2HodlerdropRedistribution.claimedStakingTier1(alice), false);

        // claim hodlerdrop for alice (only staking tier 1 condition is satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        merkleProof[0] = bytes32(0xf0df3dcda05b4fbd9c655cde3d5ceb211e019e72ec816e127a59e7195f2cd7f5);
        l2HodlerdropRedistribution.claimHodlerdrop(alice, 80 * 10 ** 18, merkleProof);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 40 * 10 ** 18);

        // check that alice has claimed hodlerdrop for staking tier 1 condition
        assertEq(l2HodlerdropRedistribution.claimedStakingTier1(alice), true);
    }

    function test_ClaimAirdrop_StakingTier1() public {
        // check that alice can claim hodlerdrop for staking tier 1 condition
        aliceClaimAirdropForStakingTier1();
    }

    function aliceClaimAirdropForStakingTier2() internal {
        // alice satisfies staking tier 2 condition
        aliceSatifiesStakingTier2();

        // alice did not claim hodlerdrop for staking tier 2 condition
        assertEq(l2HodlerdropRedistribution.claimedStakingTier2(alice), false);

        // claim hodlerdrop for alice (only staking tier 2 condition is satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        merkleProof[0] = bytes32(0xf0df3dcda05b4fbd9c655cde3d5ceb211e019e72ec816e127a59e7195f2cd7f5);
        l2HodlerdropRedistribution.claimHodlerdrop(alice, 80 * 10 ** 18, merkleProof);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 40 * 10 ** 18);

        // check that alice has claimed hodlerdrop for staking tier 2 condition
        assertEq(l2HodlerdropRedistribution.claimedStakingTier2(alice), true);
    }

    function test_ClaimAirdrop_StakingTier2() public {
        // first alice will claim hodlerdrop for staking tier 1 condition that only staking tier 2 condition will be
        // left
        aliceClaimAirdropForStakingTier1();

        // check that alice can claim hodlerdrop for staking tier 2 condition
        aliceClaimAirdropForStakingTier2();
    }

    function test_ClaimAirdrop_FullAirdrop() public {
        // alice satisfies staking tier 1 condition
        aliceSatifiesStakingTier1();

        // alice satisfies staking tier 2 condition
        aliceSatifiesStakingTier2();

        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        merkleProof[0] = bytes32(0xf0df3dcda05b4fbd9c655cde3d5ceb211e019e72ec816e127a59e7195f2cd7f5);

        // check that the HodlerdropClaimed event is emitted for all conditions
        vm.expectEmit(true, true, true, true);
        emit L2HodlerdropRedistribution.HodlerdropClaimed(
            80 * 10 ** 18,
            alice,
            l2HodlerdropRedistribution.STAKING_TIER_1_BIT() | l2HodlerdropRedistribution.STAKING_TIER_2_BIT()
        );

        l2HodlerdropRedistribution.claimHodlerdrop(alice, 80 * 10 ** 18, merkleProof);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 80 * 10 ** 18);

        // check hodlerdrop claim status for alice
        assertEq(l2HodlerdropRedistribution.claimedStakingTier1(alice), true);
        assertEq(l2HodlerdropRedistribution.claimedStakingTier2(alice), true);
        assertEq(l2HodlerdropRedistribution.claimedFullHodlerdrop(alice), true);

        // check that alice cannot claim hodlerdrop again
        vm.expectRevert("L2HodlerdropRedistribution: full hodlerdrop claimed");
        l2HodlerdropRedistribution.claimHodlerdrop(alice, 80 * 10 ** 18, merkleProof);
    }

    function test_ClaimAirdrop_NotStartedYet() public {
        // re-deploy L2HodlerdropRedistribution contract because merkle root is already set in setup
        l2HodlerdropRedistribution =
            new L2HodlerdropRedistribution(address(l2LiskToken), address(l2LockingPosition), ecosystemFundWalletAddress);

        bytes32[] memory merkleProof = new bytes32[](1);
        vm.expectRevert("L2HodlerdropRedistribution: hodlerdrop has not started yet");
        l2HodlerdropRedistribution.claimHodlerdrop(alice, 20 * 10 ** 18, merkleProof);
    }

    function test_ClaimAirdrop_AirdropOver() public {
        // proceed time to HODLERDROP_REDISTRIBUTION_DURATION + 1 so that hodlerdrop period is over
        vm.warp(block.timestamp + l2HodlerdropRedistribution.HODLERDROP_REDISTRIBUTION_DURATION() * 1 days + 1);

        bytes32[] memory merkleProof = new bytes32[](1);
        vm.expectRevert("L2HodlerdropRedistribution: hodlerdrop period is over");
        l2HodlerdropRedistribution.claimHodlerdrop(alice, 20 * 10 ** 18, merkleProof);
    }

    function test_ClaimAirdrop_AmountIsZero() public {
        bytes32[] memory merkleProof = new bytes32[](1);
        vm.expectRevert("L2HodlerdropRedistribution: amount is zero");
        l2HodlerdropRedistribution.claimHodlerdrop(alice, 0, merkleProof);
    }

    function test_ClaimAirdrop_ZeroProofLength() public {
        bytes32[] memory merkleProof = new bytes32[](0);
        vm.expectRevert("L2HodlerdropRedistribution: Merkle proof is empty");
        l2HodlerdropRedistribution.claimHodlerdrop(alice, 20 * 10 ** 18, merkleProof);
    }

    function test_ClaimAirdrop_ZeroRecipientAddress() public {
        bytes32[] memory merkleProof = new bytes32[](1);
        vm.expectRevert("L2HodlerdropRedistribution: recipient is the zero address");
        // bob did not claim tokens in the Claim contract
        l2HodlerdropRedistribution.claimHodlerdrop(address(0x0), 20 * 10 ** 18, merkleProof);
    }

    function test_TransferOwnership() public {
        address newOwner = vm.addr(1);

        l2HodlerdropRedistribution.transferOwnership(newOwner);
        assertEq(l2HodlerdropRedistribution.owner(), address(this));

        vm.prank(newOwner);
        l2HodlerdropRedistribution.acceptOwnership();
        assertEq(l2HodlerdropRedistribution.owner(), newOwner);
    }

    function test_TransferOwnership_RevertWhenNotCalledByOwner() public {
        address newOwner = vm.addr(1);
        address nobody = vm.addr(2);

        // owner is this contract
        assertEq(l2HodlerdropRedistribution.owner(), address(this));

        // address nobody is not the owner so it cannot call transferOwnership
        vm.startPrank(nobody);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nobody));
        l2HodlerdropRedistribution.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function test_TransferOwnership_RevertWhenNotCalledByPendingOwner() public {
        address newOwner = vm.addr(1);

        l2HodlerdropRedistribution.transferOwnership(newOwner);
        assertEq(l2HodlerdropRedistribution.owner(), address(this));

        address nobody = vm.addr(2);
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nobody));
        l2HodlerdropRedistribution.acceptOwnership();
    }
}
