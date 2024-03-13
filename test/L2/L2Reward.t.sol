// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { IL2LiskToken, IL2LockingPosition, IL2Staking, L2Reward } from "src/L2/L2Reward.sol";
import { ERC721Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC721/ERC721Upgradeable.sol";

import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { L2LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2Staking } from "src/L2/L2Staking.sol";

contract L2RewardTest is Test {
    L2LiskToken public l2LiskToken;
    L2Staking public l2Staking;
    L2LockingPosition public l2LockingPosition;
    L2Reward public l2Reward;

    address public remoteToken;
    address public bridge;
    uint256 deploymentDate = 19740;

    function setUp() public {
        skip(deploymentDate * 1 days);

        bridge = vm.addr(uint256(bytes32("bridge")));
        remoteToken = vm.addr(uint256(bytes32("remoteToken")));

        vm.prank(address(this), address(this));
        l2LiskToken = new L2LiskToken(remoteToken);
        l2LiskToken.initialize(bridge);

        l2LockingPosition = new L2LockingPosition();
        l2Staking = new L2Staking();
        l2Reward = new L2Reward(address(l2Staking), address(l2LockingPosition), address(l2LiskToken));

        // l2Staking.initialize(address(l2LiskToken));
        l2LockingPosition.initialize(address(l2Staking));
        vm.stopPrank();
    }

    function test_initialize() public {
        assertEq(l2Reward.startingDate(), deploymentDate);
        assertEq(l2Reward.OFFSET(), 150);
    }

    function test_createPosition() public {
        address alice = address(0x1);

        uint256 duration = 20;
        uint256 amount = convertLiskToBeddows(10);
        uint256 ID;

        vm.mockCall(address(l2Staking), abi.encodeWithSelector(L2Staking.lockAmount.selector), abi.encode(1));

        vm.prank(bridge);
        l2LiskToken.mint(alice, convertLiskToBeddows(1000));

        vm.startPrank(alice);
        l2LiskToken.approve(address(l2Staking), convertLiskToBeddows(100));
        ID = l2Reward.createPosition(amount, duration);
        vm.stopPrank();

        assertEq(l2Reward.totalWeight(), amount * (duration + l2Reward.OFFSET()));
        assertEq(l2Reward.lastClaimDate(ID), deploymentDate);
        assertEq(l2Reward.totalAmountLocked(), amount);
        assertEq(l2Reward.dailyUnlockedAmounts(l2Reward.startingDate() + duration), amount);
        assertEq(l2Reward.pendingUnlockAmount(), amount);
    }

    function test_onlyOwnerCanDeleteALockingPosition() public {
        address alice = address(0x1);

        // vm.prank(bridge);
        // l2LiskToken.mint(alice, convertLiskToBeddows(1000));

        vm.mockCall(address(l2Staking), abi.encodeWithSelector(L2Staking.lockAmount.selector), abi.encode(1));
        vm.mockCall(
            address(l2LockingPosition),
            abi.encodeWithSelector(ERC721Upgradeable.ownerOf.selector),
            abi.encode(address(0))
        );

        vm.startPrank(alice);
        vm.expectRevert("msg.sender does not own the locking postion");
        l2Reward.deletePosition(1);
        vm.stopPrank();
    }

    // function test_onlyExistingLockingPositionCanBeDeletedByAnOwner() public {
    //     address alice = address(0x1);
    // }

    function convertLiskToBeddows(uint256 lisk) internal pure returns (uint256) {
        return lisk * 10 ** 18;
    }
}
