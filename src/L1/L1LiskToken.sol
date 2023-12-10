// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "../utils/ownership/Ownable.sol";
import { BurnerRole } from "../access/roles/BurnerRole.sol";

contract L1LiskToken is ERC20, Ownable, BurnerRole {
    string private constant NAME = "Lisk";
    string private constant SYMBOL = "LSK";
    uint256 private constant TOTAL_SUPPLY = 200_000_000 * 10 ** 18; //200 million LSK tokens

    constructor() ERC20(NAME, SYMBOL) {
        _mint(_msgSender(), TOTAL_SUPPLY);
    }

    function addBurner(address account) public override onlyOwner {
        _addBurner(account);
    }

    function renounceBurner(address account) public override onlyOwner {
        _removeBurner(account);
    }
}
