// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { Ed25519 } from "../utils/Ed25519.sol";
import { ISemver } from "../utils/ISemver.sol";

/// @notice Struct representing arrays of mandatory and optional ED25519 keys used in multisig operations.
struct MultisigKeys {
    bytes32[] mandatoryKeys;
    bytes32[] optionalKeys;
}

/// @notice Struct encapsulating the components of an ED25519 signature.
struct ED25519Signature {
    bytes32 r;
    bytes32 s;
}

/// @title L2Claim
/// @notice Enables users to claim their LSK tokens from Lisk Chain on L2 using Merkle proofs, with support for both
///         regular and multisig accounts.
contract L2Claim is Initializable, Ownable2StepUpgradeable, UUPSUpgradeable, ISemver {
    /// @notice LSK originally has 8 decimal places, L2 LSK has 18 decimal places.
    uint256 public constant LSK_MULTIPLIER = 10 ** 10;

    /// @notice Address of L2 LSK Token.
    IERC20 public l2LiskToken;

    /// @notice Merkle Root for the claim process.
    bytes32 public merkleRoot;

    /// @notice Timestamp after which the contract owner can recover unclaimed LSK to the DAO.
    uint256 public recoverPeriodTimestamp;

    /// @notice DAO address for receiving unclaimed LSK after the claim period.
    address public daoAddress;

    // @notice Mapping to track which LSK addresses have claimed their tokens and its destination (lskAddress =>
    // address).
    mapping(bytes20 => address) public claimedTo;

    /// @notice Emitted when an address has claimed the LSK.
    event LSKClaimed(bytes20 lskAddress, address recipient, uint256 amount);

    /// @notice Event indicating the end of the claiming period.
    event ClaimingEnded();

    /// @notice Semantic version of the contract.
    string public version;

    /// @notice Disabling initializers on implementation contract to prevent misuse.
    constructor() {
        _disableInitializers();
    }

    /// @notice Setting global params.
    /// @param  _l2LiskToken            The address of the L2 LSK Token contract.
    /// @param  _merkleRoot             The root of the Merkle Tree for claims.
    /// @param  _recoverPeriodTimestamp The timestamp after which unclaimed LSK can be recovered.
    function initialize(
        address _l2LiskToken,
        bytes32 _merkleRoot,
        uint256 _recoverPeriodTimestamp
    )
        public
        initializer
    {
        __Ownable2Step_init();
        __Ownable_init(msg.sender);
        l2LiskToken = IERC20(_l2LiskToken);
        merkleRoot = _merkleRoot;
        recoverPeriodTimestamp = _recoverPeriodTimestamp;
        version = "1.0.0";
    }

    /// @notice Verifies ED25519 Signature, throws error when verification fails.
    /// @param _pubKey       The public key associated with the address in the Lisk Chain.
    /// @param _r            The 'r' component of the ED25519 signature.
    /// @param _s            The 's' component of the ED25519 signature.
    /// @param _message      The message to be verified.
    /// @param _errorMessage The error message to throw if verification fails.
    function verifySignature(
        bytes32 _pubKey,
        bytes32 _r,
        bytes32 _s,
        bytes32 _message,
        string memory _errorMessage
    )
        internal
        pure
        virtual
    {
        require(Ed25519.check(_pubKey, _r, _s, _message, bytes9(0)), _errorMessage);
    }

    /// @notice Hashes a message twice using Keccak-256.
    /// @param  _message The message to be double-hashed.
    /// @return The double-hashed message.
    function doubleKeccak256(bytes memory _message) internal pure virtual returns (bytes32) {
        return keccak256(bytes.concat(keccak256(_message)));
    }

    /// @notice Internal function to process claims by verifying the Merkle proof and transferring tokens called by both
    ///         regular and multisig claims.
    /// @param _lskAddress The LSK address in bytes format.
    /// @param _amount     Amount of LSK (In Beddows [1 LSK = 10**8 Beddow]).
    /// @param _proof      The array of hashes that prove the existence of the leaf in the Merkle Tree.
    /// @param _leaf       Double-hashed leaf by combining address, amount, numberOfSignatures, mandatory and optional
    ///                    keys.
    /// @param _recipient  The destination address on the L2 Chain.
    function claim(
        bytes20 _lskAddress,
        uint64 _amount,
        bytes32[] calldata _proof,
        bytes32 _leaf,
        address _recipient
    )
        internal
        virtual
    {
        require(claimedTo[_lskAddress] == address(0), "L2Claim: already Claimed");
        require(MerkleProof.verify(_proof, merkleRoot, _leaf), "L2Claim: invalid Proof");

        claimedTo[_lskAddress] = _recipient;

        // L2LiskToken is using openzeppelin ERC20, which the transfer is always checked and has no threat of
        // reentrancy.
        // slither-disable-next-line reentrancy-no-eth
        // slither-disable-next-line unchecked-transfer
        l2LiskToken.transfer(_recipient, _amount * LSK_MULTIPLIER);

        // slither-disable-next-line reentrancy-events
        emit LSKClaimed(_lskAddress, _recipient, _amount);
    }

    /// @notice Allows users to claim their LSK from a regular account on the L2 chain.
    /// @param _proof     Array of hashes that proves existence of the leaf.
    /// @param _pubKey    The public key of the Lisk chain address.
    /// @param _amount    Amount of LSK (In Beddows [1 LSK = 10**8 Beddow]).
    /// @param _recipient The recipient address on the L2 chain.
    /// @param _sig       ED25519 signature pair.
    function claimRegularAccount(
        bytes32[] calldata _proof,
        bytes32 _pubKey,
        uint64 _amount,
        address _recipient,
        ED25519Signature calldata _sig
    )
        external
        virtual
    {
        bytes20 lskAddress = bytes20(sha256(abi.encode(_pubKey)));
        bytes32 leaf = doubleKeccak256(abi.encode(lskAddress, _amount, uint32(0), new bytes32[](0), new bytes32[](0)));

        verifySignature(_pubKey, _sig.r, _sig.s, keccak256(abi.encode(leaf, _recipient)), "L2Claim: invalid signature");

        claim(lskAddress, _amount, _proof, leaf, _recipient);
    }

    /// @notice Allows users to claim their LSK from a multisig account on the L2 chain.
    /// @param _proof      Array of hashes that proves existence of the leaf.
    /// @param _lskAddress The LSK address in bytes format.
    /// @param _amount     The amount of LSK (In Beddows [1 LSK = 10**8 Beddow]) to be claimed.
    /// @param _keys       The struct containing mandatory and optional keys for the multisig.
    /// @param _recipient  The recipient address on the L2 chain.
    /// @param _sigs       Array of ED25519 signature pairs.
    function claimMultisigAccount(
        bytes32[] calldata _proof,
        bytes20 _lskAddress,
        uint64 _amount,
        MultisigKeys calldata _keys,
        address _recipient,
        ED25519Signature[] calldata _sigs
    )
        external
        virtual
    {
        require(_sigs.length > 0, "L2Claim: signatures array is empty");
        require(
            _sigs.length == _keys.optionalKeys.length + _keys.mandatoryKeys.length,
            "L2Claim: signatures array has invalid length"
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
                "L2Claim: invalid signature when verifying with mandatoryKeys[]"
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
                "L2Claim: invalid signature when verifying with optionalKeys[]"
            );
        }

        claim(_lskAddress, _amount, _proof, leaf, _recipient);
    }

    /// @notice Sets the DAO address which will receive all unclaimed LSK tokens. This function can only be called once
    ///         by the contract owner.
    /// @param _daoAddress The address of the DAO.
    function setDAOAddress(address _daoAddress) public virtual onlyOwner {
        require(daoAddress == address(0), "L2Claim: DAO Address has already been set");
        require(_daoAddress != address(0), "L2Claim: DAO Address cannot be zero");
        daoAddress = _daoAddress;
    }

    /// @notice Allows the contract owner to recover unclaimed LSK tokens to the DAO address after the claim period is
    ///         over.
    function recoverLSK() public virtual onlyOwner {
        // Use of timestamp is intentional and safe as the period would stretch out by years.
        // slither-disable-next-line timestamp
        require(block.timestamp >= recoverPeriodTimestamp, "L2Claim: recover period not reached");

        // L2LiskToken is using openzeppelin ERC20, which the transfer is always checked and has no threat of
        // reentrancy.
        // slither-disable-next-line reentrancy-no-eth
        // slither-disable-next-line unchecked-transfer
        l2LiskToken.transfer(daoAddress, l2LiskToken.balanceOf(address(this)));

        // slither-disable-next-line reentrancy-events
        emit ClaimingEnded();
    }

    /// @notice Ensures that only the owner can authorize a contract upgrade. It reverts if called by any address other
    ///         than the contract owner.
    /// @param _newImplementation The address of the new contract implementation to which the proxy will be upgraded.
    function _authorizeUpgrade(address _newImplementation) internal virtual override onlyOwner { }
}
