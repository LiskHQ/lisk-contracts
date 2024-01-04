// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
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
/// @notice L2Claim lets user claim their LSK token from Lisk Chain using Merkle Tree method.
contract L2Claim is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    /// @notice LSK originally has 8 d.p., L2 LSK has 18.
    uint256 public constant LSK_MULTIPLIER = 10 ** 10;

    /// @notice Address of L2 LSK Token.
    IERC20 public l2LiskToken;

    /// @notice Merkle Root for the claim.
    bytes32 public merkleRoot;

    /// @notice After this timestamp, owner can send all remaining unclaimed LSK from this contract to DAO
    uint256 public recoverPeriodTimestamp;

    // @notice Records claimed addresses (lskAddress => boolean).
    mapping(bytes20 => bool) public claimed;

    /// @notice Emitted when an address has claimed the LSK.
    event LSKClaimed(bytes20 lskAddress, address recipient, uint256 amount);

    /// @notice Emitted when `recoverLSK` has been called.
    event ClaimingEnded();

    /// @notice Disable Initializers at Implementation Contract.
    constructor() {
        _disableInitializers();
    }

    /// @notice Setting global params.
    /// @param  _l2LiskToken            L2 LSK Token Address
    /// @param  _merkleRoot             Merkle Tree Root
    /// @param  _recoverPeriodTimestamp Timestamp for allowing LSK Recovery
    function initialize(
        address _l2LiskToken,
        bytes32 _merkleRoot,
        uint256 _recoverPeriodTimestamp
    )
        public
        initializer
    {
        __Ownable_init(msg.sender);
        l2LiskToken = IERC20(_l2LiskToken);
        merkleRoot = _merkleRoot;
        recoverPeriodTimestamp = _recoverPeriodTimestamp;
    }

    /// @notice Verifies ED25519 Signature, throws error when verification fails.
    /// @param _pubKey          Public Key of the address in Lisk Chain.
    /// @param _r               r-value of the ED25519 signature.
    /// @param _s               s-value of the ED25519 signature.
    /// @param _message         Message to be verified.
    /// @param _errorMessage    Message the contract should throw, when the check returns false.
    function verifySignature(
        bytes32 _pubKey,
        bytes32 _r,
        bytes32 _s,
        bytes32 _message,
        string memory _errorMessage
    )
        internal
        pure
    {
        require(Ed25519.check(_pubKey, _r, _s, _message, bytes9(0)), _errorMessage);
    }

    /// @notice Hash a message twice using Keccak-256.
    /// @param  _message Message to be hashed.
    /// @return double keccak256 hashed bytes32
    function doubleKeccak256(bytes memory _message) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(_message)));
    }

    /// @notice Internal function called by both regular and multisig claims.
    /// @param _lskAddress  LSK Address in bytes format.
    /// @param _amount      Amount of LSK (In Beddows [1 LSK = 10**8 Beddow]).
    /// @param _proof       Array of hashes that proves existence of the leaf.
    /// @param _leaf        Double-hashed leaf by combining address, amount, numberOfSignatures, mandatory and optional
    ///                     keys.
    /// @param _recipient   Destination address at L2 Chain.
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
    /// @param _pubKey      Public Key of the address in Lisk Chain.
    /// @param _amount      Amount of LSK (In Beddows [1 LSK = 10**8 Beddow]).
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

        verifySignature(_pubKey, _sig.r, _sig.s, keccak256(abi.encode(leaf, _recipient)), "Invalid Signature");

        claim(lskAddress, _amount, _proof, leaf, _recipient);
    }

    /// @notice Claim LSK from a multisig account.
    /// @param _proof       Array of hashes that proves existence of the leaf.
    /// @param _lskAddress  LSK Address in bytes format.
    /// @param _amount      Amount of LSK (In Beddows [1 LSK = 10**8 Beddow]).
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
        require(
            _sigs.length == _keys.optionalKeys.length + _keys.mandatoryKeys.length,
            "Signatures array has invalid length"
        );

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
            verifySignature(
                _keys.mandatoryKeys[i],
                _sigs[i].r,
                _sigs[i].s,
                message,
                "Invalid signature when verifying with mandatoryKeys[]"
            );
        }

        for (uint256 i = 0; i < _keys.optionalKeys.length; i++) {
            if (_sigs[i + _keys.mandatoryKeys.length].r == bytes32(0)) {
                continue;
            }
            verifySignature(
                _keys.optionalKeys[i],
                _sigs[i + _keys.mandatoryKeys.length].r,
                _sigs[i + _keys.mandatoryKeys.length].s,
                message,
                "Invalid signature when verifying with optionalKeys[]"
            );
        }

        claim(_lskAddress, _amount, _proof, leaf, _recipient);
    }

    /// @notice Unclaimed LSK token can be transferred to DAO Address after claim period.
    /// @param _daoAddress        Destination recipient Address
    function recoverLSK(address _daoAddress) public onlyOwner {
        require(block.timestamp >= recoverPeriodTimestamp, "Recover period not reached");
        l2LiskToken.transfer(_daoAddress, l2LiskToken.balanceOf(address(this)));

        emit ClaimingEnded();
    }

    /// @notice Function that should revert when msg.sender is not authorized to upgrade the contract.
    /// @param _newImplementation        New Implementation Contract
    function _authorizeUpgrade(address _newImplementation) internal override onlyOwner { }
}
