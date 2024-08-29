// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console, stdJson } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { L2VestingWallet } from "src/L2/L2VestingWallet.sol";
import { L2VestingWalletPaused } from "src/L2/paused/L2VestingWalletPaused.sol";
import { MockERC20 } from "test/mock/MockERC20.sol";

contract L2VestingWalletV2UnpausedMock is L2VestingWallet {
    function initializeV2(string memory _version) public reinitializer(3) {
        version = _version;
    }

    function isV2() public pure returns (bool) {
        return true;
    }
}

contract L2VestingWalletPausedTest is Test {
    using stdJson for string;

    L2VestingWallet public l2VestingWallet;
    L2VestingWallet public l2VestingWalletImplementation;

    L2VestingWalletPaused public l2VestingWalletPaused;
    L2VestingWalletPaused public l2VestingWalletPausedImplementation;

    MockERC20 public mockToken;

    address public beneficiary = vm.addr(uint256(bytes32("beneficiary")));
    address public contractAdmin = vm.addr(uint256(bytes32("contractAdmin")));
    uint64 public startTimestamp = uint64(vm.getBlockTimestamp());
    uint64 public durationSeconds = 1000;
    string public name = "Vesting Wallet";

    uint256 public vestAmount = 1_000_000;

    function setUp() public {
        // deploy L2VestingWallet implementation contract
        l2VestingWalletImplementation = new L2VestingWallet();

        // deploy L2VestingWallet contract via proxy and initialize it at the same time
        l2VestingWallet = L2VestingWallet(
            payable(
                address(
                    new ERC1967Proxy(
                        address(l2VestingWalletImplementation),
                        abi.encodeWithSelector(
                            l2VestingWalletImplementation.initialize.selector,
                            beneficiary,
                            startTimestamp,
                            durationSeconds,
                            name,
                            contractAdmin
                        )
                    )
                )
            )
        );
        assert(address(l2VestingWallet) != address(0x0));

        // transfer token to vesting contract
        mockToken = new MockERC20(vestAmount);
        mockToken.transfer(address(l2VestingWallet), vestAmount);

        // deploy L2VestingWalletPaused implementation contract
        l2VestingWalletPausedImplementation = new L2VestingWalletPaused();

        // upgrade L2VestingWallet contract to L2VestingWalletPaused contract
        vm.startPrank(contractAdmin);
        l2VestingWallet.upgradeToAndCall(
            address(l2VestingWalletPausedImplementation),
            abi.encodeWithSelector(l2VestingWalletPausedImplementation.initializePaused.selector)
        );
        vm.stopPrank();

        // Wrapping with L2VestingWalletPaused
        l2VestingWalletPaused = L2VestingWalletPaused(payable(address(l2VestingWallet)));
    }

    function test_CustodianAddress() public view {
        // Address of Security Council on L2
        assertEq(l2VestingWalletPaused.custodianAddress(), 0x394Ae9d48eeca1C69a989B5A8C787081595c55A7);
    }

    function test_SendToCustodian_RevertWhenNotContractAdmin() public {
        address nobody = vm.addr(1);

        vm.startPrank(nobody);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nobody, l2VestingWallet.CONTRACT_ADMIN_ROLE()
            )
        );
        l2VestingWalletPaused.sendToCustodian(IERC20(address(mockToken)));
        vm.stopPrank();
    }

    function test_SendToCustodian() public {
        uint256 contractBalanceBefore = mockToken.balanceOf(address(l2VestingWalletPaused));
        uint256 recoveryAddressBalanceBefore = mockToken.balanceOf(l2VestingWalletPaused.custodianAddress());

        vm.startPrank(contractAdmin);
        l2VestingWalletPaused.sendToCustodian(IERC20(address(mockToken)));
        vm.stopPrank();

        assertEq(
            mockToken.balanceOf(l2VestingWalletPaused.custodianAddress()),
            contractBalanceBefore + recoveryAddressBalanceBefore
        );
    }

    function test_ReleaseWithAddress_Paused() public {
        vm.expectRevert(L2VestingWalletPaused.VestingWalletIsPaused.selector);
        l2VestingWallet.release(address(0));
    }

    function test_Release_Paused() public {
        vm.expectRevert(L2VestingWalletPaused.VestingWalletIsPaused.selector);
        l2VestingWallet.release();
    }

    function test_AcceptOwnership_Paused() public {
        vm.expectRevert(L2VestingWalletPaused.VestingWalletIsPaused.selector);
        l2VestingWallet.acceptOwnership();
    }

    function test_TransferOwnership_Paused() public {
        vm.expectRevert(L2VestingWalletPaused.VestingWalletIsPaused.selector);
        l2VestingWallet.transferOwnership(address(0));
    }

    function test_RenounceOwnership_Paused() public {
        vm.expectRevert(L2VestingWalletPaused.VestingWalletIsPaused.selector);
        l2VestingWallet.renounceOwnership();
    }

    function test_UpgradeToAndCall_CanUpgradeFromPausedContractToNewContract() public {
        L2VestingWalletV2UnpausedMock l2VestingWalletV2MockImplementation = new L2VestingWalletV2UnpausedMock();

        // upgrade L2VestingWallet contract to L2VestingWalletV2 contract
        vm.startPrank(contractAdmin);
        l2VestingWallet.upgradeToAndCall(
            address(l2VestingWalletV2MockImplementation),
            abi.encodeWithSelector(l2VestingWalletV2MockImplementation.initializeV2.selector, "2.0.0")
        );
        vm.stopPrank();

        // wrap L2VestingWallet Proxy with new contract
        L2VestingWalletV2UnpausedMock l2VestingWalletV2 =
            L2VestingWalletV2UnpausedMock(payable(address(l2VestingWallet)));

        // version was updated
        assertEq(l2VestingWalletV2.version(), "2.0.0");

        // new function introduced
        assertEq(l2VestingWalletV2.isV2(), true);

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2VestingWalletV2.initializeV2("2.0.1");
    }
}
