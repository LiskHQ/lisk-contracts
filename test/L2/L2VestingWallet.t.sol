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

    function setUp() public {
        console.log("L2VestingWalletTest Address is: %s", address(this));

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
                            name
                        )
                    )
                )
            )
        );
        assert(address(l2VestingWallet) != address(0x0));

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
        assertEq(mockToken.balanceOf(beneficiary), vestAmount/ 10);
    }

    // To verify if the contract works correctly when durationSeconds = 0
    function test_InstantRelease() public {
        L2VestingWallet l2VestingWalletInstant = L2VestingWallet(
            payable(
                address(
                    new ERC1967Proxy(
                        address(l2VestingWalletImplementation),
                        abi.encodeWithSelector(
                            l2VestingWalletImplementation.initialize.selector,
                            beneficiary,
                            startTimestamp,
                            0,
                            name
                        )
                    )
                )
            )
        );
        assert(address(l2VestingWalletInstant) != address(0x0));

        MockERC20 mockToken2 = new MockERC20(vestAmount);
        mockToken2.transfer(address(l2VestingWalletInstant), vestAmount);
        assertEq(l2VestingWalletInstant.releasable(address(mockToken2)), vestAmount);

        vm.prank(beneficiary);
        l2VestingWalletInstant.release(address(mockToken2));
        assertEq(mockToken2.balanceOf(beneficiary), vestAmount);
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
