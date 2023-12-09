// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Test, console2 } from "forge-std/Test.sol";
import { L1LiskToken } from "src/L1/L1LiskToken.sol";

contract L1LiskTokenTest is Test {
    string private constant NAME = "Lisk";
    string private constant SYMBOL = "LSK";
    uint256 private constant TOTAL_SUPPLY = 200_000_000 * 10 ** 18; //200 million LSK tokens

    L1LiskToken l1LiskToken;

    function setUp() public {
        l1LiskToken = new L1LiskToken();
    }

    function test_Initialize() public {
        assertEq(l1LiskToken.name(), NAME);
        assertEq(l1LiskToken.symbol(), SYMBOL);
        assertEq(l1LiskToken.totalSupply(), TOTAL_SUPPLY);
        assertEq(l1LiskToken.balanceOf(address(this)), TOTAL_SUPPLY);
    }
}
