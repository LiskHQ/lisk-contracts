// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Test, console, stdJson } from "forge-std/Test.sol";
import { L2Claim, ED25519Signature, MultisigKeys } from "src/L2/L2Claim.sol";
import { Utils } from "script/contracts/Utils.sol";
import { MockERC20 } from "test/mock/MockERC20.sol";

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

contract L2ClaimHelper is Test {
    using stdJson for string;

    Utils public utils;

    ERC20 public lsk;
    L2Claim public l2ClaimImplementation;
    L2Claim public l2Claim;
    address public daoAddress;

    string public signatureJson;
    string public merkleLeavesJson;
    string public merkleRootJson;
    bytes32 public merkleRootHex;

    /// @notice The destination address for claims as `address(uint160(uint256(keccak256("foundry default caller"))))`
    ///         and `nonce=2`.
    address public constant RECIPIENT_ADDRESS = address(0x34A1D3fff3958843C43aD80F30b94c510645C316);

    /// @notice recover LSK tokens after 2 years
    uint256 public constant RECOVER_PERIOD = 730 days;

    /// @notice initial balance of claim contract
    uint256 public constant INIT_BALANCE = 10_000_000 ether;

    function getSignature(uint256 _index) internal view returns (Signature memory) {
        return abi.decode(
            signatureJson.parseRaw(string(abi.encodePacked(".[", Strings.toString(_index), "]"))), (Signature)
        );
    }

    // get detailed MerkleTree, which is located in `test/L2/data` and only being used by testing scripts
    function getMerkleLeaves() internal view returns (MerkleLeaves memory) {
        return abi.decode(merkleLeavesJson.parseRaw("."), (MerkleLeaves));
    }

    // get MerkleRoot struct
    function getMerkleRoot() internal view returns (Utils.MerkleRoot memory) {
        return abi.decode(merkleRootJson.parseRaw("."), (Utils.MerkleRoot));
    }

    // helper function to "invalidate" a proof or sig. (e.g. 0xabcdef -> 0xabcdf0)
    function bytes32AddOne(bytes32 _value) internal pure returns (bytes32) {
        return bytes32(uint256(_value) + 1);
    }

    function setUpL2Claim() internal {
        lsk = new MockERC20(INIT_BALANCE);
        (daoAddress,) = makeAddrAndKey("DAO");

        console.log("L2ClaimTest Address is: %s", address(this));

        // read Pre-signed Signatures, Merkle Leaves and a Merkle Root in a json format from different files
        string memory rootPath = string.concat(vm.projectRoot(), "/test/L2/data");
        signatureJson = vm.readFile(string.concat(rootPath, "/signatures.json"));
        merkleLeavesJson = vm.readFile(string.concat(rootPath, "/merkle-leaves.json"));
        merkleRootJson = vm.readFile(string.concat(rootPath, "/merkle-root.json"));

        // get MerkleRoot struct
        Utils.MerkleRoot memory merkleRoot = getMerkleRoot();
        merkleRootHex = merkleRoot.merkleRoot;

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
}
