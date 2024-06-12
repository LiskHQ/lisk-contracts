// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/// @title MockERC721
/// @notice MockERC721 is a mock implementation of ERC721 token.
///         IT SHOULD NEVER BE USED IN PRODUCTION.
contract MockERC721 is ERC721 {
    constructor() ERC721("MockERC721", "ERC721") { }

    function mint(address _to, uint256 _id) public {
        _mint(_to, _id);
    }
}
