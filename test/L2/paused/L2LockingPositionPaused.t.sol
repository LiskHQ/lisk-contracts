// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test, console2 } from "forge-std/Test.sol";
import { L2LockingPosition } from "src/L2/L2LockingPosition.sol";
import { L2LockingPositionPaused } from "src/L2/paused/L2LockingPositionPaused.sol";
import { L2Staking } from "src/L2/L2Staking.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";

contract L2LockingPositionV2 is L2LockingPosition {
    uint256 public testNumber;

    function initializeV2(uint256 _testNumber) public reinitializer(3) {
        testNumber = _testNumber;
    }

    function onlyV2() public pure returns (string memory) {
        return "Only L2LockingPositionV2 have this function";
    }
}

contract L2LockingPositionPausedTest is Test {
    L2Staking public l2Staking;
    L2Staking public l2StakingImplementation;
    L2VotingPower public l2VotingPower;
    L2VotingPower public l2VotingPowerImplementation;
    L2LockingPosition public l2LockingPosition;
    L2LockingPosition public l2LockingPositionImplementation;
    L2LockingPositionPaused public l2LockingPositionPausedProxy;

    function assertInitParamsEq(L2LockingPosition lockingPosition) internal view {
        assertEq(lockingPosition.name(), "Lisk Locking Position");
        assertEq(lockingPosition.symbol(), "LLP");
        assertEq(lockingPosition.owner(), address(this));
        assertEq(lockingPosition.stakingContract(), address(l2Staking));
        assertEq(lockingPosition.votingPowerContract(), address(l2VotingPower));
        assertEq(lockingPosition.totalSupply(), 0);
    }

    function setUp() public {
        // deploy L2Staking implementation contract
        l2StakingImplementation = new L2Staking();

        // deploy L2Staking contract via proxy and initialize it at the same time
        l2Staking = L2Staking(
            address(
                new ERC1967Proxy(
                    address(l2StakingImplementation),
                    abi.encodeWithSelector(
                        l2Staking.initialize.selector, address(0xbABEBABEBabeBAbEBaBeBabeBABEBabEBAbeBAbe)
                    )
                )
            )
        );
        assert(address(l2Staking) != address(0x0));

        // deploy L2LockingPosition implementation contract
        l2LockingPositionImplementation = new L2LockingPosition();

        // check that the StakingContractAddressChanged event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2LockingPosition.StakingContractAddressChanged(address(0), address(l2Staking));

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

        // initialize LockingPosition contract inside L2Staking contract
        l2Staking.initializeLockingPosition(address(l2LockingPosition));
        assert(l2Staking.lockingPositionContract() == address(l2LockingPosition));

        // initialize Lisk DAO Treasury contract inside L2Staking contract
        l2Staking.initializeDaoTreasury(address(0xbABEBABEBabeBAbEBaBeBabeBABEBabEBAbeBAbe));
        assert(l2Staking.daoTreasury() == address(0xbABEBABEBabeBAbEBaBeBabeBABEBabEBAbeBAbe));

        // initialize VotingPower contract inside L2LockingPosition contract
        // check that the VotingPowerContractAddressChanged event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2LockingPosition.VotingPowerContractAddressChanged(address(0), address(l2VotingPower));
        l2LockingPosition.initializeVotingPower(address(l2VotingPower));
        assert(l2LockingPosition.votingPowerContract() == address(l2VotingPower));

        assertInitParamsEq(l2LockingPosition);

        // deploy L2LockingPositionPaused contract
        L2LockingPositionPaused l2LockingPositionPaused = new L2LockingPositionPaused();

        // upgrade LockingPosition contract to L2LockingPositionPaused contract
        l2LockingPosition.upgradeToAndCall(
            address(l2LockingPositionPaused), abi.encodeWithSelector(l2LockingPositionPaused.initializePaused.selector)
        );

        // wrap L2LockingPosition Proxy with new contract
        l2LockingPositionPausedProxy = L2LockingPositionPaused(address(l2LockingPosition));

        // Check that state variables are unchanged
        assertInitParamsEq(l2LockingPositionPausedProxy);

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2LockingPositionPausedProxy.initializePaused();
    }

    function test_TransferFrom_Paused() public {
        vm.expectRevert(L2LockingPositionPaused.LockingPositionIsPaused.selector);
        vm.prank(address(l2Staking));
        l2LockingPositionPausedProxy.transferFrom(address(0), address(0), 0);
    }

    function test_CreateLockingPosition_Paused() public {
        vm.expectRevert(L2LockingPositionPaused.LockingPositionIsPaused.selector);
        vm.prank(address(l2Staking));
        l2LockingPositionPausedProxy.createLockingPosition(address(0), address(0), 0, 0);
    }

    function test_ModifyLockingPosition_Paused() public {
        vm.expectRevert(L2LockingPositionPaused.LockingPositionIsPaused.selector);
        vm.prank(address(l2Staking));
        l2LockingPositionPausedProxy.modifyLockingPosition(0, 0, 0, 0);
    }

    function test_RemoveLockingPosition_Paused() public {
        vm.expectRevert(L2LockingPositionPaused.LockingPositionIsPaused.selector);
        vm.prank(address(l2Staking));
        l2LockingPositionPausedProxy.removeLockingPosition(0);
    }

    function test_UpgradeToAndCall_CanUpgradeFromPausedContractToNewContract() public {
        L2LockingPositionV2 l2LockingPositionV2Implementation = new L2LockingPositionV2();

        uint256 testNumber = 123;

        // upgrade LockingPosition contract to L2LockingPositionV2 contract
        l2LockingPosition.upgradeToAndCall(
            address(l2LockingPositionV2Implementation),
            abi.encodeWithSelector(l2LockingPositionV2Implementation.initializeV2.selector, testNumber)
        );

        // wrap L2LockingPosition Proxy with new contract
        L2LockingPositionV2 l2LockingPositionV2 = L2LockingPositionV2(address(l2LockingPosition));

        // Check that state variables are unchanged
        assertInitParamsEq(l2LockingPositionV2);

        // testNumber variable introduced
        assertEq(l2LockingPositionV2.testNumber(), testNumber);

        // new function introduced
        assertEq(l2LockingPositionV2.onlyV2(), "Only L2LockingPositionV2 have this function");

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2LockingPositionV2.initializeV2(testNumber + 1);
    }
}
