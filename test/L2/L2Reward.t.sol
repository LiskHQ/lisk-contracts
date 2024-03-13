// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { IL2LiskToken, IL2LockingPosition, IL2Staking, L2Reward } from "src/L2/L2Reward.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { L2LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2Staking } from "src/L2/L2Staking.sol";

contract L2RewardTest is Test {
    L2LiskToken public l2LiskToken;
    L2Staking public l2Staking;
    L2Staking public l2StakingImplementation;
    L2LockingPosition public l2LockingPosition;
    L2Reward public l2Reward;

    address public remoteToken;
    address public bridge;
    address proxyStaking;
    uint256 deploymentDate = 19740;

    function setUp() public {
        skip(deploymentDate * 1 days);

        bridge = vm.addr(uint256(bytes32("bridge")));
        remoteToken = vm.addr(uint256(bytes32("remoteToken")));
        vm.prank(address(this), address(this));
        l2LiskToken = new L2LiskToken(remoteToken);
        l2LiskToken.initialize(bridge);
        vm.stopPrank();

        l2Staking = new L2Staking();
        l2LockingPosition = new L2LockingPosition();

        l2StakingImplementation = new L2Staking();

        // deploy L2Staking contract via proxy and initialize it at the same time
        proxyStaking = address(
            new ERC1967Proxy(
                address(l2StakingImplementation),
                abi.encodeWithSelector(l2Staking.initialize.selector, address(l2LiskToken))
            )
        );
        l2Staking = L2Staking(proxyStaking);
        l2LockingPosition.initialize(address(l2Staking));
        l2Reward = new L2Reward(address(l2Staking), address(l2LockingPosition), address(l2LiskToken));
    }

    function test_initialize() public {
        assertEq(l2Reward.startingDate(), deploymentDate);
        assertEq(l2Reward.OFFSET(), 150);
    }

    function test_createPosition() public {
        address alice = address(0x1);

        console2.logAddress(proxyStaking);

        vm.startPrank(alice);
        l2LiskToken.approve(proxyStaking, 10 ** 9);
        l2Reward.createPostion(100, 20);
        vm.stopPrank();
    }
}
