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
import { Utils } from "script/contracts/Utils.sol";

contract L2AirdropV2Test is Test {
    using stdStorage for StdStorage;

    L2LiskToken public l2LiskToken;
    address public remoteToken;
    address public bridge;
    L2Claim public l2Claim;
    L2Staking public l2Staking;
    L2Staking public l2StakingImplementation;
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
        bytes32 merkleRoot = bytes32(0xba12d808fc6dfcb9f649bd8aba43c8ed5f58d0c3c2fce0e904b4a85f4b805c98);
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
}
