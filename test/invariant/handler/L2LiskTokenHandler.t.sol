// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Test, stdJson } from "forge-std/Test.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";

contract L2LiskTokenHandler is Test {
    using EnumerableSet for EnumerableSet.AddressSet;

    L2LiskToken public immutable l2LiskToken;

    EnumerableSet.AddressSet internal addressesWithInteraction;

    constructor(L2LiskToken _l2LiskToken) {
        l2LiskToken = _l2LiskToken;
    }

    function mint(uint256 _addressSeed, uint256 _amount) public {
        address to = vm.addr(bound(_addressSeed, 1, type(uint160).max));
        _amount = bound(_amount, 0, type(uint96).max);

        vm.startPrank(l2LiskToken.bridge());
        l2LiskToken.mint(to, _amount);
        vm.stopPrank();

        addressesWithInteraction.add(to);
    }

    function burn(uint256 _addressSeed, uint256 _amount) public {
        address from = vm.addr(bound(_addressSeed, 1, type(uint160).max));
        _amount = bound(_amount, 0, l2LiskToken.balanceOf(from));

        vm.startPrank(l2LiskToken.BRIDGE());
        l2LiskToken.burn(from, _amount);
        vm.stopPrank();
    }

    function totalBalances() public view returns (uint256 balances) {
        for (uint256 i; i < addressesWithInteraction.length(); i++) {
            balances += l2LiskToken.balanceOf(addressesWithInteraction.at(i));
        }

        return balances;
    }
}
