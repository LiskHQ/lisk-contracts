// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Ed25519 } from "../utils/Ed25519.sol";

struct ED25519Signature {
    bytes32 k;
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
        address _recipient,
        ED25519Signature calldata _sig
    )
        internal
    {
        require(!claimed[_lskAddress], "Already Claimed");
        require(MerkleProof.verify(_proof, merkleRoot, _node), "Invalid proof");

        bytes32 message = keccak256(abi.encodePacked(_node, _recipient));
        require(Ed25519.check(_sig.k, _sig.r, _sig.s, message, bytes9(0)), "Invalid Signature");

        l2LiskToken.transfer(_recipient, _amount * LSK_MULTIPLIER);

        claimed[_lskAddress] = true;
        emit LSKClaimed(_lskAddress, _amount);
    }

    function claimRegularAccount(
        bytes32[] calldata _proof,
        bytes calldata _pubKey,
        uint64 _amount,
        address _recipient,
        ED25519Signature calldata _sig
    )
        external
    {
        bytes20 lskAddress = bytes20(sha256(_pubKey));

        claim(
            lskAddress, _amount, _proof, keccak256(abi.encodePacked(lskAddress, _amount, uint256(0))), _recipient, _sig
        );
    }

    function claimMultisigAccount(
        bytes32[] calldata _proof,
        bytes20 _lskAddress,
        uint64 _amount,
        bytes32[] calldata _mandatoryKeys,
        bytes32[] calldata _optionalKeys,
        address _recipient,
        ED25519Signature calldata _sig
    )
        external
    {
        claim(
            _lskAddress,
            _amount,
            _proof,
            keccak256(
                abi.encodePacked(
                    _lskAddress,
                    _amount,
                    _mandatoryKeys.length + _optionalKeys.length,
                    encodeBytes32Array(_mandatoryKeys),
                    encodeBytes32Array(_optionalKeys)
                )
            ),
            _recipient,
            _sig
        );
    }
}
