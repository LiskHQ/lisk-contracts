// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { L2LiskTokenHandler } from "test/invariant/handler/L2LiskTokenHandler.t.sol";
import { L2ClaimHelper } from "test/L2/helper/L2ClaimHelper.sol";

contract L2LiskTokenInvariants is L2ClaimHelper {
    address public remoteToken;
    address public bridge;
    L2LiskToken public l2LiskToken;

    L2LiskTokenHandler internal l2LiskTokenHandler;

    function setUp() public {
        bridge = vm.addr(uint256(bytes32("bridge")));
        remoteToken = vm.addr(uint256(bytes32("remoteToken")));

        // msg.sender and tx.origin needs to be the same for the contract to be able to call initialize()
        vm.prank(address(this), address(this));
        l2LiskToken = new L2LiskToken(remoteToken);
        l2LiskToken.initialize(bridge);
        vm.stopPrank();

        l2LiskTokenHandler = new L2LiskTokenHandler(l2LiskToken);

        // add the handler selectors to the fuzzing targets
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = L2LiskTokenHandler.mint.selector;
        selectors[1] = L2LiskTokenHandler.burn.selector;

        targetSelector(FuzzSelector({ addr: address(l2LiskTokenHandler), selectors: selectors }));
        targetContract(address(l2LiskTokenHandler));
    }

    function invariant_L2LiskToken_metadataIsUnchanged() public view {
        assertEq(l2LiskToken.name(), "Lisk");
        assertEq(l2LiskToken.symbol(), "LSK");
        assertEq(l2LiskToken.bridge(), bridge);
        assertEq(l2LiskToken.remoteToken(), remoteToken);
    }

    function invariant_L2LiskToken_totalBalancesEqualToTotalSupply() public view {
        assertEq(l2LiskTokenHandler.totalBalances(), l2LiskToken.totalSupply());
    }
}
