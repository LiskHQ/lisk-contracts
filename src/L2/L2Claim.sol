// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

contract L2Claim {
    string private constant NAME = "Claim process";

    constructor() { }

    function name() public pure returns (string memory) {
        return NAME;
    }
}
