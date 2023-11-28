// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

/// @title SigUtils - signature verification utility library
/// @notice This library provides functions to create, hash, and sign the approvals off-chain.
contract SigUtils {
    /// @notice EIP-712 domain separator
    bytes32 internal DOMAIN_SEPARATOR;

    constructor(bytes32 _DOMAIN_SEPARATOR) {
        DOMAIN_SEPARATOR = _DOMAIN_SEPARATOR;
    }

    /// @notice keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// @notice EIP-712 permit struct
    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    /// @notice Computes the hash of a permit
    /// @param _permit The permit to hash
    /// @return The hash of the permit
    function getStructHash(Permit memory _permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(PERMIT_TYPEHASH, _permit.owner, _permit.spender, _permit.value, _permit.nonce, _permit.deadline)
        );
    }

    /// @notice Computes the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the
    ///         signer.
    /// @param _permit The permit to hash
    /// @return The hash of the EIP-712 message
    function getTypedDataHash(Permit memory _permit) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_permit)));
    }
}
