// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Test, console, stdJson } from "forge-std/Test.sol";

import { L1LiskToken } from "src/L1/L1LiskToken.sol";
import { L1LiskTokenHandler } from "test/invariant/handler/L1LiskTokenHandler.t.sol";

contract L1LiskTokenInvariants is Test {
    address public immutable burner = vm.addr(uint256(bytes32("burner")));
    L1LiskToken public l1LiskToken;

    L1LiskTokenHandler internal l1LiskTokenHandler;

    function setUp() public {
        // msg.sender and tx.origin needs to be the same for the contract to be able to call initialize()
        l1LiskToken = new L1LiskToken();

        l1LiskTokenHandler = new L1LiskTokenHandler(l1LiskToken);

        // add the handler selectors to the fuzzing targets
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = L1LiskTokenHandler.burnFrom.selector;

        targetSelector(FuzzSelector({ addr: address(l1LiskTokenHandler), selectors: selectors }));
        targetContract(address(l1LiskTokenHandler));
    }

    function invariant_metadataIsUnchanged() public view {
        assertEq(l1LiskToken.totalSupply(), 400_000_000 * 10 ** 18);
    }
}
