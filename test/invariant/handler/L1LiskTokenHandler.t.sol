// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console } from "forge-std/Test.sol";
import { L1LiskToken } from "src/L1/L1LiskToken.sol";

contract L1LiskTokenHandler is Test {
    uint256 public constant numOfAddresses = 100;

    address public immutable burner = vm.addr(uint256(bytes32("burner")));
    L1LiskToken public immutable l1LiskToken;

    constructor(L1LiskToken _l1LiskToken) {
        l1LiskToken = _l1LiskToken;
    }

    function burnFrom(uint256 _addressIndex, uint256 _amount) public {
        address from = vm.addr(bound(_addressIndex, 1, numOfAddresses));
        _amount = bound(_amount, 0, l1LiskToken.balanceOf(from));

        vm.startPrank(burner);
        l1LiskToken.burnFrom(from, _amount);
        vm.stopPrank();
    }

    function totalBalances() public view returns (uint256 balances) {
        for (uint256 i = 1; i <= numOfAddresses; i++) {
            balances += l1LiskToken.balanceOf(vm.addr(i));
        }

        return balances;
    }
}
