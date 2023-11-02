// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { L1LiskToken } from "src/L1/L1LiskToken.sol";

contract L2Claim {
    string private constant NAME = "Claim process";
    L1LiskToken public immutable l1LiskToken;

    constructor(address l1TokenAddress) {
        l1LiskToken = L1LiskToken(l1TokenAddress);
    }

    function name() public pure returns (string memory) {
        return NAME;
    }

    function claim() public {
        // send 5 Lisk tokens to the sender
        l1LiskToken.transfer(msg.sender, 5);
    }
}
