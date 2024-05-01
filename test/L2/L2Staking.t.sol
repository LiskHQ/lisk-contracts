// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { Test, console2 } from "forge-std/Test.sol";
import { L2LockingPosition } from "src/L2/L2LockingPosition.sol";
import { IL2LockingPosition } from "src/interfaces/L2/IL2LockingPosition.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { L2Staking } from "src/L2/L2Staking.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";

contract L2StakingHarness is L2Staking {
    function exposedCalculatePenalty(uint256 amount, uint256 expDate) public view returns (uint256) {
        return calculatePenalty(amount, expDate);
    }

    function exposedCanLockingPositionBeModified(
        uint256 lockId,
        IL2LockingPosition.LockingPosition memory lock
    )
        public
        view
        returns (bool)
    {
        return canLockingPositionBeModified(lockId, lock);
    }

    function exposedRemainingLockingDuration(IL2LockingPosition.LockingPosition memory lock)
        public
        view
        returns (uint256)
    {
        return remainingLockingDuration(lock);
    }
}

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

    address daoTreasuryAddress;

    address rewardsContract;
    address alice;

    function prepareL2StakingHarnessContract() private returns (L2StakingHarness) {
        L2StakingHarness l2StakingImplementationHarness = new L2StakingHarness();
        L2StakingHarness l2StakingHarness =
            L2StakingHarness(address(new ERC1967Proxy(address(l2StakingImplementationHarness), "")));

        vm.prank(address(this), address(this));
        l2LiskToken = new L2LiskToken(remoteToken);
        l2LiskToken.initialize(bridge);
        vm.stopPrank();
        l2VotingPowerImplementation = new L2VotingPower();
        l2VotingPower = L2VotingPower(address(new ERC1967Proxy(address(l2VotingPowerImplementation), "")));
        l2LockingPositionImplementation = new L2LockingPosition();
        l2LockingPosition = L2LockingPosition(address(new ERC1967Proxy(address(l2LockingPositionImplementation), "")));

        l2StakingHarness.initialize(address(l2LiskToken));
        l2VotingPower.initialize(address(l2LockingPosition));
        l2LockingPosition.initialize(address(l2StakingHarness));

        l2LockingPosition.initializeVotingPower(address(l2VotingPower));
        l2StakingHarness.initializeLockingPosition(address(l2LockingPosition));
        l2StakingHarness.initializeDaoTreasury(daoTreasuryAddress);

        // add rewardsContract to the creator list
        l2StakingHarness.addCreator(rewardsContract);
        assert(l2StakingHarness.allowedCreators(rewardsContract));

        // fund alice with 200 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(alice, 200 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 200 * 10 ** 18);

        // approve l2StakingHarness to spend alice's 200 L2LiskToken
        vm.prank(alice);
        l2LiskToken.approve(address(l2StakingHarness), 200 * 10 ** 18);
        assertEq(l2LiskToken.allowance(alice, address(l2StakingHarness)), 200 * 10 ** 18);

        // fund rewardsContract with 200 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(rewardsContract, 200 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(rewardsContract), 200 * 10 ** 18);

        // approve l2StakingHarness to spend rewardsContract's 200 L2LiskToken
        vm.prank(rewardsContract);
        l2LiskToken.approve(address(l2StakingHarness), 200 * 10 ** 18);

        return l2StakingHarness;
    }

    function setUp() public {
        daoTreasuryAddress = address(0xDeaDbeefdEAdbeefdEadbEEFdeadbeEFdEaDbeeF);

        rewardsContract = address(0x1);
        alice = address(0x2);

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

        // check that the LiskTokenContractAddressChanged event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Staking.LiskTokenContractAddressChanged(address(0), address(l2LiskToken));

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
        assertEq(l2Staking.emergencyExitEnabled(), false);

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
        // check that the LockingPositionContractAddressChanged event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Staking.LockingPositionContractAddressChanged(address(0), address(l2LockingPosition));
        l2Staking.initializeLockingPosition(address(l2LockingPosition));
        assert(l2Staking.lockingPositionContract() == address(l2LockingPosition));

        // initialize Lisk DAO Treasury contract inside L2Staking contract
        // check that the DaoTreasuryAddressChanged event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Staking.DaoTreasuryAddressChanged(address(0), daoTreasuryAddress);
        l2Staking.initializeDaoTreasury(daoTreasuryAddress);
        assert(l2Staking.daoTreasury() == daoTreasuryAddress);

        // add rewardsContract to the creator list
        l2Staking.addCreator(rewardsContract);
        assert(l2Staking.allowedCreators(rewardsContract));

        // fund alice with 100 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(alice, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);

        // approve L2Staking to spend alice's 100 L2LiskToken
        vm.prank(alice);
        l2LiskToken.approve(address(l2Staking), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(alice, address(l2Staking)), 100 * 10 ** 18);

        // fund rewardsContract with 100 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(rewardsContract, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(rewardsContract), 100 * 10 ** 18);

        // approve L2Staking to spend rewardsContract's 100 L2LiskToken
        vm.prank(rewardsContract);
        l2LiskToken.approve(address(l2Staking), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(rewardsContract, address(l2Staking)), 100 * 10 ** 18);
    }

    function test_CanLockingPositionBeModified_CreatorIsStakingContract() public {
        L2StakingHarness l2StakingHarness = prepareL2StakingHarnessContract();

        vm.prank(alice);
        l2StakingHarness.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2StakingHarness));

        IL2LockingPosition.LockingPosition memory lock = l2LockingPosition.getLockingPosition(1);

        // call the function as owner
        vm.prank(alice);
        assertEq(l2StakingHarness.exposedCanLockingPositionBeModified(1, lock), true);

        // call the function as creator (staking contract) which is not inside the allowedCreators list
        vm.prank(address(l2StakingHarness));
        assertEq(l2StakingHarness.exposedCanLockingPositionBeModified(1, lock), false);

        // call the function as not owner or creator
        vm.prank(address(0x3));
        assertEq(l2StakingHarness.exposedCanLockingPositionBeModified(1, lock), false);
    }

    function test_CanLockingPositionBeModified_CreatorIsRewardsContract() public {
        L2StakingHarness l2StakingHarness = prepareL2StakingHarnessContract();

        vm.prank(rewardsContract);
        l2StakingHarness.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, rewardsContract);

        IL2LockingPosition.LockingPosition memory lock = l2LockingPosition.getLockingPosition(1);

        // call the function as owner
        vm.prank(alice);
        assertEq(l2StakingHarness.exposedCanLockingPositionBeModified(1, lock), false); // alice can not directly call
            // the function

        // call the function as creator
        vm.prank(rewardsContract);
        assertEq(l2StakingHarness.exposedCanLockingPositionBeModified(1, lock), true);
    }

    function test_CalculatePenalty() public {
        L2StakingHarness l2StakingHarness = new L2StakingHarness();

        uint256 remainingDuration = 365;
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, remainingDuration), 25000000000000000000);

        remainingDuration -= 50;
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, remainingDuration), 21575342465753424657);

        remainingDuration -= 50;
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, remainingDuration), 18150684931506849315);

        remainingDuration -= 50;
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, remainingDuration), 14726027397260273972);

        remainingDuration -= 50;
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, remainingDuration), 11301369863013698630);

        remainingDuration -= 50;
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, remainingDuration), 7876712328767123287);

        remainingDuration -= 50;
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, remainingDuration), 4452054794520547945);

        remainingDuration -= 50;
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, remainingDuration), 1027397260273972602);

        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, 0), 0);
    }

    function test_CalculatePenalty_EmergencyExitEnabled() public {
        L2StakingHarness l2StakingHarness = new L2StakingHarness();

        // enable emergency exit
        vm.prank(l2StakingHarness.owner());
        l2StakingHarness.setEmergencyExitEnabled(true);
        assert(l2StakingHarness.emergencyExitEnabled());

        uint256 remainingDuration = 365;
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, remainingDuration), 0);

        remainingDuration -= 100;
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, remainingDuration), 0);

        remainingDuration -= 100;
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, remainingDuration), 0);

        remainingDuration -= 100;
        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, remainingDuration), 0);

        assertEq(l2StakingHarness.exposedCalculatePenalty(100 * 10 ** 18, 0), 0);
    }

    function test_RemainingLockingDuration_ZeroPausedLockingDuration() public {
        L2StakingHarness l2StakingHarness = new L2StakingHarness();

        // create a locking position with pausedLockingDuration set to zero
        IL2LockingPosition.LockingPosition memory lock = IL2LockingPosition.LockingPosition({
            creator: address(0x1),
            amount: 100 * 10 ** 18,
            expDate: 365,
            pausedLockingDuration: 0
        });
        assertEq(lock.pausedLockingDuration, 0);

        // same day
        assertEq(l2StakingHarness.exposedRemainingLockingDuration(lock), 365);

        // advance block time by 100 days
        vm.warp(100 days);
        assertEq(l2StakingHarness.exposedRemainingLockingDuration(lock), 265);
    }

    function test_RemainingLockingDuration_PausedLockingDurationNotZero() public {
        L2StakingHarness l2StakingHarness = new L2StakingHarness();

        // create a locking position with pausedLockingDuration set to 100
        IL2LockingPosition.LockingPosition memory lock = IL2LockingPosition.LockingPosition({
            creator: address(0x1),
            amount: 100 * 10 ** 18,
            expDate: 365,
            pausedLockingDuration: 100
        });
        assertEq(lock.pausedLockingDuration, 100);

        // same day
        assertEq(l2StakingHarness.exposedRemainingLockingDuration(lock), 100);

        // advance block time by 150 days
        vm.warp(150 days);
        assertEq(l2StakingHarness.exposedRemainingLockingDuration(lock), 100);
    }

    function test_RemainingLockingDuration_ExpirationDayAlreadyExpired() public {
        L2StakingHarness l2StakingHarness = new L2StakingHarness();

        // create a locking position with expDate set to 365
        IL2LockingPosition.LockingPosition memory lock = IL2LockingPosition.LockingPosition({
            creator: address(0x1),
            amount: 100 * 10 ** 18,
            expDate: 365,
            pausedLockingDuration: 0
        });
        assertEq(lock.expDate, 365);

        // advance block time to exactly one day before the expiration date
        vm.warp(364 days);
        assertEq(l2StakingHarness.exposedRemainingLockingDuration(lock), 1);

        // advance block time to exactly the expiration date
        vm.warp(365 days);
        assertEq(l2StakingHarness.exposedRemainingLockingDuration(lock), 0);

        // advance block time to exactly one day after the expiration date
        vm.warp(366 days);
        assertEq(l2StakingHarness.exposedRemainingLockingDuration(lock), 0);
    }

    function test_InitializeLockingPosition_LockingPositionContractAlreadyInitialized() public {
        vm.expectRevert("L2Staking: Locking Position contract is already initialized");
        l2Staking.initializeLockingPosition(address(l2LockingPosition));
    }

    function test_InitializeLockingPosition_NotCalledByOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        l2Staking.initializeLockingPosition(address(l2LockingPosition));
    }

    function test_InitializeLockingPosition_ZeroLockingPositionContractAddress() public {
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

        vm.expectRevert("L2Staking: Locking Position contract address can not be zero");
        l2Staking.initializeLockingPosition(address(0x0));
    }

    function test_initializeDaoTreasury_DaoTreasuryAlreadyInitialized() public {
        vm.expectRevert("L2Staking: Lisk DAO Treasury contract is already initialized");
        l2Staking.initializeDaoTreasury(daoTreasuryAddress);
    }

    function test_initializeDaoTreasury_NotCalledByOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        l2Staking.initializeDaoTreasury(daoTreasuryAddress);
    }

    function test_initializeDaoTreasury_ZeroDaoTreasuryAddress() public {
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

        vm.expectRevert("L2Staking: Lisk DAO Treasury contract address can not be zero");
        l2Staking.initializeDaoTreasury(address(0x0));
    }

    function test_AddCreator() public {
        assert(!l2Staking.allowedCreators(alice));

        // check that the AllowedCreatorAdded event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Staking.AllowedCreatorAdded(alice);
        l2Staking.addCreator(alice);
        assert(l2Staking.allowedCreators(alice));
    }

    function test_AddCreator_ZeroCreatorAddress() public {
        vm.expectRevert("L2Staking: creator address can not be zero");
        l2Staking.addCreator(address(0x0));
    }

    function test_AddCreator_OnlyOwnerCanCall() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        l2Staking.addCreator(alice);
    }

    function test_AddCreator_PreventAddingStakingContractAsCreator() public {
        vm.expectRevert("L2Staking: Staking contract can not be added as a creator");
        l2Staking.addCreator(address(l2Staking));
    }

    function test_RemoveCreator() public {
        l2Staking.addCreator(alice);
        assert(l2Staking.allowedCreators(alice));

        // check that the AllowedCreatorRemoved event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Staking.AllowedCreatorRemoved(alice);
        l2Staking.removeCreator(alice);
        assert(!l2Staking.allowedCreators(alice));
    }

    function test_RemoveCreator_ZeroCreatorAddress() public {
        vm.expectRevert("L2Staking: creator address can not be zero");
        l2Staking.removeCreator(address(0x0));
    }

    function test_RemoveCreator_OnlyOwnerCanCall() public {
        l2Staking.addCreator(alice);
        assert(l2Staking.allowedCreators(alice));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        l2Staking.removeCreator(alice);
    }

    function test_SetEmergencyExitEnabled() public {
        assert(!l2Staking.emergencyExitEnabled());

        // check that the EmergencyExitEnabledChanged event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Staking.EmergencyExitEnabledChanged(false, true);
        l2Staking.setEmergencyExitEnabled(true);
        assert(l2Staking.emergencyExitEnabled());

        // check that the EmergencyExitEnabledChanged event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Staking.EmergencyExitEnabledChanged(true, false);
        l2Staking.setEmergencyExitEnabled(false);
        assert(!l2Staking.emergencyExitEnabled());
    }

    function test_SetEmergencyExitEnabled_OnlyOwnerCanCall() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, alice));
        l2Staking.setEmergencyExitEnabled(true);
    }

    function test_LockAmount() public {
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2VotingPower.totalSupply(), 0);

        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);
    }

    function test_LockAmount_ZeroLockOwnerAddress() public {
        vm.prank(address(0x0));
        vm.expectRevert("L2Staking: lockOwner address can not be zero");
        l2Staking.lockAmount(address(0x0), 100 * 10 ** 18, 365);
    }

    function test_LockAmount_MinAmount() public {
        uint256 minAmount = l2Staking.MIN_LOCKING_AMOUNT();

        // amount is less than MIN_LOCKING_AMOUNT
        vm.prank(alice);
        vm.expectRevert(
            bytes(string.concat("L2Staking: amount should be greater than or equal to ", vm.toString(minAmount)))
        );
        l2Staking.lockAmount(alice, minAmount - 1, 365);

        // amount is exactly MIN_LOCKING_AMOUNT
        vm.prank(alice);
        l2Staking.lockAmount(alice, minAmount, 365);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, minAmount);

        // amount is greater than MIN_LOCKING_AMOUNT
        vm.prank(alice);
        l2Staking.lockAmount(alice, minAmount + 1, 365);
        assertEq(l2LockingPosition.totalSupply(), 2);
        assertEq(l2LockingPosition.balanceOf(alice), 2);
        assertEq(l2LockingPosition.getLockingPosition(2).amount, minAmount + 1);
    }

    function test_LockAmount_CreatorNotStakingContract() public {
        // execute the lockAmount function from a contract that is not the staking contract but is in the
        // allowedCreators list
        vm.prank(rewardsContract);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);

        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18); // alice didn't call lockAmount
        assertEq(l2LiskToken.balanceOf(rewardsContract), 0);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, rewardsContract);
    }

    function test_LockAmount_OwnerDifferentThanMessageSender() public {
        address bob = address(0x3);

        // fund bob with 30 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(bob, 30 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(bob), 30 * 10 ** 18);

        // execute the lockAmount function directly from the staking contract as alice but with the owner being bob
        vm.prank(alice);
        vm.expectRevert("L2Staking: owner different than message sender, can not create locking position");
        l2Staking.lockAmount(bob, 30 * 10 ** 18, 365);
    }

    function test_LockAmount_DurationIsExactlyMinOrMaxDuration() public {
        // minimum duration
        uint256 validDuration = l2Staking.MIN_LOCKING_DURATION();
        vm.prank(alice);
        l2Staking.lockAmount(alice, 30 * 10 ** 18, validDuration);

        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 30 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, validDuration);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        // maximum duration
        validDuration = l2Staking.MAX_LOCKING_DURATION();
        vm.prank(alice);
        l2Staking.lockAmount(alice, 50 * 10 ** 18, validDuration);

        assertEq(l2LockingPosition.getLockingPosition(2).creator, address(l2Staking));
        assertEq(l2LockingPosition.getLockingPosition(2).amount, 50 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(2).expDate, validDuration);
        assertEq(l2LockingPosition.getLockingPosition(2).pausedLockingDuration, 0);
    }

    function test_LockAmount_DurationIsLessThanMinDuration() public {
        uint256 invalidDuration = l2Staking.MIN_LOCKING_DURATION() - 1;
        vm.prank(alice);
        vm.expectRevert("L2Staking: lockingDuration should be at least MIN_LOCKING_DURATION");
        l2Staking.lockAmount(alice, 100 * 10 ** 18, invalidDuration);
    }

    function test_LockAmount_DurationIsMoreThanMaxDuration() public {
        uint256 invalidDuration = l2Staking.MAX_LOCKING_DURATION() + 1;
        vm.prank(alice);
        vm.expectRevert("L2Staking: lockingDuration can not be greater than MAX_LOCKING_DURATION");
        l2Staking.lockAmount(alice, 100 * 10 ** 18, invalidDuration);
    }

    function test_LockAmount_InsufficientUserBalance() public {
        uint256 aliceBalance = l2LiskToken.balanceOf(alice);
        uint256 invalidAmount = aliceBalance + l2Staking.MIN_LOCKING_AMOUNT();

        // approve l2Staking to spend invalidAmount of alice's L2LiskToken
        vm.prank(alice);
        l2LiskToken.approve(address(l2Staking), invalidAmount);
        assertEq(l2LiskToken.allowance(alice, address(l2Staking)), invalidAmount);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, aliceBalance, invalidAmount)
        );
        l2Staking.lockAmount(alice, invalidAmount, 365);
    }

    function test_LockAmount_InsufficientUserAllowance() public {
        uint256 aliceAllowance = l2LiskToken.allowance(alice, address(l2Staking));
        uint256 invalidAmount = aliceAllowance + l2Staking.MIN_LOCKING_AMOUNT();

        // alice didn't approve l2Staking to spend invalidAmount of alice's L2LiskToken
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, l2Staking, aliceAllowance, invalidAmount
            )
        );
        l2Staking.lockAmount(alice, invalidAmount, 365);
    }

    function test_Unlock() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 365 days
        vm.warp(365 days);

        vm.prank(alice);
        l2Staking.unlock(1);

        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 0);

        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);

        assertEq(l2VotingPower.totalSupply(), 0);
        assertEq(l2VotingPower.balanceOf(alice), 0);
    }

    function test_Unlock_SenderIsAllowedCreator() public {
        vm.prank(rewardsContract);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18); // alice didn't call lockAmount
        assertEq(l2LiskToken.balanceOf(rewardsContract), 0); // rewardsContract call lockAmount
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 365 days
        vm.warp(365 days);

        vm.prank(rewardsContract);
        l2Staking.unlock(1);

        assertEq(l2LiskToken.balanceOf(alice), 200 * 10 ** 18); // alice received additional 100 L2LiskToken
        assertEq(l2LiskToken.balanceOf(rewardsContract), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 0);

        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);

        assertEq(l2VotingPower.totalSupply(), 0);
        assertEq(l2VotingPower.balanceOf(alice), 0);
    }

    function test_Unlock_LockingPositionIsPaused() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // pause the remaining locking duration
        vm.prank(alice);
        l2Staking.pauseRemainingLockingDuration(1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 365);

        // advance block time by 365 + 1 days
        vm.warp(366 days);

        vm.prank(alice);
        vm.expectRevert("L2Staking: locking duration active, can not unlock");
        l2Staking.unlock(1);

        // resume the countdown
        vm.prank(alice);
        l2Staking.resumeCountdown(1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        // advance block time by additional 365 days
        vm.warp(366 days + 365 days);

        vm.prank(alice);
        l2Staking.unlock(1);

        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 0);

        assertEq(l2LockingPosition.totalSupply(), 0);
        assertEq(l2LockingPosition.balanceOf(alice), 0);

        assertEq(l2VotingPower.totalSupply(), 0);
        assertEq(l2VotingPower.balanceOf(alice), 0);
    }

    function test_Unlock_StakeDidNotExpire() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 364 days
        vm.warp(364 days);

        vm.prank(alice);
        vm.expectRevert("L2Staking: locking duration active, can not unlock");
        l2Staking.unlock(1);
    }

    function test_Unlock_InvalidLockingPositionId() public {
        vm.prank(alice);
        vm.expectRevert("L2Staking: locking position does not exist");
        l2Staking.unlock(1);
    }

    function test_Unlock_NotCreator() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));

        // address is inside the allowedCreators list but is not the creator of the locking position
        vm.prank(rewardsContract);
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.unlock(1);

        // address is not inside the allowedCreators list and is not the creator of the locking position
        vm.prank(address(0x3));
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.unlock(1);
    }

    function test_InitiateFastUnlock() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(daoTreasuryAddress), 0);
        assertEq(l2LiskToken.balanceOf(rewardsContract), 100 * 10 ** 18); // rewardsContract didn't call lockAmount
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(alice);
        uint256 penalty = l2Staking.initiateFastUnlock(1);
        assertEq(penalty, 18150684931506849315);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        // penalty is sent to the Lisk DAO Treasury contract
        assertEq(l2LiskToken.balanceOf(daoTreasuryAddress), 18150684931506849315);
        assertEq(l2LiskToken.balanceOf(rewardsContract), 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18 - 18150684931506849315);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18 - 18150684931506849315); // 100 LSK
            // tokens - penalty
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 103); // 100 + 3 days
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 81849315068493150685);
        assertEq(l2VotingPower.balanceOf(alice), 81849315068493150685);
    }

    function test_InitiateFastUnlock_PausedLockingPosition() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(daoTreasuryAddress), 0);
        assertEq(l2LiskToken.balanceOf(rewardsContract), 100 * 10 ** 18); // rewardsContract didn't call lockAmount
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 100 days
        vm.warp(100 days);

        // pause the locking position
        vm.prank(alice);
        l2Staking.pauseRemainingLockingDuration(1);

        // advance block time by additional 30 days
        vm.warp(130 days);

        vm.prank(alice);
        uint256 penalty = l2Staking.initiateFastUnlock(1);
        assertEq(penalty, 18150684931506849315);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        // penalty is sent to the Lisk DAO Treasury contract
        assertEq(l2LiskToken.balanceOf(daoTreasuryAddress), 18150684931506849315);
        assertEq(l2LiskToken.balanceOf(rewardsContract), 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18 - 18150684931506849315);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18 - 18150684931506849315); // 100 LSK
            // tokens - penalty
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 133); // 130 + 3 days
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 81849315068493150685);
        assertEq(l2VotingPower.balanceOf(alice), 81849315068493150685);
    }

    function test_InitiateFastUnlock_LockingPositionExpiresInLessThanThreeDays() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(daoTreasuryAddress), 0);
        assertEq(l2LiskToken.balanceOf(rewardsContract), 100 * 10 ** 18); // rewardsContract didn't call lockAmount
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 363 days (2 days before the expiration date)
        vm.warp(363 days);

        vm.prank(alice);
        vm.expectRevert("L2Staking: less than 3 days until unlock");
        l2Staking.initiateFastUnlock(1);
    }

    function test_InitiateFastUnlock_CreatorNotStakingContract() public {
        vm.prank(rewardsContract);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18); // alice didn't call lockAmount
        assertEq(l2LiskToken.balanceOf(daoTreasuryAddress), 0);
        assertEq(l2LiskToken.balanceOf(rewardsContract), 0);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, rewardsContract);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(rewardsContract);
        uint256 penalty = l2Staking.initiateFastUnlock(1);
        assertEq(penalty, 18150684931506849315);

        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18); // alice didn't call lockAmount
        assertEq(l2LiskToken.balanceOf(daoTreasuryAddress), 0);
        // penalty is sent to the Rewards contract
        assertEq(l2LiskToken.balanceOf(address(rewardsContract)), 18150684931506849315);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18 - 18150684931506849315);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18 - 18150684931506849315); // 100 LSK
            // tokens - penalty
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 103); // 100 + 3 days
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 81849315068493150685);
        assertEq(l2VotingPower.balanceOf(alice), 81849315068493150685);
    }

    function test_InitiateFastUnlock_InvalidLockingPositionId() public {
        vm.prank(alice);
        vm.expectRevert("L2Staking: locking position does not exist");
        l2Staking.initiateFastUnlock(1);
    }

    function test_InitiateFastUnlock_NotCreator() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));

        // address is inside the allowedCreators list but is not the creator of the locking position
        vm.prank(rewardsContract);
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.initiateFastUnlock(1);

        // address is not inside the allowedCreators list and is not the creator of the locking position
        vm.prank(address(0x3));
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.initiateFastUnlock(1);
    }

    function test_IncreaseLockingAmount() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // fund alice with additional 100 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(alice, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);

        // approve L2Staking to spend alice's additional 100 L2LiskToken
        vm.prank(alice);
        l2LiskToken.approve(address(l2Staking), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(alice, address(l2Staking)), 100 * 10 ** 18);

        vm.prank(alice);
        l2Staking.increaseLockingAmount(1, 100 * 10 ** 18);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 200 * 10 ** 18);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 200 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 200 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 200 * 10 ** 18);
    }

    function test_IncreaseLockingAmount_PausedLockingDurationNotZero() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(alice);
        l2Staking.pauseRemainingLockingDuration(1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265);

        // fund alice with additional 100 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(alice, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);

        // approve L2Staking to spend alice's additional 100 L2LiskToken
        vm.prank(alice);
        l2LiskToken.approve(address(l2Staking), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(alice, address(l2Staking)), 100 * 10 ** 18);

        vm.prank(alice);
        l2Staking.increaseLockingAmount(1, 100 * 10 ** 18);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 200 * 10 ** 18);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 200 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265);

        assertEq(l2VotingPower.totalSupply(), 345205479452054794520);
        assertEq(l2VotingPower.balanceOf(alice), 345205479452054794520);
    }

    function test_IncreaseLockingAmount_InvalidLockingPositionId() public {
        vm.prank(alice);
        vm.expectRevert("L2Staking: locking position does not exist");
        l2Staking.increaseLockingAmount(1, 100 * 10 ** 18);
    }

    function test_IncreaseLockingAmount_NotCreator() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));

        // address is inside the allowedCreators list but is not the creator of the locking position
        vm.prank(rewardsContract);
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.increaseLockingAmount(1, 100 * 10 ** 18);

        // address is not inside the allowedCreators list and is not the creator of the locking position
        vm.prank(address(0x3));
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.increaseLockingAmount(1, 100 * 10 ** 18);
    }

    function test_IncreaseLockingAmount_ZeroAmountIncrease() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);

        vm.prank(alice);
        vm.expectRevert("L2Staking: increased amount should be greater than zero");
        l2Staking.increaseLockingAmount(1, 0);
    }

    function test_IncreaseLockingAmount_ExpiredLockingPosition() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);

        // advance block time by 365 days
        vm.warp(365 days);

        // position is already expired
        vm.prank(alice);
        vm.expectRevert("L2Staking: can not increase amount, less than minimum locking duration remaining");
        l2Staking.increaseLockingAmount(1, 100 * 10 ** 18);
    }

    function test_IncreaseLockingAmount_MinimumLockingDuration() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 50 * 10 ** 18, 365);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 50 * 10 ** 18);

        // advance block time that it will be exactly MIN_LOCKING_DURATION day left until unlock
        uint256 currentDay = 365 days - (l2Staking.MIN_LOCKING_DURATION() * 1 days);
        vm.warp(currentDay);

        // it is exactly MIN_LOCKING_DURATION days until unlock, so increasing amount is still allowed
        vm.prank(alice);
        l2Staking.increaseLockingAmount(1, 30 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 80 * 10 ** 18); // 50 + 30 LSK tokens
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);

        // advance block time for additional day so that it is less than MIN_LOCKING_DURATION days until unlock
        currentDay += 1 days;
        vm.warp(currentDay);

        // it is less than MIN_LOCKING_DURATION days until unlock
        vm.prank(alice);
        vm.expectRevert("L2Staking: can not increase amount, less than minimum locking duration remaining");
        l2Staking.increaseLockingAmount(1, 20 * 10 ** 18);

        // amount is still the same
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 80 * 10 ** 18); // still 50 + 30 LSK tokens
    }

    function test_IncreaseLockingAmount_ExpiredLockingPosition_PausedLockingDurationNotZero() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(alice);
        l2Staking.pauseRemainingLockingDuration(1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265);

        // advance block time by 365 days
        vm.warp(365 days);

        // fund alice with additional 100 L2LiskToken
        vm.prank(bridge);
        l2LiskToken.mint(alice, 100 * 10 ** 18);
        assertEq(l2LiskToken.balanceOf(alice), 100 * 10 ** 18);

        // approve L2Staking to spend alice's additional 100 L2LiskToken
        vm.prank(alice);
        l2LiskToken.approve(address(l2Staking), 100 * 10 ** 18);
        assertEq(l2LiskToken.allowance(alice, address(l2Staking)), 100 * 10 ** 18);

        // expDate is in the past, but there is still some remaining locking duration and its countdown is paused;
        // increasing amount is therefore allowed
        vm.prank(alice);
        l2Staking.increaseLockingAmount(1, 100 * 10 ** 18);

        assertEq(l2LockingPosition.getLockingPosition(1).amount, 200 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265);

        assertEq(l2VotingPower.totalSupply(), 345205479452054794520);
        assertEq(l2VotingPower.balanceOf(alice), 345205479452054794520);
    }

    function test_IncreaseLockingAmount_InsufficientUserBalance() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);

        uint256 aliceBalance = l2LiskToken.balanceOf(alice);
        uint256 invalidAmount = aliceBalance + l2Staking.MIN_LOCKING_AMOUNT();

        // approve l2Staking to spend invalidAmount of alice's L2LiskToken
        vm.prank(alice);
        l2LiskToken.approve(address(l2Staking), invalidAmount);
        assertEq(l2LiskToken.allowance(alice, address(l2Staking)), invalidAmount);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, alice, aliceBalance, invalidAmount)
        );
        l2Staking.increaseLockingAmount(1, invalidAmount);
    }

    function test_IncreaseLockingAmount_InsufficientUserAllowance() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);

        uint256 aliceAllowance = l2LiskToken.allowance(alice, address(l2Staking));
        uint256 invalidAmount = aliceAllowance + l2Staking.MIN_LOCKING_AMOUNT();

        // alice didn't approve l2Staking to spend invalidAmount of alice's L2LiskToken
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector, l2Staking, aliceAllowance, invalidAmount
            )
        );
        l2Staking.increaseLockingAmount(1, invalidAmount);
    }

    function test_ExtendLockingDuration_PausedLockingDurationIsZero() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 200 days so that the locking position is not yet expired
        vm.warp(200 days);

        vm.prank(alice);
        l2Staking.extendLockingDuration(1, 100);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 465); // 365 + 100 days
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);
    }

    function test_ExtendLockingDuration_PausedLockingDurationIsZero_PositionAlreadyExpired() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 500 days so that the locking position was already expired
        vm.warp(500 days);

        vm.prank(alice);
        l2Staking.extendLockingDuration(1, 100);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 600); // 500 + 100 days
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);
    }

    function test_ExtendLockingDuration_PausedLockingDurationNotZero() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);
        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(alice);
        l2Staking.pauseRemainingLockingDuration(1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265); // 365 - 100 days

        vm.prank(alice);
        l2Staking.extendLockingDuration(1, 50);

        assertEq(l2LiskToken.balanceOf(alice), 0);
        assertEq(l2LiskToken.balanceOf(address(l2Staking)), 100 * 10 ** 18);

        assertEq(l2LockingPosition.totalSupply(), 1);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 315); // 265 + 50 days
            // (pausedLockingDuration + extendDays)

        assertEq(l2VotingPower.totalSupply(), 186301369863013698630);
        assertEq(l2VotingPower.balanceOf(alice), 186301369863013698630);
    }

    function test_ExtendLockingDuration_InvalidLockingPositionId() public {
        vm.prank(alice);
        vm.expectRevert("L2Staking: locking position does not exist");
        l2Staking.extendLockingDuration(1, 100);
    }

    function test_ExtendLockingDuration_NotCreator() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));

        // address is inside the allowedCreators list but is not the creator of the locking position
        vm.prank(rewardsContract);
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.extendLockingDuration(1, 100);

        // address is not inside the allowedCreators list and is not the creator of the locking position
        vm.prank(address(0x3));
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.extendLockingDuration(1, 100);
    }

    function test_ExtendLockingDuration_ZeroExtendedDays() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);

        vm.prank(alice);
        vm.expectRevert("L2Staking: extendDays should be greater than zero");
        l2Staking.extendLockingDuration(1, 0);
    }

    function test_ExtendLockingDuration_DurationIsMoreThanMaxDuration() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);

        // On first day, the maximum extended duration is 365 days
        uint256 invalidExtendedDuration = 365 + 1;
        vm.prank(alice);
        vm.expectRevert("L2Staking: locking duration can not be extended to more than MAX_LOCKING_DURATION");
        l2Staking.extendLockingDuration(1, invalidExtendedDuration);

        // advance block time by 100 days
        vm.warp(100 days);

        // On 100th day, the maximum extended duration is 465 days (365 + 100 days)
        invalidExtendedDuration = 465 + 1;
        vm.prank(alice);
        vm.expectRevert("L2Staking: locking duration can not be extended to more than MAX_LOCKING_DURATION");
        l2Staking.extendLockingDuration(1, invalidExtendedDuration);
    }

    function test_PauseRemainingLockingDuration() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(alice);
        l2Staking.pauseRemainingLockingDuration(1);

        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265); // 365 - 100 days

        assertEq(l2VotingPower.totalSupply(), 172602739726027397260);
        assertEq(l2VotingPower.balanceOf(alice), 172602739726027397260);
    }

    function test_PauseRemainingLockingDuration_InvalidLockingPositionId() public {
        vm.prank(alice);
        vm.expectRevert("L2Staking: locking position does not exist");
        l2Staking.pauseRemainingLockingDuration(1);
    }

    function test_PauseRemainingLockingDuration_NotCreator() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));

        // address is inside the allowedCreators list but is not the creator of the locking position
        vm.prank(rewardsContract);
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.pauseRemainingLockingDuration(1);

        // address is not inside the allowedCreators list and is not the creator of the locking position
        vm.prank(address(0x3));
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.pauseRemainingLockingDuration(1);
    }

    function test_PauseRemainingLockingDuration_AlreadyPaused() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(alice);
        l2Staking.pauseRemainingLockingDuration(1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265); // 365 - 100 days

        vm.prank(alice);
        vm.expectRevert("L2Staking: remaining duration is already paused");
        l2Staking.pauseRemainingLockingDuration(1);
    }

    function test_PauseRemainingLockingDuration_ExpiredLockingPosition() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        // advance block time by 365 days so that the locking position is already expired
        vm.warp(365 days);

        vm.prank(alice);
        vm.expectRevert("L2Staking: locking period has ended");
        l2Staking.pauseRemainingLockingDuration(1);
    }

    function test_ResumeCountdown() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 365);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);
        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);

        // advance block time by 100 days
        vm.warp(100 days);

        vm.prank(alice);
        l2Staking.pauseRemainingLockingDuration(1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 265); // 365 - 100 days

        // advance block time by another 50 days
        vm.warp(150 days);

        vm.prank(alice);
        l2Staking.resumeCountdown(1);

        assertEq(l2LockingPosition.getLockingPosition(1).amount, 100 * 10 ** 18);
        assertEq(l2LockingPosition.getLockingPosition(1).expDate, 415); // 150 + 265 days (today + paused duration)
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        assertEq(l2VotingPower.totalSupply(), 100 * 10 ** 18);
        assertEq(l2VotingPower.balanceOf(alice), 100 * 10 ** 18);
    }

    function test_ResumeCountdown_InvalidLockingPositionId() public {
        vm.prank(alice);
        vm.expectRevert("L2Staking: locking position does not exist");
        l2Staking.resumeCountdown(1);
    }

    function test_ResumeCountdown_NotCreator() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).creator, address(l2Staking));

        // address is inside the allowedCreators list but is not the creator of the locking position
        vm.prank(rewardsContract);
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.resumeCountdown(1);

        // address is not inside the allowedCreators list and is not the creator of the locking position
        vm.prank(address(0x3));
        vm.expectRevert("L2Staking: only owner or creator can call this function");
        l2Staking.resumeCountdown(1);
    }

    function test_ResumeCountdown_ZeroPausedLockingDuration() public {
        vm.prank(alice);
        l2Staking.lockAmount(alice, 100 * 10 ** 18, 365);
        assertEq(l2LockingPosition.balanceOf(alice), 1);
        assertEq(l2LockingPosition.getLockingPosition(1).pausedLockingDuration, 0);

        vm.prank(alice);
        vm.expectRevert("L2Staking: countdown is not paused");
        l2Staking.resumeCountdown(1);
    }

    function test_TransferOwnership() public {
        address newOwner = vm.addr(100);

        l2Staking.transferOwnership(newOwner);
        assertEq(l2Staking.owner(), address(this));

        vm.prank(newOwner);
        l2Staking.acceptOwnership();
        assertEq(l2Staking.owner(), newOwner);
    }

    function test_TransferOwnership_RevertWhenNotCalledByOwner() public {
        address newOwner = vm.addr(1);
        address nobody = vm.addr(2);

        // owner is this contract
        assertEq(l2Staking.owner(), address(this));

        // address nobody is not the owner so it cannot call transferOwnership
        vm.startPrank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2Staking.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function test_TransferOwnership_RevertWhenNotCalledByPendingOwner() public {
        address newOwner = vm.addr(100);

        l2Staking.transferOwnership(newOwner);
        assertEq(l2Staking.owner(), address(this));

        address nobody = vm.addr(200);
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2Staking.acceptOwnership();
    }
}
