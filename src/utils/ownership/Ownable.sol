// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { Unauthorized } from "../Errors.sol";

abstract contract Ownable is Context {
    address private _owner;

    constructor() {
        _owner = _msgSender();
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    modifier onlyOwner() {
        if (!isOwner()) {
            revert Unauthorized();
        }
        _;
    }
}
