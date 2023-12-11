// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Roles } from "@hiddentao/contracts/access/Roles.sol";

contract L1LiskToken is ERC20, ERC20Permit, Ownable {
    using Roles for Roles.Role;

    error UnauthorizedBurnerAccount(address account);

    event BurnerAdded(address indexed account);
    event BurnerRemoved(address indexed account);

    string private constant NAME = "Lisk";
    string private constant SYMBOL = "LSK";
    uint256 private constant TOTAL_SUPPLY = 200_000_000 * 10 ** 18; //200 million LSK tokens

    Roles.Role private burners;

    constructor() ERC20(NAME, SYMBOL) ERC20Permit(NAME) Ownable(_msgSender()) {
        _mint(_msgSender(), TOTAL_SUPPLY);
    }

    function isBurner(address account) public view returns (bool) {
        return burners.has(account);
    }

    function addBurner(address account) public onlyOwner {
        _addBurner(account);
    }

    function renounceBurner(address account) public onlyOwner {
        _removeBurner(account);
    }

    function burn(uint256 value) public onlyBurner {
        _burn(_msgSender(), value);
    }

    modifier onlyBurner() {
        if (!isBurner(_msgSender())) {
            revert UnauthorizedBurnerAccount(_msgSender());
        }
        _;
    }

    function _addBurner(address account) internal {
        burners.add(account);
        emit BurnerAdded(account);
    }

    function _removeBurner(address account) internal {
        burners.remove(account);
        emit BurnerRemoved(account);
    }
}
