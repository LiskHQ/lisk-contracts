// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Roles } from "@hiddentao/contracts/access/Roles.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";

contract BurnerRole is Context {
    using Roles for Roles.Role;

    error UnauthorizedBurnerAccount(address account);

    event BurnerAdded(address indexed account);
    event BurnerRemoved(address indexed account);

    Roles.Role private burners;

    function isBurner(address account) public view returns (bool) {
        return burners.has(account);
    }

    function addBurner(address account) public virtual {
        _addBurner(account);
    }

    function renounceBurner(address account) public virtual {
        _removeBurner(account);
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
