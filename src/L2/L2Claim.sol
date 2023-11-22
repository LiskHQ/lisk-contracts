// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Ed25519 } from "../utils/Ed25519.sol";

struct MultisigKeys {
    bytes32[] mandatoryKeys;
    bytes32[] optionalKeys;
}

struct ED25519Signature {
    bytes32 r;
    bytes32 s;
}

contract L2Claim {
    event LSKClaimed(bytes20 lskAddress, uint256 amount);

    uint256 public constant LSK_MULTIPLIER = 10 ** 10;

    IERC20 public immutable l2LiskToken;
    bytes32 public immutable merkleRoot;

    // lskAddress => boolean;
    mapping(bytes20 => bool) public claimed;

    constructor(address _l2LiskToken, bytes32 _merkleRoot) {
        l2LiskToken = IERC20(_l2LiskToken);
        merkleRoot = _merkleRoot;
    }

    function verifySignature(bytes32 _pubKey, bytes32 _r, bytes32 _s, bytes32 _message) internal pure {
        require(Ed25519.check(_pubKey, _r, _s, _message, bytes9(0)), "Invalid Signature");
    }

    function encodeBytes32Array(bytes32[] calldata _input) internal pure returns (bytes memory data) {
        for (uint256 i = 0; i < _input.length; i++) {
            data = abi.encodePacked(data, _input[i]);
        }
    }

    function claim(
        bytes20 _lskAddress,
        uint64 _amount,
        bytes32[] calldata _proof,
        bytes32 _node,
        address _recipient
    )
        internal
    {
        require(!claimed[_lskAddress], "Already Claimed");
        require(MerkleProof.verify(_proof, merkleRoot, _node), "Invalid Proof");

        l2LiskToken.transfer(_recipient, _amount * LSK_MULTIPLIER);

        claimed[_lskAddress] = true;
        emit LSKClaimed(_lskAddress, _amount);
    }

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
        bytes32 node = keccak256(abi.encodePacked(lskAddress, _amount, uint256(0)));

        verifySignature(_pubKey, _sig.r, _sig.s, keccak256(abi.encodePacked(node, _recipient)));

        claim(lskAddress, _amount, _proof, node, _recipient);
    }

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
        // If numberOfSignatures passes MerkleProof in later stage, that means this value is correct.
        uint256 numberOfSignatures = _keys.mandatoryKeys.length;

        for (uint256 i = 0; i < _keys.optionalKeys.length; i++) {
            if (_sigs[i + _keys.mandatoryKeys.length].r == bytes32(0)) {
                continue;
            }
            numberOfSignatures++;
        }

        bytes32 node = keccak256(
            abi.encodePacked(
                _lskAddress,
                _amount,
                numberOfSignatures,
                encodeBytes32Array(_keys.mandatoryKeys),
                encodeBytes32Array(_keys.optionalKeys)
            )
        );

        bytes32 message = keccak256(abi.encodePacked(node, _recipient));

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

        claim(_lskAddress, _amount, _proof, node, _recipient);
    }
}
