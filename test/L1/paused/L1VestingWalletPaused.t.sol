// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console, stdJson } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { L1VestingWallet } from "src/L1/L1VestingWallet.sol";
import { L1VestingWalletPaused } from "src/L1/paused/L1VestingWalletPaused.sol";
import { MockERC20 } from "test/mock/MockERC20.sol";

contract L1VestingWalletPausedTest is Test {
    using stdJson for string;

    L1VestingWallet public l1VestingWallet;
    L1VestingWallet public l1VestingWalletImplementation;

    L1VestingWalletPaused public l1VestingWalletPaused;
    L1VestingWalletPaused public l1VestingWalletPausedImplementation;

    MockERC20 public mockToken;

    address public beneficiary = vm.addr(uint256(bytes32("beneficiary")));
    address public contractAdmin = vm.addr(uint256(bytes32("contractAdmin")));
    uint64 public startTimestamp = uint64(vm.getBlockTimestamp());
    uint64 public durationSeconds = 1000;
    string public name = "Vesting Wallet";

    uint256 public vestAmount = 1_000_000;

    function setUp() public {
        // deploy L1VestingWallet implementation contract
        l1VestingWalletImplementation = new L1VestingWallet();

        // deploy L1VestingWallet contract via proxy and initialize it at the same time
        l1VestingWallet = L1VestingWallet(
            payable(
                address(
                    new ERC1967Proxy(
                        address(l1VestingWalletImplementation),
                        abi.encodeWithSelector(
                            l1VestingWalletImplementation.initialize.selector,
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
        assert(address(l1VestingWallet) != address(0x0));

        // transfer token to vesting contract
        mockToken = new MockERC20(vestAmount);
        mockToken.transfer(address(l1VestingWallet), vestAmount);

        // deploy L1VestingWalletPaused implementation contract
        l1VestingWalletPausedImplementation = new L1VestingWalletPaused();

        // upgrade L1VestingWallet contract to L1VestingWalletPaused contract
        vm.startPrank(contractAdmin);
        l1VestingWallet.upgradeToAndCall(
            address(l1VestingWalletPausedImplementation),
            abi.encodeWithSelector(l1VestingWalletPausedImplementation.initializePaused.selector)
        );
        vm.stopPrank();

        // Wrapping with L1VestingWalletPaused
        l1VestingWalletPaused = L1VestingWalletPaused(payable(address(l1VestingWallet)));
    }

    function test_CustodianAddress() public view {
        // Address of Security Council on L1
        assertEq(l1VestingWalletPaused.custodianAddress(), 0xD2D7535e099F26EbfbA26d96bD1a661d3531d0e9);
    }
}
