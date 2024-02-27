// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Script, console2 } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { L2Claim, ED25519Signature, MultisigKeys } from "src/L2/L2Claim.sol";
import { Signature, MerkleTreeLeaf, MerkleLeaves } from "test/L2/L2Claim.t.sol";
import { MockERC20 } from "../../test/mock/MockERC20.sol";
import "script/Utils.sol";

/// @title L2ClaimTokensScript - L2 Claim Lisk tokens script
/// @notice This contract is used to claim L2 Lisk tokens from the L2 Claim contract for a demonstration purpose.
contract L2ClaimTokensScript is Script {
    using stdJson for string;

    /// @notice Utils contract which provides functions to read and write JSON files containing L1 and L2 addresses.
    Utils internal utils;

    /// @notice LSK Token in L2.
    IERC20 internal lsk;

    /// @notice L2Claim Contract, with address pointing to Proxy.
    L2Claim internal l2Claim;

    /// @notice signatures.json in string format.
    string public signatureJson;

    /// @notice merkleRoot.json in string format.
    string public merkleLeavesJson;

    /// @notice The contract address created by default mnemonic in Anvil/Ganache when nonce=0.
    address public constant destination = address(0x34A1D3fff3958843C43aD80F30b94c510645C316);

    function getSignature(uint256 _index) internal view returns (Signature memory) {
        return abi.decode(signatureJson.parseRaw(string(abi.encodePacked(".[", vm.toString(_index), "]"))), (Signature));
    }

    function getMerkleLeaves() internal view returns (MerkleLeaves memory) {
        return abi.decode(merkleLeavesJson.parseRaw("."), (MerkleLeaves));
    }

    function setUp() public {
        utils = new Utils();
        require(
            keccak256(bytes(utils.getNetworkType())) == keccak256(bytes("devnet")),
            "L2ClaimTokensScript: this script is only available in `devnet`."
        );

        /// @notice Get Merkle Root from /devnet/merkle-root.json
        Utils.MerkleRoot memory merkleRoot = utils.readMerkleRootFile();
        console2.log("MerkleRoot: %s", vm.toString(merkleRoot.merkleRoot));

        /// @notice The L2 Token is a Bridge token with zero totalSupply at the start. In this example script, a ERC20
        /// is deployed to focus on the Claim Process.
        lsk = new MockERC20(10000 ether);

        /// @notice Since another "LSK" token is used, a new L2Claim also need to be deployed
        L2Claim l2ClaimImplementation = new L2Claim();
        ERC1967Proxy l2ClaimProxy = new ERC1967Proxy(
            address(l2ClaimImplementation),
            abi.encodeWithSelector(
                l2ClaimImplementation.initialize.selector,
                address(lsk),
                merkleRoot.merkleRoot,
                block.timestamp + 365 days * 2
            )
        );
        l2Claim = L2Claim(address(l2ClaimProxy));
        lsk.transfer(address(l2Claim), lsk.balanceOf(address(this)));

        string memory rootPath = string.concat(vm.projectRoot(), "/test/L2/data");
        signatureJson = vm.readFile(string.concat(rootPath, "/signatures.json"));
        merkleLeavesJson = vm.readFile(string.concat(rootPath, "/merkleLeaves.json"));
    }

    /// @notice This function submit request to `claimRegularAccount` and `claimMultisigAccount` once to demonstrate
    /// claiming process of both regular account and multisig account
    function run() public {
        console2.log("Destination LSK Balance before Claim:", lsk.balanceOf(destination), "Beddows");

        // Claiming Regular Account
        MerkleTreeLeaf memory regularAccountLeaf = getMerkleLeaves().leaves[0];
        Signature memory regularAccountSignature = getSignature(0);
        console2.log(
            "Claiming Regular Account: id=0, LSK address(hex)=%s, Balance (Old Beddows): %s",
            vm.toString(abi.encodePacked(bytes20(regularAccountLeaf.b32Address << 96))),
            regularAccountLeaf.balanceBeddows
        );
        l2Claim.claimRegularAccount(
            regularAccountLeaf.proof,
            regularAccountSignature.sigs[0].pubKey,
            regularAccountLeaf.balanceBeddows,
            destination,
            ED25519Signature(regularAccountSignature.sigs[0].r, regularAccountSignature.sigs[0].s)
        );
        console2.log("Destination LSK Balance After Regular Account Claim:", lsk.balanceOf(destination), "Beddows");

        // Claiming Multisig Account
        uint256 multisigAccountIndex = 0;
        MerkleTreeLeaf memory multisigAccountLeaf = getMerkleLeaves().leaves[multisigAccountIndex];

        // A non-hardcode way to get the first Multisig Account from Merkle Tree
        while (multisigAccountLeaf.numberOfSignatures == 0) {
            multisigAccountIndex++;
            multisigAccountLeaf = getMerkleLeaves().leaves[multisigAccountIndex];
        }
        Signature memory multisigAccountSignature = getSignature(multisigAccountIndex);

        console2.log(
            "Claiming Multisig Account: id=%s, LSK address(hex)=%s, Balance (Old Beddows): %s",
            multisigAccountIndex,
            vm.toString(abi.encodePacked(bytes20(multisigAccountLeaf.b32Address << 96))),
            multisigAccountLeaf.balanceBeddows
        );

        // Gather just-right amount of signatures from signatures.json
        ED25519Signature[] memory ed25519Signatures = new ED25519Signature[](multisigAccountLeaf.numberOfSignatures);
        for (uint256 i; i < multisigAccountLeaf.numberOfSignatures; i++) {
            ed25519Signatures[i] =
                ED25519Signature(multisigAccountSignature.sigs[i].r, multisigAccountSignature.sigs[i].s);
        }

        l2Claim.claimMultisigAccount(
            multisigAccountLeaf.proof,
            bytes20(multisigAccountLeaf.b32Address << 96),
            multisigAccountLeaf.balanceBeddows,
            MultisigKeys(multisigAccountLeaf.mandatoryKeys, multisigAccountLeaf.optionalKeys),
            destination,
            ed25519Signatures
        );
        console2.log("Destination LSK Balance After Multisig Account Claim:", lsk.balanceOf(destination), "Beddows");
    }
}
