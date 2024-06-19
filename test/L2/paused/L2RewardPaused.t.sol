// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console2 } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { L2Reward } from "src/L2/L2Reward.sol";
import { L2RewardPaused } from "src/L2/paused/L2RewardPaused.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { L2LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2LockingPositionPaused } from "src/L2/paused/L2LockingPositionPaused.sol";
import { L2Staking } from "src/L2/L2Staking.sol";

contract L2RewardV2 is L2Reward {
    uint256 public testNumber;

    function initializeV2(uint256 _testNumber) public reinitializer(3) {
        testNumber = _testNumber;
        version = "2.0.0";
    }

    function onlyV2() public pure returns (string memory) {
        return "Only L2RewardV2 have this function";
    }
}

contract L2RewardPausedTest is Test {
    L2LiskToken public l2LiskToken;
    L2Staking public l2Staking;
    L2Staking public l2StakingImplementation;
    L2LockingPosition public l2LockingPosition;
    L2LockingPosition public l2LockingPositionImplementation;
    L2VotingPower public l2VotingPowerImplementation;
    L2VotingPower public l2VotingPower;
    L2Reward public l2Reward;
    L2Reward public l2RewardImplementation;
    L2RewardPaused public l2RewardPausedProxy;

    address public remoteToken;
    address public bridge;
    uint256 deploymentDate = 19740;
    address public staker = address(0x1);

    uint256[] public stakerPositions = new uint256[](1);
    uint256 public ID;

    struct Funds {
        uint256 amount;
        uint16 duration;
        uint16 delay;
    }

    struct Position {
        uint256 amount;
        uint256 duration;
    }

    function upgradeLockingPositionContractToPausedVersion() private {
        // deploy L2LockingPositionPaused contract
        L2LockingPositionPaused l2LockingPositionPaused = new L2LockingPositionPaused();

        // upgrade L2LockingPosition contract to L2LockingPositionPaused contract
        l2LockingPosition.upgradeToAndCall(
            address(l2LockingPositionPaused), abi.encodeWithSelector(l2LockingPositionPaused.initializePaused.selector)
        );
    }

    function convertLiskToSmallestDenomination(uint256 lisk) internal pure returns (uint256) {
        return lisk * 10 ** 18;
    }

    function assertInitParamsEq(L2Reward reward) internal view {
        assertEq(reward.OFFSET(), 150);
        assertEq(reward.REWARD_DURATION(), 30);
        assertEq(reward.REWARD_DURATION_DELAY(), 1);
        assertEq(reward.l2TokenContract(), address(l2LiskToken));
        assertEq(reward.lockingPositionContract(), address(l2LockingPosition));
        assertEq(reward.stakingContract(), address(l2Staking));
    }

    function setUp() public {
        skip(deploymentDate * 1 days);

        bridge = vm.addr(uint256(bytes32("bridge")));
        remoteToken = vm.addr(uint256(bytes32("remoteToken")));

        vm.prank(address(this), address(this));

        l2LiskToken = new L2LiskToken(remoteToken);
        l2LiskToken.initialize(bridge);

        vm.stopPrank();

        l2StakingImplementation = new L2Staking();
        l2Staking = L2Staking(
            address(
                new ERC1967Proxy(
                    address(l2StakingImplementation),
                    abi.encodeWithSelector(l2Staking.initialize.selector, address(l2LiskToken))
                )
            )
        );

        l2LockingPositionImplementation = new L2LockingPosition();
        l2LockingPosition = L2LockingPosition(
            address(
                new ERC1967Proxy(
                    address(l2LockingPositionImplementation),
                    abi.encodeWithSelector(l2LockingPosition.initialize.selector, address(l2Staking))
                )
            )
        );

        l2VotingPowerImplementation = new L2VotingPower();
        l2VotingPower = L2VotingPower(
            address(
                new ERC1967Proxy(
                    address(l2VotingPowerImplementation),
                    abi.encodeWithSelector(l2VotingPower.initialize.selector, address(l2LockingPosition))
                )
            )
        );

        l2Staking.initializeLockingPosition(address(l2LockingPosition));
        l2LockingPosition.initializeVotingPower(address(l2VotingPower));

        l2RewardImplementation = new L2Reward();

        vm.expectEmit(true, true, true, true);
        emit L2Staking.LiskTokenContractAddressChanged(address(0x0), address(l2LiskToken));

        l2Reward = L2Reward(
            address(
                new ERC1967Proxy(
                    address(l2RewardImplementation),
                    abi.encodeWithSelector(l2Reward.initialize.selector, address(l2LiskToken))
                )
            )
        );

        l2Reward.initializeLockingPosition(address(l2LockingPosition));

        vm.expectEmit(true, true, true, true);
        emit L2Reward.StakingContractAddressChanged(address(0x0), address(l2Staking));
        l2Reward.initializeStaking(address(l2Staking));

        assertInitParamsEq(l2Reward);

        l2Staking.addCreator(address(l2Reward));

        vm.startPrank(bridge);
        l2LiskToken.mint(staker, convertLiskToSmallestDenomination(100));
        vm.stopPrank();

        // create a position to have it for testing different function calls inside Reward contract
        vm.startPrank(staker);
        l2LiskToken.approve(address(l2Reward), convertLiskToSmallestDenomination(100));
        ID = l2Reward.createPosition(convertLiskToSmallestDenomination(100), 150);
        vm.stopPrank();

        stakerPositions = new uint256[](1);
        stakerPositions[0] = ID;

        upgradeLockingPositionContractToPausedVersion();

        // deploy L2RewardPaused contract
        L2RewardPaused l2RewardPaused = new L2RewardPaused();

        // upgrade Reward contract to L2RewardPaused contract
        l2Reward.upgradeToAndCall(
            address(l2RewardPaused), abi.encodeWithSelector(l2RewardPaused.initializePaused.selector)
        );

        // wrap L2Reward Proxy with new contract
        l2RewardPausedProxy = L2RewardPaused(address(l2Reward));

        // Check that state variables are unchanged
        assertInitParamsEq(l2RewardPausedProxy);

        // version was updated
        assertEq(l2RewardPausedProxy.version(), "1.0.0-paused");

        vm.startPrank(bridge);
        l2LiskToken.mint(staker, convertLiskToSmallestDenomination(100));
        vm.stopPrank();

        // approve L2Reward contract to spend funds
        vm.prank(address(staker));
        l2LiskToken.approve(address(l2RewardPausedProxy), convertLiskToSmallestDenomination(100));

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2RewardPausedProxy.initializePaused();
    }

    function test_CreatePosition_Paused() public {
        vm.expectRevert(L2RewardPaused.RewardIsPaused.selector);
        vm.prank(address(staker));
        l2RewardPausedProxy.createPosition(convertLiskToSmallestDenomination(100), 120);
    }

    function test_DeletePositions_Paused() public {
        skip(150 days);
        vm.expectRevert(L2RewardPaused.RewardIsPaused.selector);
        vm.prank(address(staker));
        l2RewardPausedProxy.deletePositions(stakerPositions);
    }

    function test_InitiateFastUnlock_Paused() public {
        skip(100 days);

        vm.expectRevert(L2RewardPaused.RewardIsPaused.selector);
        vm.prank(address(staker));
        l2RewardPausedProxy.initiateFastUnlock(stakerPositions);
    }

    function test_ClaimRewards_Paused() public {
        vm.expectRevert(L2RewardPaused.RewardIsPaused.selector);
        vm.prank(address(staker));
        l2RewardPausedProxy.claimRewards(stakerPositions);
    }

    function test_IncreaseLockingAmount_Paused() public {
        L2Reward.IncreasedAmount[] memory increasingAmounts = new L2Reward.IncreasedAmount[](1);
        increasingAmounts[0].lockID = ID;
        increasingAmounts[0].amountIncrease = convertLiskToSmallestDenomination(10);
        vm.expectRevert(L2RewardPaused.RewardIsPaused.selector);
        vm.prank(address(staker));
        l2RewardPausedProxy.increaseLockingAmount(increasingAmounts);
    }

    function test_ExtendDuration_Paused() public {
        L2Reward.ExtendedDuration[] memory extensions = new L2Reward.ExtendedDuration[](1);
        extensions[0].lockID = ID;
        extensions[0].durationExtension = 10;
        vm.expectRevert(L2RewardPaused.RewardIsPaused.selector);
        vm.prank(address(staker));
        l2RewardPausedProxy.extendDuration(extensions);
    }

    function test_PauseUnlocking_Paused() public {
        vm.expectRevert(L2RewardPaused.RewardIsPaused.selector);
        vm.prank(address(staker));
        l2RewardPausedProxy.pauseUnlocking(stakerPositions);
    }

    function test_ResumeUnlockingCountdown_Paused() public {
        vm.expectRevert(L2RewardPaused.RewardIsPaused.selector);
        vm.prank(address(staker));
        l2RewardPausedProxy.resumeUnlockingCountdown(stakerPositions);
    }

    function test_UpgradeToAndCall_CanUpgradeFromPausedContractToNewContract() public {
        L2RewardV2 l2RewardV2Implementation = new L2RewardV2();

        uint256 testNumber = 123;

        // upgrade Reward contract to L2RewardV2 contract
        l2Reward.upgradeToAndCall(
            address(l2RewardV2Implementation),
            abi.encodeWithSelector(l2RewardV2Implementation.initializeV2.selector, testNumber)
        );

        // wrap L2Reward Proxy with new contract
        L2RewardV2 l2RewardV2 = L2RewardV2(address(l2Reward));

        // Check that state variables are unchanged
        assertInitParamsEq(l2RewardV2);

        // version was updated
        assertEq(l2RewardV2.version(), "2.0.0");

        // testNumber variable introduced
        assertEq(l2RewardV2.testNumber(), testNumber);

        // new function introduced
        assertEq(l2RewardV2.onlyV2(), "Only L2RewardV2 have this function");

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2RewardV2.initializeV2(testNumber + 1);
    }
}
