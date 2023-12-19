// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract L1LiskToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    string private constant NAME = "Lisk";
    string private constant SYMBOL = "LSK";
    uint256 private constant TOTAL_SUPPLY = 200_000_000 * 10 ** 18; //200 million LSK tokens

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC20_init(NAME, SYMBOL);
        _mint(msg.sender, TOTAL_SUPPLY);
        __Ownable_init(msg.sender);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
