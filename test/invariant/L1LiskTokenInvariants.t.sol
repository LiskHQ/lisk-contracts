// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console, stdJson } from "forge-std/Test.sol";

import { L1LiskToken } from "src/L1/L1LiskToken.sol";
import { L1LiskTokenHandler } from "test/invariant/handler/L1LiskTokenHandler.t.sol";

contract L1LiskTokenInvariants is Test {
    address public immutable burner = vm.addr(uint256(bytes32("burner")));
    L1LiskToken public l1LiskToken;

    L1LiskTokenHandler internal l1LiskTokenHandler;

    function setUp() public {
        l1LiskToken = new L1LiskToken();
        l1LiskToken.addBurner(burner);

        l1LiskTokenHandler = new L1LiskTokenHandler(l1LiskToken);

        // L1 Token has fixed supply and not mintable, distributing tokens to addresses
        uint256 totalPortions = l1LiskTokenHandler.numOfAddresses() * (l1LiskTokenHandler.numOfAddresses() + 1) / 2;
        for (uint256 i = 1; i < l1LiskTokenHandler.numOfAddresses() + 1; i++) {
            address balanceHolder = vm.addr(i);

            // Approve token to be burnt
            vm.startPrank(balanceHolder);
            l1LiskToken.approve(burner, type(uint256).max);
            vm.stopPrank();

            // #1 address gets 1 portion, #2 gets 2 portions etc.
            l1LiskToken.transfer(balanceHolder, l1LiskToken.totalSupply() * i / totalPortions);

            // Last address gets the rest of the balances, to ensure address(this) has no balance left because of
            // rounding
            if (i == l1LiskTokenHandler.numOfAddresses()) {
                l1LiskToken.transfer(balanceHolder, l1LiskToken.balanceOf(address(this)));
            }
        }

        // add the handler selectors to the fuzzing targets
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = L1LiskTokenHandler.burnFrom.selector;

        targetSelector(FuzzSelector({ addr: address(l1LiskTokenHandler), selectors: selectors }));
        targetContract(address(l1LiskTokenHandler));
    }

    function invariant_L1LiskToken_metadataIsUnchanged() public view {
        assertEq(l1LiskToken.name(), "Lisk");
        assertEq(l1LiskToken.symbol(), "LSK");
        assertEq(l1LiskToken.isBurner(burner), true);
    }

    function invariant_L1LiskToken_totalBalancesEqualToTotalSupply() public view {
        assertEq(l1LiskTokenHandler.totalBalances(), l1LiskToken.totalSupply());
    }
}
