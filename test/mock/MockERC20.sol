// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(uint256 _totalSupply) ERC20("Mock Lisk Token", "mLSK") {
        _mint(msg.sender, _totalSupply);
    }
}
