// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test, console2 } from "forge-std/Test.sol";
import { stdStorage, StdStorage } from "forge-std/StdStorage.sol";
import { L2LockingPosition, LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2Staking } from "src/L2/L2Staking.sol";

contract L2LockingPositionTest is Test {
    L2Staking public l2Staking;
    L2Staking public l2StakingImplementation;
    L2LockingPosition public l2LockingPosition;
    L2LockingPosition public l2LockingPositionImplementation;

    function setUp() public {
        // deploy L2Staking implementation contract
        l2StakingImplementation = new L2Staking();

        // deploy L2Staking contract via proxy and initialize it at the same time
        l2Staking = L2Staking(
            address(
                new ERC1967Proxy(
                    address(l2StakingImplementation),
                    abi.encodeWithSelector(l2Staking.initialize.selector, address(0x0), address(0x0))
                )
            )
        );

        assert(address(l2Staking) != address(0x0));

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

        assertEq(l2LockingPosition.name(), "Lisk Locking Position");
        assertEq(l2LockingPosition.symbol(), "LLP");
        assertEq(l2LockingPosition.owner(), address(this));
        assertEq(l2LockingPosition.stakingContract(), address(l2Staking));
        assertEq(l2LockingPosition.totalSupply(), 0);
    }

    function test_Initialize_ZeroStakingContractAddress() public {
        // deploy L2LockingPosition implementation contract
        l2LockingPositionImplementation = new L2LockingPosition();

        // deploy L2LockingPosition contract via proxy and initialize it at the same time
        vm.expectRevert("L2LockingPosition: staking contract address is required");
        l2LockingPosition = L2LockingPosition(
            address(
                new ERC1967Proxy(
                    address(l2LockingPositionImplementation),
                    abi.encodeWithSelector(l2LockingPosition.initialize.selector, address(0x0))
                )
            )
        );
    }

    function test_CreateLockingPosition() public {
        address alice = address(0x1);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);

        vm.prank(address(l2Staking));
        l2LockingPosition.createLockingPosition(alice, 100 * 10 ** 18, 365, 0);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);
        assertEq(l2LockingPosition.getLockingPosition(1).lastClaimDate, 0);
    }

    function test_CreateLockingPosition_OnlyStakingCanCall() public {
        address alice = address(0x1);

        vm.prank(alice);
        vm.expectRevert("L2LockingPosition: only Staking contract can call this function");
        l2LockingPosition.createLockingPosition(alice, 100 * 10 ** 18, 365, 0);
    }

    function test_RemoveLockingPosition() public {
        address alice = address(0x1);
        address bob = address(0x2);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);
        assertEq(l2LockingPosition.balanceOf(bob), 0);

        vm.startPrank(address(l2Staking));
        l2LockingPosition.createLockingPosition(alice, 100 * 10 ** 18, 365, 0);
        l2LockingPosition.createLockingPosition(alice, 200 * 10 ** 18, 365, 0);
        l2LockingPosition.createLockingPosition(bob, 300 * 10 ** 18, 365, 0);
        l2LockingPosition.createLockingPosition(bob, 400 * 10 ** 18, 365, 0);
        l2LockingPosition.createLockingPosition(alice, 500 * 10 ** 18, 365, 0);
        vm.stopPrank();

        assertEq(l2LockingPosition.totalSupply(), 5);
        assertEq(l2LockingPosition.balanceOf(alice), 3);
        assertEq(l2LockingPosition.balanceOf(bob), 2);

        // remove the second locking position of alice; index = 1
        uint256 positionId = l2LockingPosition.tokenOfOwnerByIndex(alice, 1);
        console2.log("positionId %d", positionId);
        vm.prank(address(l2Staking));
        l2LockingPosition.removeLockingPosition(positionId);

        assertEq(l2LockingPosition.totalSupply(), 4);
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2LockingPosition.balanceOf(bob), 2);

        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(alice, 0)).amount, 100 * 10 ** 18
        );
        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(alice, 1)).amount, 500 * 10 ** 18
        );
        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 0)).amount, 300 * 10 ** 18
        );
        assertEq(
            l2LockingPosition.getLockingPosition(l2LockingPosition.tokenOfOwnerByIndex(bob, 1)).amount, 400 * 10 ** 18
        );
    }
}
