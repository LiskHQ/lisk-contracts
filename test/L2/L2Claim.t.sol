// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Test, console, stdJson } from "forge-std/Test.sol";
import { L2Claim, ED25519Signature, MultisigKeys } from "src/L2/L2Claim.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { Utils } from "script/Utils.sol";
import { MockERC20 } from "../mock/MockERC20.sol";

struct SigPair {
    bytes32 pubKey;
    bytes32 r;
    bytes32 s;
}

struct Signature {
    bytes message;
    SigPair[] sigs;
}

contract L2ClaimTest is Test {
    using stdJson for string;

    ERC20 public lsk;
    L2Claim public l2Claim;

    string public merkleTreeJson;
    string public signatureJson;

    function getMerkleTree() internal view returns (Utils.MerkleTree memory) {
        return abi.decode(merkleTreeJson.parseRaw("."), (Utils.MerkleTree));
    }

    function getSignature(uint256 _index) internal view returns (Signature memory) {
        return abi.decode(
            signatureJson.parseRaw(string(abi.encodePacked(".[", Strings.toString(_index), "]"))), (Signature)
        );
    }

    // Helper function to "invalidate" a proof or sig. (e.g. 0xabcdef -> 0xabcdf0)
    function bytes32AddOne(bytes32 _value) internal pure returns (bytes32) {
        return bytes32(uint256(_value) + 1);
    }

    function setUp() public {
        console.log("L2ClaimTest Address is: %s", address(this));

        string memory root = string.concat(vm.projectRoot(), "/test/L2/data");

        // Read Merkle Tree File
        merkleTreeJson = vm.readFile(string.concat(root, "/merkle-tree-result-simple.json"));

        // Read Pre-signed Signatures, for testing purpose
        signatureJson = vm.readFile(string.concat(root, "/signatures.json"));

        Utils.MerkleTree memory rawTxDetail = getMerkleTree();
        lsk = new MockERC20(10_000_000 * 10 ** 18);
        l2Claim = new L2Claim(address(lsk), rawTxDetail.merkleRoot);
        lsk.transfer(address(l2Claim), lsk.balanceOf(address(this)));

        assertEq(address(l2Claim.l2LiskToken()), address(lsk));
        assertEq(l2Claim.merkleRoot(), rawTxDetail.merkleRoot);
    }

    function test_claimRegularAccount_RevertWhenInvalidProof() public {
        uint256 accountIndex = 0;
        Utils.MerkleTreeNode memory node = getMerkleTree().node[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        node.proof[0] = bytes32AddOne(node.proof[0]);

        vm.expectRevert("Invalid Proof");
        l2Claim.claimRegularAccount(
            node.proof,
            bytes32(signature.sigs[0].pubKey),
            node.balanceBeddows,
            address(this),
            ED25519Signature(signature.sigs[0].r, signature.sigs[0].s)
        );
    }

    function test_claimRegularAccount_RevertWhenValidProofInvalidSig() public {
        uint256 accountIndex = 0;
        Utils.MerkleTreeNode memory node = getMerkleTree().node[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        vm.expectRevert();
        l2Claim.claimRegularAccount(
            node.proof,
            bytes32(signature.sigs[0].pubKey),
            node.balanceBeddows,
            address(this),
            ED25519Signature(bytes32AddOne(signature.sigs[0].r), signature.sigs[0].s)
        );

        vm.expectRevert();
        l2Claim.claimRegularAccount(
            node.proof,
            bytes32(signature.sigs[0].pubKey),
            node.balanceBeddows,
            address(this),
            ED25519Signature(signature.sigs[0].r, bytes32AddOne(signature.sigs[0].s))
        );
    }

    function claimRegularAccount(uint256 _accountIndex) internal {
        uint256 originalBalance = lsk.balanceOf(address(this));
        Utils.MerkleTreeNode memory node = getMerkleTree().node[_accountIndex];
        Signature memory signature = getSignature(_accountIndex);

        l2Claim.claimRegularAccount(
            node.proof,
            bytes32(signature.sigs[0].pubKey),
            node.balanceBeddows,
            address(this),
            ED25519Signature(signature.sigs[0].r, signature.sigs[0].s)
        );

        assertEq(lsk.balanceOf(address(this)), originalBalance + node.balanceBeddows * l2Claim.LSK_MULTIPLIER());
    }

    function test_claimRegularAccount_SuccessClaim() public {
        for (uint256 i; i < 50; i++) {
            claimRegularAccount(i);
        }
    }

    function test_claimRegularAccount_RevertWhenAlreadyClaimed() public {
        uint256 claimIndex = 0;
        claimRegularAccount(claimIndex);

        Utils.MerkleTreeNode memory node = getMerkleTree().node[claimIndex];
        Signature memory signature = getSignature(claimIndex);

        vm.expectRevert("Already Claimed");
        l2Claim.claimRegularAccount(
            node.proof,
            bytes32(signature.sigs[0].pubKey),
            node.balanceBeddows,
            address(this),
            ED25519Signature(signature.sigs[0].r, signature.sigs[0].s)
        );
    }

    // Multisig settings refers to: lisk-merkle-tree-builder/data/example/create-balances.ts
    function test_claimMultisigAccount_RevertWhenIncorrectProof() public {
        uint256 accountIndex = 50;
        Utils.MerkleTreeNode memory node = getMerkleTree().node[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](node.numberOfSignatures);

        for (uint256 i; i < node.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        node.proof[0] = bytes32AddOne(node.proof[0]);

        vm.expectRevert("Invalid Proof");
        l2Claim.claimMultisigAccount(
            node.proof,
            bytes20(node.b32Address << 96),
            node.balanceBeddows,
            MultisigKeys(node.mandatoryKeys, node.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_claimMultisigAccount_RevertWhenValidProofInvalidSig() public {
        uint256 accountIndex = 50;
        Utils.MerkleTreeNode memory node = getMerkleTree().node[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](node.numberOfSignatures);

        for (uint256 i; i < node.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        ed25519Signatures[0].r = bytes32AddOne(ed25519Signatures[0].r);

        vm.expectRevert("Invalid Signature");
        l2Claim.claimMultisigAccount(
            node.proof,
            bytes20(node.b32Address << 96),
            node.balanceBeddows,
            MultisigKeys(node.mandatoryKeys, node.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_claimMultisigAccount_RevertWhenValidProofInsufficientSig() public {
        uint256 accountIndex = 50;
        Utils.MerkleTreeNode memory node = getMerkleTree().node[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](node.numberOfSignatures);

        for (uint256 i; i < node.numberOfSignatures - 1; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        vm.expectRevert("Invalid Signature");

        l2Claim.claimMultisigAccount(
            node.proof,
            bytes20(node.b32Address << 96),
            node.balanceBeddows,
            MultisigKeys(node.mandatoryKeys, node.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_claimMultisigAccount_RevertWhenSigLengthLongerThanManKeysAndOpKeys() public {
        uint256 accountIndex = 50;
        Utils.MerkleTreeNode memory node = getMerkleTree().node[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](node.numberOfSignatures + 1);

        for (uint256 i; i < node.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        vm.expectRevert("Invalid Signature Length");
        l2Claim.claimMultisigAccount(
            node.proof,
            bytes20(node.b32Address << 96),
            node.balanceBeddows,
            MultisigKeys(node.mandatoryKeys, node.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    // numberOfSignatures are calculated by number of non-empty signatures, hence providing more signature than needed
    // would result in sig error
    function test_claimMultisigAccount_RevertWhenSigOversupplied() public {
        uint256 accountIndex = 51;
        Utils.MerkleTreeNode memory node = getMerkleTree().node[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](node.mandatoryKeys.length + node.optionalKeys.length);

        for (uint256 i; i < ed25519Signatures.length; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        vm.expectRevert("Invalid Signature");
        l2Claim.claimMultisigAccount(
            node.proof,
            bytes20(node.b32Address << 96),
            node.balanceBeddows,
            MultisigKeys(node.mandatoryKeys, node.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_claimMultisigAccount_SuccessClaim_3M() public {
        uint256 accountIndex = 50;
        Utils.MerkleTreeNode memory node = getMerkleTree().node[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](node.numberOfSignatures);

        for (uint256 i; i < node.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        l2Claim.claimMultisigAccount(
            node.proof,
            bytes20(node.b32Address << 96),
            node.balanceBeddows,
            MultisigKeys(node.mandatoryKeys, node.optionalKeys),
            address(this),
            ed25519Signatures
        );
        assertEq(lsk.balanceOf(address(this)), node.balanceBeddows * l2Claim.LSK_MULTIPLIER());
    }

    function test_claimMultisigAccount_SuccessClaim_1M_2O() public {
        uint256 accountIndex = 51;
        Utils.MerkleTreeNode memory node = getMerkleTree().node[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](node.mandatoryKeys.length + node.optionalKeys.length);

        for (uint256 i; i < ed25519Signatures.length; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        ed25519Signatures[1] = ED25519Signature(bytes32(0), bytes32(0));

        l2Claim.claimMultisigAccount(
            node.proof,
            bytes20(node.b32Address << 96),
            node.balanceBeddows,
            MultisigKeys(node.mandatoryKeys, node.optionalKeys),
            address(this),
            ed25519Signatures
        );

        assertEq(lsk.balanceOf(address(this)), node.balanceBeddows * l2Claim.LSK_MULTIPLIER());
    }

    function test_claimMultisigAccount_SuccessClaim_3M_3O() public {
        uint256 accountIndex = 52;
        Utils.MerkleTreeNode memory node = getMerkleTree().node[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](node.mandatoryKeys.length + node.optionalKeys.length);

        for (uint256 i; i < ed25519Signatures.length; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        ed25519Signatures[4] = ED25519Signature(bytes32(0), bytes32(0));

        l2Claim.claimMultisigAccount(
            node.proof,
            bytes20(node.b32Address << 96),
            node.balanceBeddows,
            MultisigKeys(node.mandatoryKeys, node.optionalKeys),
            address(this),
            ed25519Signatures
        );

        assertEq(lsk.balanceOf(address(this)), node.balanceBeddows * l2Claim.LSK_MULTIPLIER());
    }

    function test_claimMultisigAccount_SuccessClaim_64M() public {
        uint256 accountIndex = 53;
        Utils.MerkleTreeNode memory node = getMerkleTree().node[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](node.mandatoryKeys.length + node.optionalKeys.length);

        for (uint256 i; i < ed25519Signatures.length; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        l2Claim.claimMultisigAccount(
            node.proof,
            bytes20(node.b32Address << 96),
            node.balanceBeddows,
            MultisigKeys(node.mandatoryKeys, node.optionalKeys),
            address(this),
            ed25519Signatures
        );

        assertEq(lsk.balanceOf(address(this)), node.balanceBeddows * l2Claim.LSK_MULTIPLIER());
    }

    function test_claimMultisigAccount_RevertWhenAlreadyClaimed() public {
        test_claimMultisigAccount_SuccessClaim_3M();

        vm.expectRevert("Already Claimed");
        test_claimMultisigAccount_SuccessClaim_3M();
    }
}
