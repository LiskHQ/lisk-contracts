// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { L2LiskToken } from "src/L2/L2LiskToken.sol";

contract L2Claim {
    string private constant NAME = "Claim process";
    L2LiskToken public immutable l2LiskToken;

    constructor(address l2TokenAddress) {
        l2LiskToken = L2LiskToken(l2TokenAddress);
    }

    function name() public pure returns (string memory) {
        return NAME;
    }

    function claim() public {
        // send 5 Lisk tokens to the sender
        l2LiskToken.transfer(msg.sender, 5 * 10 ** 18);
    }
}
