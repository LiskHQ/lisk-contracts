// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Test, console, stdJson } from "forge-std/Test.sol";
import { L2Claim, ED25519Signature, MultisigKeys } from "src/L2/L2Claim.sol";
import { L2LiskToken } from "src/L2/L2LiskToken.sol";
import { Utils } from "script/Utils.sol";
import { MockERC20 } from "../mock/MockERC20.sol";
import { UUPSProxy } from "src/utils/UUPSProxy.sol";

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

    UUPSProxy public proxy;
    L2Claim public l2Claim;
    L2Claim public l2ClaimProxy;

    Utils public utils;
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
        l2Claim = new L2Claim();

        // deploy Proxy contract
        l2ClaimProxy = L2Claim(address(new UUPSProxy(address(l2Claim), "")));

        // Send bunch of MockLSK to Claim Contract
        lsk = new MockERC20(10_000_000 * 10 ** 18);
        lsk.transfer(address(l2ClaimProxy), lsk.balanceOf(address(this)));

        l2ClaimProxy.initialize(address(lsk), rawTxDetail.merkleRoot);

        assertEq(address(l2ClaimProxy.l2LiskToken()), address(lsk));
        assertEq(l2ClaimProxy.merkleRoot(), rawTxDetail.merkleRoot);
    }

    function test_claimRegularAccount_RevertWhenInvalidProof() public {
        uint256 accountIndex = 0;
        Utils.MerkleTreeLeaf memory leaf = getMerkleTree().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        leaf.proof[0] = bytes32AddOne(leaf.proof[0]);

        vm.expectRevert("Invalid Proof");
        l2ClaimProxy.claimRegularAccount(
            leaf.proof,
            bytes32(signature.sigs[0].pubKey),
            leaf.balanceBeddows,
            address(this),
            ED25519Signature(signature.sigs[0].r, signature.sigs[0].s)
        );
    }

    function test_claimRegularAccount_RevertWhenValidProofInvalidSig() public {
        uint256 accountIndex = 0;
        Utils.MerkleTreeLeaf memory leaf = getMerkleTree().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        vm.expectRevert();
        l2ClaimProxy.claimRegularAccount(
            leaf.proof,
            bytes32(signature.sigs[0].pubKey),
            leaf.balanceBeddows,
            address(this),
            ED25519Signature(bytes32AddOne(signature.sigs[0].r), signature.sigs[0].s)
        );

        vm.expectRevert();
        l2ClaimProxy.claimRegularAccount(
            leaf.proof,
            bytes32(signature.sigs[0].pubKey),
            leaf.balanceBeddows,
            address(this),
            ED25519Signature(signature.sigs[0].r, bytes32AddOne(signature.sigs[0].s))
        );
    }

    function claimRegularAccount(uint256 _accountIndex) internal {
        uint256 originalBalance = lsk.balanceOf(address(this));
        Utils.MerkleTreeLeaf memory leaf = getMerkleTree().leaves[_accountIndex];
        Signature memory signature = getSignature(_accountIndex);

        l2ClaimProxy.claimRegularAccount(
            leaf.proof,
            bytes32(signature.sigs[0].pubKey),
            leaf.balanceBeddows,
            address(this),
            ED25519Signature(signature.sigs[0].r, signature.sigs[0].s)
        );

        assertEq(lsk.balanceOf(address(this)), originalBalance + leaf.balanceBeddows * l2ClaimProxy.LSK_MULTIPLIER());
    }

    function test_claimRegularAccount_SuccessClaim() public {
        for (uint256 i; i < 50; i++) {
            console.log(i);
            claimRegularAccount(i);
        }
    }

    function test_claimRegularAccount_RevertWhenAlreadyClaimed() public {
        uint256 claimIndex = 0;
        claimRegularAccount(claimIndex);

        Utils.MerkleTreeLeaf memory leaf = getMerkleTree().leaves[claimIndex];
        Signature memory signature = getSignature(claimIndex);

        vm.expectRevert("Already Claimed");
        l2ClaimProxy.claimRegularAccount(
            leaf.proof,
            bytes32(signature.sigs[0].pubKey),
            leaf.balanceBeddows,
            address(this),
            ED25519Signature(signature.sigs[0].r, signature.sigs[0].s)
        );
    }

    // Multisig settings refers to: lisk-merkle-tree-builder/data/example/create-balances.ts
    function test_claimMultisigAccount_RevertWhenIncorrectProof() public {
        uint256 accountIndex = 50;
        Utils.MerkleTreeLeaf memory leaf = getMerkleTree().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](leaf.numberOfSignatures);

        for (uint256 i; i < leaf.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        leaf.proof[0] = bytes32AddOne(leaf.proof[0]);

        vm.expectRevert("Invalid Proof");
        l2ClaimProxy.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_claimMultisigAccount_RevertWhenValidProofInvalidMandatorySig() public {
        uint256 accountIndex = 50;
        Utils.MerkleTreeLeaf memory leaf = getMerkleTree().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](leaf.numberOfSignatures);

        for (uint256 i; i < leaf.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        ed25519Signatures[0].r = bytes32AddOne(ed25519Signatures[0].r);

        vm.expectRevert("Invalid signature for mandatoryKey");
        l2ClaimProxy.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_claimMultisigAccount_RevertWhenValidProofInvalidOptionalSig() public {
        uint256 accountIndex = 51;
        Utils.MerkleTreeLeaf memory leaf = getMerkleTree().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](leaf.mandatoryKeys.length + leaf.optionalKeys.length);

        for (uint256 i; i < leaf.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        // Shifting byte of the last sig (i.e. one of the optionalKey sig)
        ed25519Signatures[leaf.numberOfSignatures - 1].r =
            bytes32AddOne(ed25519Signatures[leaf.numberOfSignatures - 1].r);

        vm.expectRevert("Invalid signature for optionalKey");
        l2ClaimProxy.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_claimMultisigAccount_RevertWhenValidProofInsufficientSig() public {
        uint256 accountIndex = 50;
        Utils.MerkleTreeLeaf memory leaf = getMerkleTree().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](leaf.numberOfSignatures);

        for (uint256 i; i < leaf.numberOfSignatures - 1; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        vm.expectRevert("Invalid signature for mandatoryKey");

        l2ClaimProxy.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_claimMultisigAccount_RevertWhenSigLengthLongerThanManKeysAndOpKeys() public {
        uint256 accountIndex = 50;
        Utils.MerkleTreeLeaf memory leaf = getMerkleTree().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](leaf.numberOfSignatures + 1);

        for (uint256 i; i < leaf.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        vm.expectRevert("Signatures array has invalid length");
        l2ClaimProxy.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    // numberOfSignatures are calculated by number of non-empty signatures, hence providing more signature than needed
    // would result in sig error at mandatoryKey stage
    function test_claimMultisigAccount_RevertWhenSigOversupplied() public {
        // 1m + 2o, numberOfSignatures = 2
        uint256 accountIndex = 51;

        Utils.MerkleTreeLeaf memory leaf = getMerkleTree().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](leaf.mandatoryKeys.length + leaf.optionalKeys.length);

        for (uint256 i; i < ed25519Signatures.length; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        vm.expectRevert("Invalid signature for mandatoryKey");
        l2ClaimProxy.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_claimMultisigAccount_SuccessClaim_3M() public {
        uint256 accountIndex = 50;
        Utils.MerkleTreeLeaf memory leaf = getMerkleTree().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](leaf.numberOfSignatures);

        for (uint256 i; i < leaf.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        l2ClaimProxy.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
        assertEq(lsk.balanceOf(address(this)), leaf.balanceBeddows * l2ClaimProxy.LSK_MULTIPLIER());
    }

    function test_claimMultisigAccount_SuccessClaim_1M_2O() public {
        uint256 accountIndex = 51;
        Utils.MerkleTreeLeaf memory leaf = getMerkleTree().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](leaf.mandatoryKeys.length + leaf.optionalKeys.length);

        for (uint256 i; i < ed25519Signatures.length; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        ed25519Signatures[1] = ED25519Signature(bytes32(0), bytes32(0));

        l2ClaimProxy.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );

        assertEq(lsk.balanceOf(address(this)), leaf.balanceBeddows * l2ClaimProxy.LSK_MULTIPLIER());
    }

    function test_claimMultisigAccount_SuccessClaim_3M_3O() public {
        uint256 accountIndex = 52;
        Utils.MerkleTreeLeaf memory leaf = getMerkleTree().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](leaf.mandatoryKeys.length + leaf.optionalKeys.length);

        for (uint256 i; i < ed25519Signatures.length; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        ed25519Signatures[4] = ED25519Signature(bytes32(0), bytes32(0));

        l2ClaimProxy.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );

        assertEq(lsk.balanceOf(address(this)), leaf.balanceBeddows * l2ClaimProxy.LSK_MULTIPLIER());
    }

    function test_claimMultisigAccount_SuccessClaim_64M() public {
        uint256 accountIndex = 53;
        Utils.MerkleTreeLeaf memory leaf = getMerkleTree().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](leaf.mandatoryKeys.length + leaf.optionalKeys.length);

        for (uint256 i; i < ed25519Signatures.length; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        l2ClaimProxy.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );

        assertEq(lsk.balanceOf(address(this)), leaf.balanceBeddows * l2ClaimProxy.LSK_MULTIPLIER());
    }

    function test_claimMultisigAccount_RevertWhenAlreadyClaimed() public {
        test_claimMultisigAccount_SuccessClaim_3M();

        vm.expectRevert("Already Claimed");
        test_claimMultisigAccount_SuccessClaim_3M();
    }
}
