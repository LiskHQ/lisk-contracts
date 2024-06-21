// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Test, console, stdJson } from "forge-std/Test.sol";
import { L1LiskToken } from "src/L1/L1LiskToken.sol";

contract L1LiskTokenHandler is Test {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant numOfAddresses = 100;
    address public immutable burner = vm.addr(uint256(bytes32("burner")));
    L1LiskToken public immutable l1LiskToken;

    EnumerableSet.AddressSet internal addressesWithInteraction;

    constructor(L1LiskToken _l1LiskToken) {
        l1LiskToken = _l1LiskToken;
    }

    function burnFrom(uint256 _addressSeed, uint256 _amount) public {
        _addressSeed = bound(_addressSeed, 1, type(uint160).max);
        address from = vm.addr(_addressSeed);

        _amount = bound(_amount, 0, type(uint96).max);
        if (_amount > l1LiskToken.balanceOf(from)) {
            return;
        }

        vm.startPrank(burner);
        l1LiskToken.burnFrom(from, _amount);
        vm.stopPrank();
    }
}
