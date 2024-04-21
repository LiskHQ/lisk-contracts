// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console, console2, StdCheats } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { L2VestingWallet } from "src/L2/L2VestingWallet.sol";
import { SigUtils } from "test/SigUtils.sol";
import { MockERC20 } from "test/mock/MockERC20.sol";

contract L2VestingWalletTest is Test {
    L2VestingWallet public l2VestingWallet;
    L2VestingWallet public l2VestingWalletImplementation;

    MockERC20 public mockToken;

    address public beneficiary = vm.addr(uint256(bytes32("beneficiary")));
    uint64 public startTimestamp = uint64(vm.getBlockTimestamp());
    uint64 public durationSeconds = 1000;
    string public name = "Vesting Wallet";

    uint256 public vestAmount = 1_000_000;

    function _deployVestingWallet(
        address _beneficiary,
        uint64 _startTimestamp,
        uint64 _durationSeconds,
        string memory _name
    )
        public
        returns (L2VestingWallet l2VestingWalletProxy)
    {
        l2VestingWalletProxy = L2VestingWallet(
            payable(
                address(
                    new ERC1967Proxy(
                        address(l2VestingWalletImplementation),
                        abi.encodeWithSelector(
                            l2VestingWalletImplementation.initialize.selector,
                            _beneficiary,
                            _startTimestamp,
                            _durationSeconds,
                            _name
                        )
                    )
                )
            )
        );
        assert(address(l2VestingWalletProxy) != address(0x0));
    }

    function setUp() public {
        console.log("L2VestingWalletTest Address is: %s", address(this));

        // deploy L2VestingWallet implementation contract
        l2VestingWalletImplementation = new L2VestingWallet();

        // deploy L2VestingWallet contract via proxy and initialize it at the same time
        l2VestingWallet = _deployVestingWallet(beneficiary, startTimestamp, durationSeconds, name);

        mockToken = new MockERC20(vestAmount);
        mockToken.transfer(address(l2VestingWallet), vestAmount);
    }

    function test_Initialize() public {
        assertEq(l2VestingWallet.name(), name);
        assertEq(l2VestingWallet.start(), startTimestamp);
        assertEq(l2VestingWallet.duration(), durationSeconds);
        assertEq(l2VestingWallet.version(), "1.0.0");
    }

    function test_Release() public {
        vm.warp(startTimestamp + durationSeconds / 10);
        assertEq(l2VestingWallet.releasable(address(mockToken)), vestAmount / 10);

        vm.prank(beneficiary);
        l2VestingWallet.release(address(mockToken));
        assertEq(mockToken.balanceOf(beneficiary), vestAmount / 10);
    }

    // To verify if the contract works correctly when durationSeconds = 0
    function test_Release_Instant() public {
        L2VestingWallet newL2VestingWallet = _deployVestingWallet(beneficiary, startTimestamp, 0, name);

        MockERC20 mockToken2 = new MockERC20(vestAmount);
        mockToken2.transfer(address(newL2VestingWallet), vestAmount);
        assertEq(newL2VestingWallet.releasable(address(mockToken2)), vestAmount);

        vm.prank(beneficiary);
        newL2VestingWallet.release(address(mockToken2));
        assertEq(mockToken2.balanceOf(beneficiary), vestAmount);
    }

    // Similar to test_Release_Instant, but startTimeStamp is set in future
    function test_Release_ZeroDurationSecondInFuture() public {
        // startTimestamp starts with 1, leap 10 years
        vm.warp(10 * 365 days);

        uint64 newStartTimestamp = uint64(vm.getBlockTimestamp());
        L2VestingWallet newL2VestingWallet = _deployVestingWallet(beneficiary, newStartTimestamp + 365 days, 0, name);

        // leap 11 years
        vm.warp(11 * 365 days + 1);
        MockERC20 mockToken2 = new MockERC20(vestAmount);
        mockToken2.transfer(address(newL2VestingWallet), vestAmount);
        assertEq(newL2VestingWallet.releasable(address(mockToken2)), vestAmount);

        vm.prank(beneficiary);
        newL2VestingWallet.release(address(mockToken2));
        assertEq(mockToken2.balanceOf(beneficiary), vestAmount);
    }

    // Token fully available after deployment
    function test_Release_FullyAvailable() public {
        // startTimestamp starts with 1, leap 10 years
        vm.warp(10 * 365 days);

        uint64 newStartTimestamp = uint64(vm.getBlockTimestamp());
        L2VestingWallet newL2VestingWallet =
            _deployVestingWallet(beneficiary, newStartTimestamp - 365 days, 100 days, name);

        MockERC20 mockToken2 = new MockERC20(vestAmount);
        mockToken2.transfer(address(newL2VestingWallet), vestAmount);
        assertEq(newL2VestingWallet.releasable(address(mockToken2)), vestAmount);

        vm.prank(beneficiary);
        newL2VestingWallet.release(address(mockToken2));
        assertEq(mockToken2.balanceOf(beneficiary), vestAmount);
    }

    // Token partially (50%) available after deployment
    function test_Release_PartiallyAvailable() public {
        // startTimestamp starts with 1, leap 10 years
        vm.warp(10 * 365 days);

        uint64 newStartTimestamp = uint64(vm.getBlockTimestamp());
        L2VestingWallet newL2VestingWallet =
            _deployVestingWallet(beneficiary, newStartTimestamp - 100 days, 365 days, name);

        MockERC20 mockToken2 = new MockERC20(vestAmount);
        mockToken2.transfer(address(newL2VestingWallet), vestAmount);
        assertEq(newL2VestingWallet.releasable(address(mockToken2)), vestAmount * 100 days / 365 days);

        vm.prank(beneficiary);
        newL2VestingWallet.release(address(mockToken2));
        assertEq(mockToken2.balanceOf(beneficiary), vestAmount * 100 days / 365 days);
    }

    // No token is available after deployment
    function test_Release_NoneAvailable() public {
        // startTimestamp starts with 1, leap 10 years
        vm.warp(10 * 365 days);

        uint64 newStartTimestamp = uint64(vm.getBlockTimestamp());
        L2VestingWallet newL2VestingWallet =
            _deployVestingWallet(beneficiary, newStartTimestamp + 365 days, 365 days, name);

        MockERC20 mockToken2 = new MockERC20(vestAmount);
        mockToken2.transfer(address(newL2VestingWallet), vestAmount);
        assertEq(newL2VestingWallet.releasable(address(mockToken2)), 0);

        vm.prank(beneficiary);
        newL2VestingWallet.release(address(mockToken2));
        assertEq(mockToken2.balanceOf(beneficiary), vestAmount * 0);
    }

    function test_TransferOwnership() public {
        address newOwner = vm.addr(100);

        vm.prank(beneficiary);
        l2VestingWallet.transferOwnership(newOwner);
        assertEq(l2VestingWallet.owner(), beneficiary);

        vm.prank(newOwner);
        l2VestingWallet.acceptOwnership();
        assertEq(l2VestingWallet.owner(), newOwner);
    }

    function test_TransferOwnership_RevertWhenNotCalledByOwner() public {
        address newOwner = vm.addr(1);
        address nobody = vm.addr(2);

        // owner is this contract
        assertEq(l2VestingWallet.owner(), beneficiary);

        // address nobody is not the owner so it cannot call transferOwnership
        vm.startPrank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2VestingWallet.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function test_TransferOwnership_RevertWhenNotCalledByPendingOwner() public {
        address newOwner = vm.addr(100);

        vm.prank(beneficiary);
        l2VestingWallet.transferOwnership(newOwner);
        assertEq(l2VestingWallet.owner(), beneficiary);

        address nobody = vm.addr(200);
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2VestingWallet.acceptOwnership();
    }
}
