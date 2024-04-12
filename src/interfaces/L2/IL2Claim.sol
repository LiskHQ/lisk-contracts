// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

interface IL2Claim {
    struct ED25519Signature {
        bytes32 r;
        bytes32 s;
    }

    struct MultisigKeys {
        bytes32[] mandatoryKeys;
        bytes32[] optionalKeys;
    }

    error AddressEmptyCode(address target);
    error ERC1967InvalidImplementation(address implementation);
    error ERC1967NonPayable();
    error FailedInnerCall();
    error InvalidInitialization();
    error NotInitializing();
    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);
    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    event ClaimingEnded();
    event DaoAddressSet(address indexed daoAddress);
    event Initialized(uint64 version);
    event LSKClaimed(bytes20 indexed lskAddress, address indexed recipient, uint256 amount);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Upgraded(address indexed implementation);

    function LSK_MULTIPLIER() external view returns (uint256);
    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);
    function acceptOwnership() external;
    function claimMultisigAccount(
        bytes32[] memory _proof,
        bytes20 _lskAddress,
        uint64 _amount,
        MultisigKeys memory _keys,
        address _recipient,
        ED25519Signature[] memory _sigs
    )
        external;
    function claimRegularAccount(
        bytes32[] memory _proof,
        bytes32 _pubKey,
        uint64 _amount,
        address _recipient,
        ED25519Signature memory _sig
    )
        external;
    function claimedTo(bytes20) external view returns (address);
    function daoAddress() external view returns (address);
    function initialize(address _l2LiskToken, bytes32 _merkleRoot, uint256 _recoverPeriodTimestamp) external;
    function l2LiskToken() external view returns (address);
    function merkleRoot() external view returns (bytes32);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function proxiableUUID() external view returns (bytes32);
    function recoverLSK() external;
    function recoverPeriodTimestamp() external view returns (uint256);
    function renounceOwnership() external;
    function setDAOAddress(address _daoAddress) external;
    function transferOwnership(address newOwner) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function version() external view returns (string memory);
}
