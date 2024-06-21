// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { L2Claim } from "src/L2/L2Claim.sol";
import { L2ClaimHandler } from "test/invariant/handler/L2ClaimHandler.t.sol";
import { L2ClaimHelper, MerkleTreeLeaf } from "test/L2/helper/L2ClaimHelper.sol";

contract L2ClaimInvariants is L2ClaimHelper {
    L2ClaimHandler internal l2ClaimHandler;

    function setUp() public {
        setUpL2Claim();

        l2ClaimHandler = new L2ClaimHandler(l2Claim, lsk, RECIPIENT_ADDRESS);

        // add the handler selectors to the fuzzing targets
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = L2ClaimHandler.claimRegularAccount.selector;
        selectors[1] = L2ClaimHandler.claimMultisigAccount.selector;

        targetSelector(FuzzSelector({ addr: address(l2ClaimHandler), selectors: selectors }));
        targetContract(address(l2ClaimHandler));
    }

    function invariant_L2Claim_metadataIsUnchanged() public view {
        assertEq(address(l2Claim.l2LiskToken()), address(lsk));
        assertEq(l2Claim.merkleRoot(), merkleRootHex);
    }

    function invariant_L2Claim_outAmountEqualToClaimAmount() public view {
        assertEq(INIT_BALANCE - l2ClaimHandler.totalClaimed(), lsk.balanceOf(address(l2Claim)));
    }
}
