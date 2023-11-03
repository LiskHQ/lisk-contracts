// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract UUPSProxy is ERC1967Proxy {
    constructor(address _implementation, bytes memory _data) ERC1967Proxy(_implementation, _data) { }
}

contract L1LiskToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    string private constant NAME = "Lost Space Key";
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
