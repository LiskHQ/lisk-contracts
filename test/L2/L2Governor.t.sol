// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { IVotes } from "@openzeppelin-upgradeable/contracts/governance/extensions/GovernorVotesUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test, console } from "forge-std/Test.sol";
import { L2Governor } from "src/L2/L2Governor.sol";
import { Utils } from "script/Utils.sol";

contract L2GovernorV2 is L2Governor {
    uint256 public testNumber;

    function initializeV2(uint256 _testNumber) public reinitializer(2) {
        testNumber = _testNumber;
    }

    function version() public pure virtual override returns (string memory) {
        return "2.0.0";
    }

    function onlyV2() public pure returns (string memory) {
        return "Only L2GovernorV2 have this function";
    }
}

contract L2GovernorTest is Test {
    Utils public utils;
    L2Governor public l2GovernorImplementation;
    L2Governor public l2Governor;

    IVotes votingPower;
    address[] executors;
    TimelockController timelock;
    address initialOwner;

    function setUp() public {
        utils = new Utils();

        // set initial values
        votingPower = IVotes(address(0x1));
        executors.push(address(0)); // executor array contains address(0) such that anyone can execute proposals
        timelock = new TimelockController(0, new address[](0), executors, address(this));
        initialOwner = address(this);

        console.log("L2GovernorTest address is: %s", address(this));

        // deploy L2Governor Implementation contract
        l2GovernorImplementation = new L2Governor();

        // deploy L2Governor contract via proxy and initialize it at the same time
        l2Governor = L2Governor(
            payable(
                address(
                    new ERC1967Proxy(
                        address(l2GovernorImplementation),
                        abi.encodeWithSelector(l2Governor.initialize.selector, votingPower, timelock, initialOwner)
                    )
                )
            )
        );

        assertEq(l2Governor.name(), "Lisk Governor");
        assertEq(l2Governor.version(), "1.0.0");
        assertEq(l2Governor.votingDelay(), 0);
        assertEq(l2Governor.votingPeriod(), 604800);
        assertEq(l2Governor.proposalThreshold(), 300_000 * 10 ** 18);
        assertEq(l2Governor.timelock(), address(timelock));
        assertEq(l2Governor.quorum(0), 24_000_000 * 10 ** 18);
        assertEq(address(l2Governor.token()), address(votingPower));
        assertEq(l2Governor.owner(), initialOwner);

        // assure that address(0) is in executors role
        assertEq(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(0)), true);
    }

    function test_Initialize_ZeroVotesTokenAddress() public {
        vm.expectRevert("L2Governor: Votes token address cannot be 0");
        l2Governor = L2Governor(
            payable(
                address(
                    new ERC1967Proxy(
                        address(l2GovernorImplementation),
                        abi.encodeWithSelector(l2Governor.initialize.selector, address(0), timelock, initialOwner)
                    )
                )
            )
        );
    }

    function test_Initialize_ZeroTimelockControllerAddress() public {
        vm.expectRevert("L2Governor: Timelock Controller address cannot be 0");
        l2Governor = L2Governor(
            payable(
                address(
                    new ERC1967Proxy(
                        address(l2GovernorImplementation),
                        abi.encodeWithSelector(l2Governor.initialize.selector, votingPower, address(0), initialOwner)
                    )
                )
            )
        );
    }

    function test_Initialize_ZeroInitialOwnerAddress() public {
        vm.expectRevert("L2Governor: initial owner address cannot be 0");
        l2Governor = L2Governor(
            payable(
                address(
                    new ERC1967Proxy(
                        address(l2GovernorImplementation),
                        abi.encodeWithSelector(l2Governor.initialize.selector, votingPower, timelock, address(0))
                    )
                )
            )
        );
    }

    function test_TransferOwnership() public {
        address newOwner = vm.addr(1);

        l2Governor.transferOwnership(newOwner);
        assertEq(l2Governor.owner(), address(this));

        vm.prank(newOwner);
        l2Governor.acceptOwnership();
        assertEq(l2Governor.owner(), newOwner);
    }

    function test_TransferOwnership_RevertWhenNotCalledByOwner() public {
        address newOwner = vm.addr(1);
        address nobody = vm.addr(2);

        // owner is this contract
        assertEq(l2Governor.owner(), address(this));

        // address nobody is not the owner so it cannot call transferOwnership
        vm.startPrank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2Governor.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function test_TransferOwnership_RevertWhenNotCalledByPendingOwner() public {
        address newOwner = vm.addr(1);

        l2Governor.transferOwnership(newOwner);
        assertEq(l2Governor.owner(), address(this));

        address nobody = vm.addr(2);
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2Governor.acceptOwnership();
    }

    function test_UpgradeToAndCall_RevertWhenNotOwner() public {
        // deploy L2GovernorV2 implementation contract
        L2GovernorV2 l2GovernorV2Implementation = new L2GovernorV2();
        address nobody = vm.addr(1);

        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2Governor.upgradeToAndCall(address(l2GovernorV2Implementation), "");
    }

    function test_UpgradeToAndCall_SuccessUpgrade() public {
        // deploy L2GovernorV2 implementation contract
        L2GovernorV2 l2GovernorV2Implementation = new L2GovernorV2();

        uint256 testNumber = 123;

        // upgrade contract, and also change some variables by reinitialize
        l2Governor.upgradeToAndCall(
            address(l2GovernorV2Implementation),
            abi.encodeWithSelector(l2GovernorV2Implementation.initializeV2.selector, testNumber)
        );

        // wrap L2Governor proxy with new contract
        L2GovernorV2 l2GovernorV2 = L2GovernorV2(payable(address(l2Governor)));

        // assure version is updated
        assertEq(l2GovernorV2.version(), "2.0.0");

        // new testNumber variable introduced
        assertEq(l2GovernorV2.testNumber(), testNumber);

        // new function introduced
        assertEq(l2GovernorV2.onlyV2(), "Only L2GovernorV2 have this function");

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2GovernorV2.initializeV2(testNumber + 1);
    }
}
