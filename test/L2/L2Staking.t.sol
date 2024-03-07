// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test, console2 } from "forge-std/Test.sol";
import { L2LockingPosition, LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { L2Staking } from "src/L2/L2Staking.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";

contract L2StakingTest is Test {
    L2LiskToken public l2LiskToken;
    address public remoteToken;
    address public bridge;
    L2Staking public l2Staking;
    L2Staking public l2StakingImplementation;
    L2VotingPower public l2VotingPower;
    L2VotingPower public l2VotingPowerImplementation;
    L2LockingPosition public l2LockingPosition;
    L2LockingPosition public l2LockingPositionImplementation;

    address daoContractAddress;

    address alice;
    address bob;

    function setUp() public {
        daoContractAddress = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);

        alice = address(0x1);
        bob = address(0x2);

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

        // deploy L2Staking contract via proxy
        l2Staking = L2Staking(address(new ERC1967Proxy(address(l2StakingImplementation), "")));

        assert(address(l2Staking) != address(0x0));

        // deploy L2VotingPower implementation contract
        l2VotingPowerImplementation = new L2VotingPower();

        // deploy L2VotingPower contract via proxy
        l2VotingPower = L2VotingPower(address(new ERC1967Proxy(address(l2VotingPowerImplementation), "")));

        assert(address(l2VotingPower) != address(0x0));

        // deploy L2LockingPosition implementation contract
        l2LockingPositionImplementation = new L2LockingPosition();

        // deploy L2LockingPosition contract via proxy
        l2LockingPosition = L2LockingPosition(address(new ERC1967Proxy(address(l2LockingPositionImplementation), "")));

        assert(address(l2LockingPosition) != address(0x0));

        // initialize L2Staking contract
        l2Staking.initialize(address(l2LiskToken), address(l2LockingPosition), daoContractAddress);

        // initialize L2VotingPower contract
        l2VotingPower.initialize(address(l2LockingPosition));

        assertEq(l2VotingPower.lockingPositionAddress(), address(l2LockingPosition));

        // initialize L2LockingPosition contract
        l2LockingPosition.initialize(address(l2Staking), address(l2VotingPower));

        assertEq(l2LockingPosition.name(), "Lisk Locking Position");
        assertEq(l2LockingPosition.symbol(), "LLP");
        assertEq(l2LockingPosition.owner(), address(this));
        assertEq(l2LockingPosition.stakingContract(), address(l2Staking));
        assertEq(l2LockingPosition.powerVotingContract(), address(l2VotingPower));
        assertEq(l2LockingPosition.totalSupply(), 0);

        // add alice to the creator list
        l2Staking.addCreator(alice);
        assert(l2Staking.allowedCreators(alice));

        // fund bob with 100 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(bob, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(bob), 100 * 10 ** 18);

        // approve L2Staking to spend 100 L2LiskToken
        vm.prank(bob);
        l2LiskToken.approve(address(l2Staking), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(bob, address(l2Staking)), 100 * 10 ** 18);
    }

    function test_AddCreator() public {
        l2Staking.addCreator(bob);
        assert(l2Staking.allowedCreators(bob));
    }

    function test_AddCreator_OnlyOwnerCanCall() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, bob));
        l2Staking.addCreator(bob);
    }

    function test_RemoveCreator() public {
        l2Staking.addCreator(bob);
        assert(l2Staking.allowedCreators(bob));
        l2Staking.removeCreator(bob);
        assert(!l2Staking.allowedCreators(bob));
    }

    function test_RemoveCreator_OnlyOwnerCanCall() public {
        l2Staking.addCreator(bob);
        assert(l2Staking.allowedCreators(bob));

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, bob));
        l2Staking.removeCreator(bob);
    }

    function test_LockAmount() public {
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2VotingPower.totalSupply(), 0);

        vm.prank(bob);
        l2Staking.lockAmount(bob, 100 * 10 ** 18, 365);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(bob), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(bob), 100 * 10 ** 18);
    }
}
