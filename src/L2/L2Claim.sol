// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Ed25519 } from "../utils/Ed25519.sol";

/// @notice A struct of array of mandatoryKeys and optionalKeys.
struct MultisigKeys {
    bytes32[] mandatoryKeys;
    bytes32[] optionalKeys;
}

/// @notice A struct of ED25519 signature pair.
struct ED25519Signature {
    bytes32 r;
    bytes32 s;
}

/// @title L2Claim
/// @notice L2Claim lets user claim their LSK token from LSK Chain using Merkle Tree method.
contract L2Claim {
    /// @notice LSK originally has 8 d.p., L2 LSK has 18.
    uint256 public constant LSK_MULTIPLIER = 10 ** 10;

    /// @notice address of L2 LSK Token.
    IERC20 public immutable l2LiskToken;

    /// @notice Merkle Tree for the claim.
    bytes32 public immutable merkleRoot;

    // @notice Records claimed addresses (lskAddress => boolean).
    mapping(bytes20 => bool) public claimed;

    /// @notice Emitted when an address has claimed the LSK.
    event LSKClaimed(bytes20 lskAddress, address recipient, uint256 amount);

    /// @notice _l2LiskToken    L2 LSK Token Address
    /// @notice _merkleRoot     Merkle Tree Root
    constructor(address _l2LiskToken, bytes32 _merkleRoot) {
        l2LiskToken = IERC20(_l2LiskToken);
        merkleRoot = _merkleRoot;
    }

    /// @notice Verifies ED25519 Signature, throws error when verification fails.
    /// @param _pubKey  Public Key of the address in LSK Chain.
    /// @param _r       r-value of the ED25519 signature.
    /// @param _s       s-value of the ED25519 signature.
    /// @param _message Message to be verified.
    function verifySignature(bytes32 _pubKey, bytes32 _r, bytes32 _s, bytes32 _message) internal pure {
        require(Ed25519.check(_pubKey, _r, _s, _message, bytes9(0)), "Invalid Signature");
    }

    /// @notice Hash a message twice using Keccak-256.
    /// @param  _message Message to be hashed.
    function doubleKeccak256(bytes memory _message) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(_message)));
    }

    /// @notice Internal function called by both regular and multisig claims.
    function claim(
        bytes20 _lskAddress,
        uint64 _amount,
        bytes32[] calldata _proof,
        bytes32 _leaf,
        address _recipient
    )
        internal
    {
        require(!claimed[_lskAddress], "Already Claimed");
        require(MerkleProof.verify(_proof, merkleRoot, _leaf), "Invalid Proof");

        l2LiskToken.transfer(_recipient, _amount * LSK_MULTIPLIER);

        claimed[_lskAddress] = true;
        emit LSKClaimed(_lskAddress, _recipient, _amount);
    }

    /// @notice Claim LSK from a regular account.
    /// @param _proof       Array of hashes that proves existence of the leaf.
    /// @param _pubKey      Public Key of LSK Address.
    /// @param _amount      Amount of LSK (In Beddows).
    /// @param _recipient   Destination address at L2 Chain.
    /// @param _sig         ED25519 signature pair.
    function claimRegularAccount(
        bytes32[] calldata _proof,
        bytes32 _pubKey,
        uint64 _amount,
        address _recipient,
        ED25519Signature calldata _sig
    )
        external
    {
        bytes20 lskAddress = bytes20(sha256(abi.encode(_pubKey)));
        bytes32 leaf = doubleKeccak256(abi.encode(lskAddress, _amount, uint32(0), new bytes32[](0), new bytes32[](0)));

        verifySignature(_pubKey, _sig.r, _sig.s, keccak256(abi.encode(leaf, _recipient)));

        claim(lskAddress, _amount, _proof, leaf, _recipient);
    }

    /// @notice Claim LSK from a multisig account.
    /// @param _proof       Array of hashes that proves existence of the leaf.
    /// @param _lskAddress  LSK Address in bytes format.
    /// @param _amount      Amount of LSK (In Beddows).
    /// @param _keys        Structs of Mandatory Keys and Optional Keys.
    /// @param _recipient   Destination address at L2 Chain.
    /// @param _sigs        Array of ED25519 signature pair.
    function claimMultisigAccount(
        bytes32[] calldata _proof,
        bytes20 _lskAddress,
        uint64 _amount,
        MultisigKeys calldata _keys,
        address _recipient,
        ED25519Signature[] calldata _sigs
    )
        external
    {
        require(_sigs.length == _keys.optionalKeys.length + _keys.mandatoryKeys.length, "Invalid Signature Length");

        // If numberOfSignatures passes MerkleProof in later stage, that means this value is correct.
        uint32 numberOfSignatures = uint32(_keys.mandatoryKeys.length);

        for (uint256 i = 0; i < _keys.optionalKeys.length; i++) {
            if (_sigs[i + _keys.mandatoryKeys.length].r == bytes32(0)) {
                continue;
            }
            numberOfSignatures++;
        }

        bytes32 leaf = doubleKeccak256(
            abi.encode(_lskAddress, _amount, numberOfSignatures, _keys.mandatoryKeys, _keys.optionalKeys)
        );

        bytes32 message = keccak256(abi.encode(leaf, _recipient));

        for (uint256 i = 0; i < _keys.mandatoryKeys.length; i++) {
            verifySignature(_keys.mandatoryKeys[i], _sigs[i].r, _sigs[i].s, message);
        }

        for (uint256 i = 0; i < _keys.optionalKeys.length; i++) {
            if (_sigs[i + _keys.mandatoryKeys.length].r == bytes32(0)) {
                continue;
            }
            verifySignature(
                _keys.optionalKeys[i],
                _sigs[i + _keys.mandatoryKeys.length].r,
                _sigs[i + _keys.mandatoryKeys.length].s,
                message
            );
        }

        claim(_lskAddress, _amount, _proof, leaf, _recipient);
    }
}
