// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { Test, console, stdJson } from "forge-std/Test.sol";
import { L2Claim, ED25519Signature, MultisigKeys } from "src/L2/L2Claim.sol";
import { Utils } from "script/contracts/Utils.sol";
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

/// @notice This struct stores merkleTree leaf.
/// @dev Limitation of parseJSON, only bytes32 is supported.
///      To convert b32Address back to bytes20, shift 96 bits to the left.
///      i.e. bytes20(leaf.b32Address << 96)
struct MerkleTreeLeaf {
    bytes32 b32Address;
    uint64 balanceBeddows;
    bytes32[] mandatoryKeys;
    uint256 numberOfSignatures;
    bytes32[] optionalKeys;
    bytes32[] proof;
}

/// @notice This struct is used to read MerkleLeaves from JSON file.
struct MerkleLeaves {
    MerkleTreeLeaf[] leaves;
}

contract L2ClaimV2Mock is L2Claim {
    function initializeV2(uint256 _recoverPeriodTimestamp) public reinitializer(2) {
        recoverPeriodTimestamp = _recoverPeriodTimestamp;
        version = "2.0.0";
    }

    function onlyV2() public pure returns (string memory) {
        return "Hello from V2";
    }
}

contract L2ClaimTest is Test {
    using stdJson for string;

    // recover LSK tokens after 2 years
    uint256 public constant RECOVER_PERIOD = 730 days;

    ERC20 public lsk;
    L2Claim public l2ClaimImplementation;
    L2Claim public l2Claim;
    Utils public utils;

    string public signatureJson;
    string public MerkleLeavesJson;
    string public MerkleRootJson;

    address public daoAddress;

    function getSignature(uint256 _index) internal view returns (Signature memory) {
        return abi.decode(
            signatureJson.parseRaw(string(abi.encodePacked(".[", Strings.toString(_index), "]"))), (Signature)
        );
    }

    // get detailed MerkleTree, which is located in `test/L2/data` and only being used by testing scripts
    function getMerkleLeaves() internal view returns (MerkleLeaves memory) {
        return abi.decode(MerkleLeavesJson.parseRaw("."), (MerkleLeaves));
    }

    // get MerkleRoot struct
    function getMerkleRoot() internal view returns (Utils.MerkleRoot memory) {
        return abi.decode(MerkleRootJson.parseRaw("."), (Utils.MerkleRoot));
    }

    // helper function to "invalidate" a proof or sig. (e.g. 0xabcdef -> 0xabcdf0)
    function bytes32AddOne(bytes32 _value) internal pure returns (bytes32) {
        return bytes32(uint256(_value) + 1);
    }

    function claimRegularAccount(uint256 _accountIndex) internal {
        uint256 originalBalance = lsk.balanceOf(address(this));
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[_accountIndex];
        Signature memory signature = getSignature(_accountIndex);

        bytes32 pubKey = signature.sigs[0].pubKey;

        // check that the LSKClaimed event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Claim.LSKClaimed(bytes20(sha256(abi.encode(pubKey))), address(this), leaf.balanceBeddows);

        l2Claim.claimRegularAccount(
            leaf.proof,
            pubKey,
            leaf.balanceBeddows,
            address(this),
            ED25519Signature(signature.sigs[0].r, signature.sigs[0].s)
        );

        assertEq(lsk.balanceOf(address(this)), originalBalance + leaf.balanceBeddows * l2Claim.LSK_MULTIPLIER());
        assertEq(l2Claim.claimedTo(bytes20(sha256(abi.encode(pubKey)))), address(this));
    }

    function setUp() public {
        utils = new Utils();
        lsk = new MockERC20(10_000_000 * 10 ** 18);
        (daoAddress,) = makeAddrAndKey("DAO");

        console.log("L2ClaimTest Address is: %s", address(this));

        // read Pre-signed Signatures, Merkle Leaves and a Merkle Root in a json format from different files
        string memory rootPath = string.concat(vm.projectRoot(), "/test/L2/data");
        signatureJson = vm.readFile(string.concat(rootPath, "/signatures.json"));
        MerkleLeavesJson = vm.readFile(string.concat(rootPath, "/merkle-leaves.json"));
        MerkleRootJson = vm.readFile(string.concat(rootPath, "/merkle-root.json"));

        // get MerkleRoot struct
        Utils.MerkleRoot memory merkleRoot = getMerkleRoot();

        // deploy L2Claim Implementation contract
        l2ClaimImplementation = new L2Claim();

        // deploy L2Claim contract via Proxy and initialize it at the same time
        l2Claim = L2Claim(
            address(
                new ERC1967Proxy(
                    address(l2ClaimImplementation),
                    abi.encodeWithSelector(
                        l2Claim.initialize.selector,
                        address(lsk),
                        merkleRoot.merkleRoot,
                        block.timestamp + RECOVER_PERIOD
                    )
                )
            )
        );
        assertEq(address(l2Claim.l2LiskToken()), address(lsk));
        assertEq(l2Claim.merkleRoot(), merkleRoot.merkleRoot);

        // send bunch of MockLSK to Claim contract
        lsk.transfer(address(l2Claim), lsk.balanceOf(address(this)));
    }

    function test_Initialize_RevertWhenL2LiskTokenIsZero() public {
        l2Claim = L2Claim(address(new ERC1967Proxy(address(l2ClaimImplementation), "")));
        Utils.MerkleRoot memory merkleRoot = getMerkleRoot();

        vm.expectRevert("L2Claim: L2 Lisk Token address cannot be zero");
        l2Claim.initialize(address(0), merkleRoot.merkleRoot, block.timestamp + RECOVER_PERIOD);
    }

    function test_Initialize_RevertWhenMerkleRootIsZero() public {
        l2Claim = L2Claim(address(new ERC1967Proxy(address(l2ClaimImplementation), "")));

        vm.expectRevert("L2Claim: Merkle Root cannot be zero");
        l2Claim.initialize(address(lsk), bytes32(0), block.timestamp + RECOVER_PERIOD);
    }

    function test_Initialize_RevertWhenRecoveredPeriodIsNotInFuture() public {
        l2Claim = L2Claim(address(new ERC1967Proxy(address(l2ClaimImplementation), "")));
        Utils.MerkleRoot memory merkleRoot = getMerkleRoot();

        // recover period is now, hence it should still pass
        l2Claim.initialize(address(lsk), merkleRoot.merkleRoot, block.timestamp);
        assertEq(l2Claim.recoverPeriodTimestamp(), block.timestamp);

        l2Claim = L2Claim(address(new ERC1967Proxy(address(l2ClaimImplementation), "")));

        // recover period is in the past, hence it should revert
        vm.expectRevert("L2Claim: recover period must be in the future");
        l2Claim.initialize(address(lsk), merkleRoot.merkleRoot, block.timestamp - 1);
    }

    function test_Initialize_RevertWhenCalledAtImplementationContract() public {
        vm.expectRevert();
        l2ClaimImplementation.initialize(address(lsk), bytes32(0), block.timestamp + RECOVER_PERIOD);
    }

    function test_Version() public {
        assertEq(l2Claim.version(), "1.0.0");
    }

    function test_ClaimRegularAccount_RevertWhenZeroLengthProof() public {
        uint256 accountIndex = 0;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        vm.expectRevert("L2Claim: proof array is empty");
        l2Claim.claimRegularAccount(
            new bytes32[](0),
            bytes32(signature.sigs[0].pubKey),
            leaf.balanceBeddows,
            address(this),
            ED25519Signature(signature.sigs[0].r, signature.sigs[0].s)
        );
    }

    function test_ClaimRegularAccount_RevertWhenInvalidProof() public {
        uint256 accountIndex = 0;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        leaf.proof[0] = bytes32AddOne(leaf.proof[0]);

        vm.expectRevert("L2Claim: invalid Proof");
        l2Claim.claimRegularAccount(
            leaf.proof,
            bytes32(signature.sigs[0].pubKey),
            leaf.balanceBeddows,
            address(this),
            ED25519Signature(signature.sigs[0].r, signature.sigs[0].s)
        );
    }

    function test_ClaimRegularAccount_RevertWhenValidProofInvalidSig() public {
        uint256 accountIndex = 0;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        vm.expectRevert();
        l2Claim.claimRegularAccount(
            leaf.proof,
            bytes32(signature.sigs[0].pubKey),
            leaf.balanceBeddows,
            address(this),
            ED25519Signature(bytes32AddOne(signature.sigs[0].r), signature.sigs[0].s)
        );

        vm.expectRevert();
        l2Claim.claimRegularAccount(
            leaf.proof,
            bytes32(signature.sigs[0].pubKey),
            leaf.balanceBeddows,
            address(this),
            ED25519Signature(signature.sigs[0].r, bytes32AddOne(signature.sigs[0].s))
        );
    }

    function test_ClaimRegularAccount_SuccessClaim() public {
        for (uint256 i; i < 50; i++) {
            claimRegularAccount(i);
        }
    }

    function test_ClaimRegularAccount_RevertWhenAlreadyClaimed() public {
        uint256 claimIndex = 0;
        claimRegularAccount(claimIndex);

        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[claimIndex];
        Signature memory signature = getSignature(claimIndex);

        vm.expectRevert("L2Claim: already Claimed");
        l2Claim.claimRegularAccount(
            leaf.proof,
            bytes32(signature.sigs[0].pubKey),
            leaf.balanceBeddows,
            address(this),
            ED25519Signature(signature.sigs[0].r, signature.sigs[0].s)
        );
    }

    function test_ClaimMultisigAccount_RevertWhenZeroLengthProof() public {
        uint256 accountIndex = 50;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](leaf.numberOfSignatures);

        for (uint256 i; i < leaf.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        vm.expectRevert("L2Claim: proof array is empty");
        l2Claim.claimMultisigAccount(
            new bytes32[](0),
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    // multisig settings refers to: lisk-merkle-tree-builder/data/example/create-balances.ts
    function test_ClaimMultisigAccount_RevertWhenIncorrectProof() public {
        uint256 accountIndex = 50;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](leaf.numberOfSignatures);

        for (uint256 i; i < leaf.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        leaf.proof[0] = bytes32AddOne(leaf.proof[0]);

        vm.expectRevert("L2Claim: invalid Proof");
        l2Claim.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_ClaimMultisigAccount_RevertWhenValidProofInvalidMandatorySig() public {
        uint256 accountIndex = 50;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](leaf.numberOfSignatures);

        for (uint256 i; i < leaf.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        ed25519Signatures[0].r = bytes32AddOne(ed25519Signatures[0].r);

        vm.expectRevert("L2Claim: invalid signature when verifying with mandatoryKeys[]");
        l2Claim.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_ClaimMultisigAccount_RevertWhenValidProofInvalidOptionalSig() public {
        uint256 accountIndex = 51;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](leaf.mandatoryKeys.length + leaf.optionalKeys.length);

        for (uint256 i; i < leaf.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        // shifting byte of the last sig (i.e. one of the optionalKey sig)
        ed25519Signatures[leaf.numberOfSignatures - 1].r =
            bytes32AddOne(ed25519Signatures[leaf.numberOfSignatures - 1].r);

        vm.expectRevert("L2Claim: invalid signature when verifying with optionalKeys[]");
        l2Claim.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_ClaimMultisigAccount_RevertWhenValidProofInsufficientSig() public {
        uint256 accountIndex = 50;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](leaf.numberOfSignatures);

        for (uint256 i; i < leaf.numberOfSignatures - 1; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        vm.expectRevert("L2Claim: invalid signature when verifying with mandatoryKeys[]");

        l2Claim.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_ClaimMultisigAccount_RevertWhenSigLengthIsZero() public {
        // claim as multisig account
        uint256 accountIndex = 50;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];

        vm.expectRevert("L2Claim: signatures array is empty");
        l2Claim.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(new bytes32[](0), new bytes32[](0)),
            address(this),
            new ED25519Signature[](0)
        );
    }

    function test_ClaimMultisigAccount_RevertWhenClaimAsRegularAccount() public {
        // claim as regular account
        uint256 accountIndex = 0;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];

        vm.expectRevert("L2Claim: signatures array is empty");
        l2Claim.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(new bytes32[](0), new bytes32[](0)),
            address(this),
            new ED25519Signature[](0)
        );
    }

    function test_ClaimMultisigAccount_RevertWhenSigLengthLongerThanManKeysAndOpKeys() public {
        uint256 accountIndex = 50;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](leaf.numberOfSignatures + 1);

        for (uint256 i; i < leaf.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        vm.expectRevert("L2Claim: signatures array has invalid length");
        l2Claim.claimMultisigAccount(
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
    function test_ClaimMultisigAccount_RevertWhenSigOversupplied() public {
        // 1m + 2o, numberOfSignatures = 2
        uint256 accountIndex = 51;

        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](leaf.mandatoryKeys.length + leaf.optionalKeys.length);

        for (uint256 i; i < ed25519Signatures.length; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        vm.expectRevert("L2Claim: invalid signature when verifying with mandatoryKeys[]");
        l2Claim.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_ClaimMultisigAccount_SuccessClaim_3M() public {
        uint256 accountIndex = 50;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](leaf.numberOfSignatures);

        for (uint256 i; i < leaf.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        bytes20 lskAddress = bytes20(leaf.b32Address << 96);

        // check that the LSKClaimed event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Claim.LSKClaimed(lskAddress, address(this), leaf.balanceBeddows);

        l2Claim.claimMultisigAccount(
            leaf.proof,
            lskAddress,
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
        assertEq(lsk.balanceOf(address(this)), leaf.balanceBeddows * l2Claim.LSK_MULTIPLIER());
        assertEq(l2Claim.claimedTo(lskAddress), address(this));
    }

    function test_ClaimMultisigAccount_SuccessClaim_1M_2O() public {
        uint256 accountIndex = 51;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](leaf.mandatoryKeys.length + leaf.optionalKeys.length);

        for (uint256 i; i < ed25519Signatures.length; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        ed25519Signatures[1] = ED25519Signature(bytes32(0), bytes32(0));

        bytes20 lskAddress = bytes20(leaf.b32Address << 96);

        // check that the LSKClaimed event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Claim.LSKClaimed(lskAddress, address(this), leaf.balanceBeddows);

        l2Claim.claimMultisigAccount(
            leaf.proof,
            lskAddress,
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );

        assertEq(lsk.balanceOf(address(this)), leaf.balanceBeddows * l2Claim.LSK_MULTIPLIER());
        assertEq(l2Claim.claimedTo(lskAddress), address(this));
    }

    function test_ClaimMultisigAccount_SuccessClaim_3M_3O() public {
        uint256 accountIndex = 52;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](leaf.mandatoryKeys.length + leaf.optionalKeys.length);

        for (uint256 i; i < ed25519Signatures.length; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        ed25519Signatures[4] = ED25519Signature(bytes32(0), bytes32(0));

        bytes20 lskAddress = bytes20(leaf.b32Address << 96);

        // check that the LSKClaimed event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Claim.LSKClaimed(lskAddress, address(this), leaf.balanceBeddows);

        l2Claim.claimMultisigAccount(
            leaf.proof,
            lskAddress,
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );

        assertEq(lsk.balanceOf(address(this)), leaf.balanceBeddows * l2Claim.LSK_MULTIPLIER());
        assertEq(l2Claim.claimedTo(lskAddress), address(this));
    }

    function test_ClaimMultisigAccount_SuccessClaim_64M() public {
        uint256 accountIndex = 53;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures =
            new ED25519Signature[](leaf.mandatoryKeys.length + leaf.optionalKeys.length);

        for (uint256 i; i < ed25519Signatures.length; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        bytes20 lskAddress = bytes20(leaf.b32Address << 96);

        // check that the LSKClaimed event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Claim.LSKClaimed(lskAddress, address(this), leaf.balanceBeddows);

        l2Claim.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );

        assertEq(lsk.balanceOf(address(this)), leaf.balanceBeddows * l2Claim.LSK_MULTIPLIER());
        assertEq(l2Claim.claimedTo(lskAddress), address(this));
    }

    function test_ClaimMultisigAccount_RevertWhenAlreadyClaimed() public {
        test_ClaimMultisigAccount_SuccessClaim_3M();

        // copy-and-paste test_ClaimMultisigAccount_SuccessClaim_3M(), such that the `vm.expectRevert` could be
        // correctly placed
        uint256 accountIndex = 50;
        MerkleTreeLeaf memory leaf = getMerkleLeaves().leaves[accountIndex];
        Signature memory signature = getSignature(accountIndex);

        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](leaf.numberOfSignatures);

        for (uint256 i; i < leaf.numberOfSignatures; i++) {
            ed25519Signatures[i] = ED25519Signature(signature.sigs[i].r, signature.sigs[i].s);
        }

        vm.expectRevert("L2Claim: already Claimed");
        l2Claim.claimMultisigAccount(
            leaf.proof,
            bytes20(leaf.b32Address << 96),
            leaf.balanceBeddows,
            MultisigKeys(leaf.mandatoryKeys, leaf.optionalKeys),
            address(this),
            ed25519Signatures
        );
    }

    function test_SetDAOAddress_RevertWhenNotCalledByOwner() public {
        address nobody = vm.addr(1);

        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2Claim.setDAOAddress(daoAddress);
    }

    function test_SetDAOAddress_RevertWhenSettingDAOAddressToZero() public {
        vm.expectRevert("L2Claim: DAO Address cannot be zero");
        l2Claim.setDAOAddress(address(0));
    }

    function test_SetDAOAddress_RevertWhenDAOAddressAlreadyBeenSet() public {
        l2Claim.setDAOAddress(daoAddress);

        vm.expectRevert("L2Claim: DAO Address has already been set");
        l2Claim.setDAOAddress(daoAddress);
    }

    function test_SetDAOAddress_SuccessSet() public {
        // check that the DaoAddressSet event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Claim.DaoAddressSet(daoAddress);

        l2Claim.setDAOAddress(daoAddress);
        assertEq(l2Claim.daoAddress(), daoAddress);
    }

    function test_RecoverLSK_RevertWhenRecoverPeriodNotReached() public {
        l2Claim.setDAOAddress(daoAddress);
        vm.expectRevert("L2Claim: recover period not reached");
        l2Claim.recoverLSK();
    }

    function test_RecoverLSK_RevertWhenNotCalledByOwner() public {
        l2Claim.setDAOAddress(daoAddress);
        address nobody = vm.addr(1);

        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2Claim.recoverLSK();
    }

    function test_RecoverLSK_RevertWhenDAOAddressNotSet() public {
        vm.warp(RECOVER_PERIOD + 1 seconds);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        l2Claim.recoverLSK();
    }

    function test_RecoverLSK_SuccessRecover() public {
        l2Claim.setDAOAddress(daoAddress);
        uint256 claimContractBalance = lsk.balanceOf(address(l2Claim));
        assert(claimContractBalance > 0);

        vm.warp(RECOVER_PERIOD + 1 seconds);

        // check that the ClaimingEnded event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Claim.ClaimingEnded();

        l2Claim.recoverLSK();
        assertEq(lsk.balanceOf(daoAddress), claimContractBalance);
        assertEq(lsk.balanceOf(address(l2Claim)), 0);
    }

    function test_RecoverLSK_DifferentTimestamps() public {
        l2Claim.setDAOAddress(daoAddress);
        uint256 claimContractBalance = lsk.balanceOf(address(l2Claim));
        assert(claimContractBalance > 0);

        // try to call recoverLSK right after initialization
        vm.expectRevert("L2Claim: recover period not reached");
        l2Claim.recoverLSK();

        // try to call recoverLSK in the middle of the recover period
        vm.warp(RECOVER_PERIOD / 2);
        vm.expectRevert("L2Claim: recover period not reached");
        l2Claim.recoverLSK();

        // try to call recoverLSK just before the end of the recover period
        vm.warp(RECOVER_PERIOD - 1 seconds);
        vm.expectRevert("L2Claim: recover period not reached");
        l2Claim.recoverLSK();

        // try to call recoverLSK exactly at the end of the recover period
        vm.warp(RECOVER_PERIOD);
        vm.expectRevert("L2Claim: recover period not reached");
        l2Claim.recoverLSK();

        // try to call recoverLSK after the end of the recover period
        vm.warp(RECOVER_PERIOD + 1 seconds);

        // check that the ClaimingEnded event is emitted
        vm.expectEmit(true, true, true, true);
        emit L2Claim.ClaimingEnded();

        l2Claim.recoverLSK();
        assertEq(lsk.balanceOf(daoAddress), claimContractBalance);
        assertEq(lsk.balanceOf(address(l2Claim)), 0);
    }

    function test_TransferOwnership() public {
        address newOwner = vm.addr(1);

        l2Claim.transferOwnership(newOwner);
        assertEq(l2Claim.owner(), address(this));

        vm.prank(newOwner);
        l2Claim.acceptOwnership();
        assertEq(l2Claim.owner(), newOwner);
    }

    function test_TransferOwnership_RevertWhenNotCalledByOwner() public {
        address newOwner = vm.addr(1);
        address nobody = vm.addr(2);

        // owner is this contract
        assertEq(l2Claim.owner(), address(this));

        // address nobody is not the owner so it cannot call transferOwnership
        vm.startPrank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2Claim.transferOwnership(newOwner);
        vm.stopPrank();
    }

    function test_TransferOwnership_RevertWhenNotCalledByPendingOwner() public {
        address newOwner = vm.addr(1);

        l2Claim.transferOwnership(newOwner);
        assertEq(l2Claim.owner(), address(this));

        address nobody = vm.addr(2);
        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2Claim.acceptOwnership();
    }

    function test_UpgradeToAndCall_RevertWhenNotOwner() public {
        // deploy L2Claim Implementation contract
        L2ClaimV2Mock l2ClaimV2Implementation = new L2ClaimV2Mock();
        address nobody = vm.addr(1);

        vm.prank(nobody);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nobody));
        l2Claim.upgradeToAndCall(address(l2ClaimV2Implementation), "");
    }

    function test_UpgradeToAndCall_SuccessUpgrade() public {
        // deploy L2ClaimV2 Implementation contract
        L2ClaimV2Mock l2ClaimV2Implementation = new L2ClaimV2Mock();
        Utils.MerkleRoot memory merkleRoot = getMerkleRoot();

        // claim Period is now 20 years
        uint256 newRecoverPeriodTimestamp = block.timestamp + 365 days * 20;

        // upgrade contract, and also change some variables by reinitialize
        l2Claim.upgradeToAndCall(
            address(l2ClaimV2Implementation),
            abi.encodeWithSelector(l2ClaimV2Implementation.initializeV2.selector, newRecoverPeriodTimestamp)
        );

        // wrap L2Claim Proxy with new contract
        L2ClaimV2Mock l2ClaimV2 = L2ClaimV2Mock(address(l2Claim));

        // LSK Token and MerkleRoot unchanged
        assertEq(address(l2ClaimV2.l2LiskToken()), address(lsk));
        assertEq(l2ClaimV2.merkleRoot(), merkleRoot.merkleRoot);

        // version of L2Claim changed to 2.0.0
        assertEq(l2ClaimV2.version(), "2.0.0");

        // new Timestamp changed by reinitializer
        assertEq(l2ClaimV2.recoverPeriodTimestamp(), newRecoverPeriodTimestamp);

        // new function introduced
        assertEq(l2ClaimV2.onlyV2(), "Hello from V2");

        // assure cannot re-reinitialize
        vm.expectRevert();
        l2ClaimV2.initializeV2(newRecoverPeriodTimestamp + 1);
    }
}
