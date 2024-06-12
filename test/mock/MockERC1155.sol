// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

/// @title MockERC1155
/// @notice MockERC1155 is a mock implementation of ERC1155 token.
///         IT SHOULD NEVER BE USED IN PRODUCTION.
contract MockERC1155 is ERC1155 {
    constructor() ERC1155("") { }

    function mint(address _to, uint256 _id, uint256 _value, bytes memory _data) public {
        _mint(_to, _id, _value, _data);
    }
}
