// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Test, console, stdJson } from "forge-std/Test.sol";
import { L2Claim, ED25519Signature, MultisigKeys } from "src/L2/L2Claim.sol";
import { L2ClaimHelper, MerkleTreeLeaf, Signature, MerkleLeaves } from "test/L2/helper/L2ClaimHelper.sol";

contract L2ClaimHandler is Test {
    using stdJson for string;

    L2Claim public immutable l2Claim;
    ERC20 public immutable lsk;
    address public immutable recipientAddress;

    string public signatureJson;
    string public merkleLeavesJson;
    string public merkleRootJson;
    bytes32 public merkleRootHex;

    // Invariant Test Params
    uint256 public totalClaimed;

    constructor(L2Claim _l2Claim, ERC20 _lsk, address _recipientAddress) {
        l2Claim = _l2Claim;
        lsk = _lsk;
        recipientAddress = _recipientAddress;

        string memory rootPath = string.concat(vm.projectRoot(), "/test/L2/data");
        signatureJson = vm.readFile(string.concat(rootPath, "/signatures.json"));
        merkleLeavesJson = vm.readFile(string.concat(rootPath, "/merkle-leaves.json"));
        merkleRootJson = vm.readFile(string.concat(rootPath, "/merkle-root.json"));
    }

    function getSignature(uint256 _index) internal view returns (Signature memory) {
        return abi.decode(
            signatureJson.parseRaw(string(abi.encodePacked(".[", Strings.toString(_index), "]"))), (Signature)
        );
    }

    // get detailed MerkleTree, which is located in `test/L2/data` and only being used by testing scripts
    function getMerkleLeaves() internal view returns (MerkleLeaves memory) {
        return abi.decode(merkleLeavesJson.parseRaw("."), (MerkleLeaves));
    }

    function claimRegularAccount(uint8 _index) public {
        // index #0 - #49 are regular accounts
        _index = uint8(bound(_index, 0, 49));

        uint256 originalBalance = lsk.balanceOf(recipientAddress);
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[_index];
        Signature memory signature = getSignature(_index);

        bytes32 pubKey = signature.sigs[0].pubKey;

        // check that the LSKClaimed event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Claim.LSKClaimed(bytes20(sha256(abi.encode(pubKey))), recipientAddress, leaf.balanceBeddows);

        l2Claim.claimRegularAccount(
            leaf.proof,
            pubKey,
            leaf.balanceBeddows,
            recipientAddress,
            ED25519Signature(signature.sigs[0].r, signature.sigs[0].s)
        );

        assertEq(lsk.balanceOf(recipientAddress), originalBalance + leaf.balanceBeddows * l2Claim.LSK_MULTIPLIER());
        assertEq(l2Claim.claimedTo(bytes20(sha256(abi.encode(pubKey)))), recipientAddress);

        totalClaimed += leaf.balanceBeddows * l2Claim.LSK_MULTIPLIER();
    }

    function claimMultisigAccount(uint8 _index) public {
        // index #50 - #53 are multisig accounts
        _index = uint8(bound(_index, 0, 3)) + 50;

        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[_index];
        Signature memory signature = getSignature(_index);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](leaf.mandatoryKeys.length + leaf.optionalKeys.length);
        for (uint256 i; i < leaf.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        bytes20 lskAddress = bytes20(leaf.b32Address << 96);

        // check that the LSKClaimed event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Claim.LSKClaimed(lskAddress, recipientAddress, leaf.balanceBeddows);

        l2Claim.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            recipientAddress,
            ed25519Signatures
        );

        assertEq(lsk.balanceOf(recipientAddress), leaf.balanceBeddows * l2Claim.LSK_MULTIPLIER());
        assertEq(l2Claim.claimedTo(lskAddress), recipientAddress);

        totalClaimed += leaf.balanceBeddows * l2Claim.LSK_MULTIPLIER();
    }
}
