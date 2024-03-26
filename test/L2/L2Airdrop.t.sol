// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Test, console2, stdStorage, StdStorage } from "forge-std/Test.sol";
import { L2Airdrop } from "src/L2/L2Airdrop.sol";
import { L2Claim } from "src/L2/L2Claim.sol";
import { L2LockingPosition, LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { L2Staking } from "src/L2/L2Staking.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";
import { Utils } from "script/Utils.sol";

contract L2AirdropTest is Test {
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
    L2Airdrop public l2Airdrop;

    address daoTreasuryAddress;
    address alice;
    bytes20 aliceLSKAddress;
    address bob;
    address charlie;

    function setUp() public {
        daoTreasuryAddress = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);
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

        // initialize Lisk DAO Treasury contract inside L2Staking contract
        l2Staking.initializeDaoTreasury(daoTreasuryAddress);
        assert(l2Staking.daoTreasury() == daoTreasuryAddress);

        // deploy L2Airdrop contract
        l2Airdrop = new L2Airdrop(
            address(l2LiskToken),
            address(l2Claim),
            address(l2LockingPosition),
            address(l2VotingPower),
            daoTreasuryAddress
        );
        assert(address(l2Airdrop) != address(0x0));
        assertEq(l2Airdrop.l2LiskTokenAddress(), address(l2LiskToken));
        assertEq(l2Airdrop.l2ClaimAddress(), address(l2Claim));
        assertEq(l2Airdrop.l2LockingPositionAddress(), address(l2LockingPosition));
        assertEq(l2Airdrop.l2VotingPowerAddress(), address(l2VotingPower));
        assertEq(l2Airdrop.daoTreasuryAddress(), daoTreasuryAddress);

        // set merkle root for L2Airdrop contract
        bytes32 merkleRoot = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
        l2Airdrop.setMerkleRoot(merkleRoot);
        assertEq(l2Airdrop.merkleRoot(), merkleRoot);

        // fund L2Airdrop with 10_000 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(address(l2Airdrop), 10000 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(address(l2Airdrop)), 10000 * 10 ** 18);

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

    function test_SetMerkleRoot() public {
        bytes32 merkleRoot = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);

        // re-deploy L2Airdrop contract because merkle root is already set in setup
        l2Airdrop = new L2Airdrop(
            address(l2LiskToken),
            address(l2Claim),
            address(l2LockingPosition),
            address(l2VotingPower),
            daoTreasuryAddress
        );

        l2Airdrop.setMerkleRoot(merkleRoot);
        assertEq(l2Airdrop.merkleRoot(), merkleRoot);
    }

    function test_SetMerkleRoot_AlreadySet() public {
        bytes32 merkleRoot = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
        vm.expectRevert("L2Airdrop: Merkle root already set");
        l2Airdrop.setMerkleRoot(merkleRoot);
    }

    function test_SetMerkleRoot_OnlyOwner() public {
        bytes32 merkleRoot = bytes32(0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        l2Airdrop.setMerkleRoot(merkleRoot);
    }

    function test_SendLSKToDaoTreasury() public {
        // send all L2LiskToken to DAO treasury
        l2Airdrop.sendLSKToDaoTreasury();
        assertEq(l2LiskToken.balanceOf(address(l2Airdrop)), 0);
        assertEq(l2LiskToken.balanceOf(daoTreasuryAddress), 10000 * 10 ** 18);
    }

    function test_SendLSKToDaoTreasury_OnlyOwner() public {
        // alice tries to send all L2LiskToken to DAO treasury
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        l2Airdrop.sendLSKToDaoTreasury();
    }

    function aliceSatisfiesMinEth() internal {
        // fund alice with exactly MIN_ETH ether (0.01 ETH)
        vm.deal(alice, 0.01 ether);
        assertEq(l2Airdrop.satisfiesMinEth(alice), true);
    }

    function test_SatisfiesMinEth() public {
        // fund bob with less than MIN_ETH ether (0.01 ETH)
        vm.deal(bob, 0.009 ether);
        assertEq(l2Airdrop.satisfiesMinEth(bob), false);

        // check that alice satisfies min eth condition
        aliceSatisfiesMinEth();

        // fund charlie with more than MIN_ETH ether (0.01 ETH)
        vm.deal(charlie, 0.011 ether);
        assertEq(l2Airdrop.satisfiesMinEth(charlie), true);
    }

    function aliceSatisfiesDelegating() internal {
        // alice is delegating
        vm.prank(alice);
        l2VotingPower.delegate(alice);
        assertEq(l2Airdrop.satisfiesDelegating(alice), true);
    }

    function test_SatisfiesDelegating() public {
        // bob is not delegating
        assertEq(l2Airdrop.satisfiesDelegating(bob), false);

        // check that alice satisfies delegating condition
        aliceSatisfiesDelegating();

        // charlie is delegating
        vm.prank(charlie);
        l2VotingPower.delegate(charlie);
        assertEq(l2Airdrop.satisfiesDelegating(charlie), true);
    }

    function aliceSatifiesStakingTier1() internal {
        // alice stakes 30 and 50 L2LiskToken for minimum and minumum plus 1 days respectively in two positions
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2Airdrop.MIN_STAKING_DURATION_TIER_1());
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2Airdrop.MIN_STAKING_DURATION_TIER_1() + 1);
        vm.stopPrank();

        // maximum staking tier 1 airdrop amount for alice is 80 / 5 = 16 L2LiskToken
        assertEq(l2Airdrop.satisfiesStakingTier1(alice, 16 * 10 ** 18), true);

        // check that bigger amount than 16 L2LiskToken does not satisfy staking tier 1
        assertEq(l2Airdrop.satisfiesStakingTier1(alice, (16 * 10 ** 18) + 1), false);
    }

    function test_SatisfiesStakingTier1() public {
        // check that alice satisfies staking tier 1
        aliceSatifiesStakingTier1();
    }

    function test_SatisfiesStakingTier1_NotAllLockingPositionsSatisfy() public {
        // alice stakes 30 L2LiskToken for minimum days in one position
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2Airdrop.MIN_STAKING_DURATION_TIER_1());
        // and 50 L2LiskToken for less than minimum staking duration in another position
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2Airdrop.MIN_STAKING_DURATION_TIER_1() - 1);
        vm.stopPrank();
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2VotingPower.balanceOf(alice), 80 * 10 ** 18);

        // check that alice does not satisfy staking tier 1 because second position is not staked for
        // MIN_STAKING_DURATION_TIER_1 days or more
        assertEq(l2Airdrop.satisfiesStakingTier1(alice, 16 * 10 ** 18), false);
    }

    function aliceSatifiesStakingTier2() internal {
        // alice stakes 30 and 50 L2LiskToken for minimum and minumum plus 1 days respectively in two positions
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2Airdrop.MIN_STAKING_DURATION_TIER_2());
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2Airdrop.MIN_STAKING_DURATION_TIER_2() + 1);
        vm.stopPrank();

        // maximum staking tier 2 airdrop amount for alice is 80 / 5 = 16 L2LiskToken
        assertEq(l2Airdrop.satisfiesStakingTier2(alice, 16 * 10 ** 18), true);

        // check that bigger amount than 16 L2LiskToken does not satisfy staking tier 2
        assertEq(l2Airdrop.satisfiesStakingTier2(alice, (16 * 10 ** 18) + 1), false);
    }

    function test_SatisfiesStakingTier2() public {
        // check that alice satisfies staking tier 2
        aliceSatifiesStakingTier2();
    }

    function test_SatisfiesStakingTier2_NotAllLockingPositionsSatisfy() public {
        // alice stakes 30 L2LiskToken for minimum days in one position
        vm.startPrank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, l2Airdrop.MIN_STAKING_DURATION_TIER_2());
        // and 50 L2LiskToken for less than minimum staking duration in another position
        l2Staking.lockAmount(alice, 50 * 10 ** 18, l2Airdrop.MIN_STAKING_DURATION_TIER_2() - 1);
        vm.stopPrank();
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2VotingPower.balanceOf(alice), 80 * 10 ** 18);

        // check that alice does not satisfy staking tier 2 because second position is not staked for
        // MIN_STAKING_DURATION_TIER_2 days or more
        assertEq(l2Airdrop.satisfiesStakingTier2(alice, 16 * 10 ** 18), false);
    }

    function aliceClaimAirdropForMinEth() internal {
        // alice satisfies min eth condition
        aliceSatisfiesMinEth();

        // alice did not claim airdrop for min eth condition
        assertEq(l2Airdrop.claimedMinEth(aliceLSKAddress), false);

        // claim airdrop for alice (only min eth condition is satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        l2Airdrop.claimAirdrop(aliceLSKAddress, 20 * 10 ** 18, merkleProof, alice);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 5 * 10 ** 18); // 5 L2LiskToken airdrop

        // check that alice has claimed airdrop for min eth condition
        assertEq(l2Airdrop.claimedMinEth(aliceLSKAddress), true);
    }

    function test_ClaimAirdrop_MinEth() public {
        // check that alice can claim airdrop for min eth condition
        aliceClaimAirdropForMinEth();
    }

    function aliceClaimAirdropForDelegating() internal {
        // alice satisfies delegating condition
        aliceSatisfiesDelegating();

        // alice did not claim airdrop for delegating condition
        assertEq(l2Airdrop.claimedDelegating(aliceLSKAddress), false);

        // claim airdrop for alice (only delegating condition is satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        l2Airdrop.claimAirdrop(aliceLSKAddress, 20 * 10 ** 18, merkleProof, alice);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 5 * 10 ** 18); // 5 L2LiskToken airdrop

        // check that alice has claimed airdrop for delegating condition
        assertEq(l2Airdrop.claimedDelegating(aliceLSKAddress), true);
    }

    function test_ClaimAirdrop_Delegating() public {
        // check that alice can claim airdrop for delegating condition
        aliceClaimAirdropForDelegating();
    }

    function aliceClaimAirdropForStakingTier1() internal {
        // alice satisfies staking tier 1 condition
        aliceSatifiesStakingTier1();

        // alice did not claim airdrop for staking tier 1 condition
        assertEq(l2Airdrop.claimedStakingTier1(aliceLSKAddress), false);

        // claim airdrop for alice (only staking tier 1 condition is satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        l2Airdrop.claimAirdrop(aliceLSKAddress, 16 * 10 ** 18, merkleProof, alice);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 4 * 10 ** 18); // 4 L2LiskToken airdrop

        // check that alice has claimed airdrop for staking tier 1 condition
        assertEq(l2Airdrop.claimedStakingTier1(aliceLSKAddress), true);
    }

    function test_ClaimAirdrop_StakingTier1() public {
        // check that alice can claim airdrop for staking tier 1 condition
        aliceClaimAirdropForStakingTier1();
    }

    function aliceClaimAirdropForStakingTier2() internal {
        // alice satisfies staking tier 2 condition
        aliceSatifiesStakingTier2();

        // alice did not claim airdrop for staking tier 2 condition
        assertEq(l2Airdrop.claimedStakingTier2(aliceLSKAddress), false);

        // claim airdrop for alice (only staking tier 2 condition is satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        l2Airdrop.claimAirdrop(aliceLSKAddress, 16 * 10 ** 18, merkleProof, alice);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 4 * 10 ** 18); // 4 L2LiskToken airdrop

        // check that alice has claimed airdrop for staking tier 2 condition
        assertEq(l2Airdrop.claimedStakingTier2(aliceLSKAddress), true);
    }

    function test_ClaimAirdrop_StakingTier2() public {
        // first alice will claim airdrop for staking tier 1 condition that only staking tier 2 condition will be left
        aliceClaimAirdropForStakingTier1();

        // check that alice can claim airdrop for staking tier 2 condition
        aliceClaimAirdropForStakingTier2();
    }

    function test_ClaimAirdrop_MinEth_Delegating() public {
        // alice satisfies min eth condition
        aliceSatisfiesMinEth();

        // alice satisfies delegating condition
        aliceSatisfiesDelegating();

        // claim airdrop for alice (min eth and delegating conditions are satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        l2Airdrop.claimAirdrop(aliceLSKAddress, 20 * 10 ** 18, merkleProof, alice);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 10 * 10 ** 18); // 10 L2LiskToken airdrop

        // check airdrop claim status for alice
        assertEq(l2Airdrop.claimedMinEth(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedDelegating(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedStakingTier1(bytes20(alice)), false);
        assertEq(l2Airdrop.claimedStakingTier2(bytes20(alice)), false);
        assertEq(l2Airdrop.claimedFullAirdrop(bytes20(alice)), false);
    }

    function test_ClaimAirdrop_StakingTier1_StakingTier2() public {
        // alice satisfies staking tier 1 condition
        aliceSatifiesStakingTier1();

        // alice satisfies staking tier 2 condition
        aliceSatifiesStakingTier2();

        // claim airdrop for alice (min eth and delegating conditions are satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        l2Airdrop.claimAirdrop(aliceLSKAddress, 16 * 10 ** 18, merkleProof, alice);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 8 * 10 ** 18); // 8 L2LiskToken airdrop

        // check airdrop claim status for alice
        assertEq(l2Airdrop.claimedMinEth(bytes20(alice)), false);
        assertEq(l2Airdrop.claimedDelegating(bytes20(alice)), false);
        assertEq(l2Airdrop.claimedStakingTier1(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedStakingTier2(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedFullAirdrop(bytes20(alice)), false);
    }

    function test_ClaimAirdrop_MinEth_Delegating_StakingTier1() public {
        // alice satisfies min eth condition
        aliceSatisfiesMinEth();

        // alice satisfies delegating condition
        aliceSatisfiesDelegating();

        // alice satisfies staking tier 1 condition
        aliceSatifiesStakingTier1();

        // claim airdrop for alice (min eth and delegating conditions are satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        l2Airdrop.claimAirdrop(aliceLSKAddress, 16 * 10 ** 18, merkleProof, alice);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 12 * 10 ** 18); // 12 L2LiskToken airdrop

        // check airdrop claim status for alice
        assertEq(l2Airdrop.claimedMinEth(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedDelegating(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedStakingTier1(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedStakingTier2(bytes20(alice)), false);
        assertEq(l2Airdrop.claimedFullAirdrop(bytes20(alice)), false);
    }

    function test_ClaimAirdrop_MinEth_StakingTier1_StakingTier2() public {
        // alice satisfies min eth condition
        aliceSatisfiesMinEth();

        // alice satisfies staking tier 1 condition
        aliceSatifiesStakingTier1();

        // alice satisfies staking tier 2 condition
        aliceSatifiesStakingTier2();

        // claim airdrop for alice (min eth and delegating conditions are satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        l2Airdrop.claimAirdrop(aliceLSKAddress, 16 * 10 ** 18, merkleProof, alice);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 12 * 10 ** 18); // 12 L2LiskToken airdrop

        // check airdrop claim status for alice
        assertEq(l2Airdrop.claimedMinEth(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedDelegating(bytes20(alice)), false);
        assertEq(l2Airdrop.claimedStakingTier1(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedStakingTier2(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedFullAirdrop(bytes20(alice)), false);
    }

    function test_ClaimAirdrop_Delegating_StakingTier1_StakingTier2() public {
        // alice satisfies delegating condition
        aliceSatisfiesDelegating();

        // alice satisfies staking tier 1 condition
        aliceSatifiesStakingTier1();

        // alice satisfies staking tier 2 condition
        aliceSatifiesStakingTier2();

        // claim airdrop for alice (min eth and delegating conditions are satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        l2Airdrop.claimAirdrop(aliceLSKAddress, 16 * 10 ** 18, merkleProof, alice);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 12 * 10 ** 18); // 12 L2LiskToken airdrop

        // check airdrop claim status for alice
        assertEq(l2Airdrop.claimedMinEth(bytes20(alice)), false);
        assertEq(l2Airdrop.claimedDelegating(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedStakingTier1(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedStakingTier2(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedFullAirdrop(bytes20(alice)), false);
    }

    function test_ClaimAirdrop_MinEth_Delegating_StakingTier2() public {
        // first alice will claim airdrop for staking tier 1 condition that only staking tier 2 condition will be left
        aliceClaimAirdropForStakingTier1();
        assertEq(l2Airdrop.claimedStakingTier1(bytes20(alice)), true);

        // alice satisfies min eth condition
        aliceSatisfiesMinEth();

        // alice satisfies delegating condition
        aliceSatisfiesDelegating();

        // alice satisfies staking tier 2 condition
        aliceSatifiesStakingTier2();

        // claim airdrop for alice (min eth and delegating conditions are satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        l2Airdrop.claimAirdrop(aliceLSKAddress, 16 * 10 ** 18, merkleProof, alice);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 12 * 10 ** 18); // 12 L2LiskToken airdrop

        // check airdrop claim status for alice
        assertEq(l2Airdrop.claimedMinEth(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedDelegating(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedStakingTier1(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedStakingTier2(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedFullAirdrop(bytes20(alice)), true); // full airdrop claimed because also staking tier
            // 1 condition was satisfied before
    }

    function test_ClaimAirdrop_FullAirdrop() public {
        // alice satisfies min eth condition
        aliceSatisfiesMinEth();

        // alice satisfies delegating condition
        aliceSatisfiesDelegating();

        // alice satisfies staking tier 1 condition
        aliceSatifiesStakingTier1();

        // alice satisfies staking tier 2 condition
        aliceSatifiesStakingTier2();

        // claim airdrop for alice (min eth and delegating conditions are satisfied)
        uint256 aliceBalanceBefore = l2LiskToken.balanceOf(alice);
        bytes32[] memory merkleProof = new bytes32[](1);
        l2Airdrop.claimAirdrop(aliceLSKAddress, 16 * 10 ** 18, merkleProof, alice);
        assertEq(l2LiskToken.balanceOf(alice), aliceBalanceBefore + 16 * 10 ** 18); // 16 L2LiskToken airdrop

        // check airdrop claim status for alice
        assertEq(l2Airdrop.claimedMinEth(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedDelegating(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedStakingTier1(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedStakingTier2(bytes20(alice)), true);
        assertEq(l2Airdrop.claimedFullAirdrop(bytes20(alice)), true);

        // check that alice cannot claim airdrop again
        vm.expectRevert("L2Airdrop: full airdrop claimed");
        l2Airdrop.claimAirdrop(bytes20(alice), 20 * 10 ** 18, merkleProof, alice);
    }

    function test_ClaimAirdrop_NotStartedYet() public {
        // re-deploy L2Airdrop contract because merkle root is already set in setup
        l2Airdrop = new L2Airdrop(
            address(l2LiskToken),
            address(l2Claim),
            address(l2LockingPosition),
            address(l2VotingPower),
            daoTreasuryAddress
        );

        bytes32[] memory merkleProof = new bytes32[](1);
        vm.expectRevert("L2Airdrop: airdrop has not started yet");
        l2Airdrop.claimAirdrop(bytes20(alice), 20 * 10 ** 18, merkleProof, alice);
    }

    function test_ClaimAirdrop_AmountIsZero() public {
        bytes32[] memory merkleProof = new bytes32[](1);
        vm.expectRevert("L2Airdrop: amount is zero");
        l2Airdrop.claimAirdrop(bytes20(alice), 0, merkleProof, alice);
    }

    function test_ClaimAirdrop_ZeroProofLength() public {
        bytes32[] memory merkleProof = new bytes32[](0);
        vm.expectRevert("L2Airdrop: Merkle proof is empty");
        l2Airdrop.claimAirdrop(bytes20(alice), 20 * 10 ** 18, merkleProof, alice);
    }

    function test_ClaimAirdrop_ZeroRecipientAddress() public {
        bytes32[] memory merkleProof = new bytes32[](1);
        vm.expectRevert("L2Airdrop: recipient is the zero address");
        l2Airdrop.claimAirdrop(bytes20(alice), 20 * 10 ** 18, merkleProof, address(0));
    }

    function test_ClaimAirdrop_InvalidRecipient() public {
        bytes32[] memory merkleProof = new bytes32[](1);
        vm.expectRevert("L2Airdrop: invalid recipient");
        l2Airdrop.claimAirdrop(bytes20(alice), 20 * 10 ** 18, merkleProof, bob);
    }
}
