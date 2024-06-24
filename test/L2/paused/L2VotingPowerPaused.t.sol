// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Test, console } from "forge-std/Test.sol";
import { L2VotingPower } from "src/L2/L2VotingPower.sol";
import { L2VotingPowerPaused } from "src/L2/paused/L2VotingPowerPaused.sol";
import { IL2LockingPosition } from "src/interfaces/L2/IL2LockingPosition.sol";
import { Utils } from "script/contracts/Utils.sol";

contract MockL2VotingPowerV2 is L2VotingPower {
    uint256 public testNumber;

    function initializeV2(uint256 _testNumber) public reinitializer(3) {
        version = "2.0.0";
        testNumber = _testNumber;
    }

    function onlyV2() public pure returns (string memory) {
        return "Only L2VotingPowerV2 have this function";
    }
}

contract L2VotingPowerPausedTest is Test {
    Utils public utils;
    L2VotingPower public l2VotingPowerImplementation;
    L2VotingPower public l2VotingPower;

    address lockingPositionContractAddress;

    function assertInitParamsEq() internal view {
        assertEq(l2VotingPower.lockingPositionAddress(), lockingPositionContractAddress);
        assertEq(l2VotingPower.name(), "Lisk Voting Power");
        assertEq(l2VotingPower.symbol(), "vpLSK");
    }

    function setUp() public {
        utils = new Utils();

        // set initial values
        lockingPositionContractAddress = address(0xdeadbeefdeadbeefdeadbeef);

        console.log("L2VotingPowerTest address is: %s", address(this));

        // deploy L2VotingPower Implementation contract
        l2VotingPowerImplementation = new L2VotingPower();

        // deploy L2VotingPower contract via proxy and initialize it at the same time
        l2VotingPower = L2VotingPower(
            address(
                new ERC1967Proxy(
                    address(l2VotingPowerImplementation),
                    abi.encodeWithSelector(l2VotingPower.initialize.selector, lockingPositionContractAddress)
                )
            )
        );

        assertInitParamsEq();
        assertEq(l2VotingPower.version(), "1.0.0");

        // Upgrade from L2VotingPower to L2VotingPowerPaused, and call initializePaused
        L2VotingPowerPaused l2VotingPowerPausedImplementation = new L2VotingPowerPaused();
        l2VotingPower.upgradeToAndCall(
            address(l2VotingPowerPausedImplementation),
            abi.encodeWithSelector(l2VotingPowerPausedImplementation.initializePaused.selector)
        );

        // l2VotingPower pointing to paused contract
        assertEq(l2VotingPower.version(), "1.0.0-paused");

        // Ensure all other params are unchanged after paused contract update
        assertInitParamsEq();
    }

    function test_AdjustVotingPower_NotPaused() public {
        IL2LockingPosition.LockingPosition memory positionBefore =
            IL2LockingPosition.LockingPosition(address(this), 50, 0, 0);
        IL2LockingPosition.LockingPosition memory positionAfter =
            IL2LockingPosition.LockingPosition(address(this), 100, 0, 0);

        // call it as LockingPosition contract
        vm.prank(lockingPositionContractAddress);

        // Throws the require check on the first line, proving this function is not paused
        vm.expectRevert("L2VotingPower: owner address cannot be 0");
        l2VotingPower.adjustVotingPower(address(0), positionBefore, positionAfter);
    }

    function test_Delegate_Paused() public {
        vm.expectRevert(L2VotingPowerPaused.VotingPowerIsPaused.selector);
        l2VotingPower.delegate(address(0));
    }

    function test_DelegateBySig_Paused() public {
        vm.expectRevert(L2VotingPowerPaused.VotingPowerIsPaused.selector);
        l2VotingPower.delegateBySig(address(0), 0, 0, 0, "", "");
    }

    function test_UpgradeToAndCall_CanUpgradeFromPausedContractToNewContract() public {
        MockL2VotingPowerV2 mockL2VotingPowerV2Implementation = new MockL2VotingPowerV2();

        uint256 testNumber = 123;

        // upgrade contract, and also change some variables by reinitialize
        l2VotingPower.upgradeToAndCall(
            address(mockL2VotingPowerV2Implementation),
            abi.encodeWithSelector(mockL2VotingPowerV2Implementation.initializeV2.selector, testNumber)
        );

        // new testNumber variable introduced
        assertEq(MockL2VotingPowerV2(address(l2VotingPower)).testNumber(), testNumber);

        // new version updated
        assertEq(l2VotingPower.version(), "2.0.0");
    }
}
