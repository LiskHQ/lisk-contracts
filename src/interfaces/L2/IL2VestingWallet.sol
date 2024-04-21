// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

interface IL2VestingWallet {
    error AddressEmptyCode(address target);
    error AddressInsufficientBalance(address account);
    error ERC1967InvalidImplementation(address implementation);
    error ERC1967NonPayable();
    error FailedInnerCall();
    error InvalidInitialization();
    error NotInitializing();
    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);
    error SafeERC20FailedOperation(address token);
    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    event ERC20Released(address indexed token, uint256 amount);
    event EtherReleased(uint256 amount);
    event Initialized(uint64 version);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Upgraded(address indexed implementation);

    receive() external payable;

    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);
    function acceptOwnership() external;
    function duration() external view returns (uint256);
    function end() external view returns (uint256);
    function initialize(
        address _beneficiary,
        uint64 _startTimestamp,
        uint64 _durationSeconds,
        string memory _name
    )
        external;
    function name() external view returns (string memory);
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function proxiableUUID() external view returns (bytes32);
    function releasable(address token) external view returns (uint256);
    function releasable() external view returns (uint256);
    function release(address token) external;
    function release() external;
    function released() external view returns (uint256);
    function released(address token) external view returns (uint256);
    function renounceOwnership() external;
    function start() external view returns (uint256);
    function transferOwnership(address _newOwner) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function version() external view returns (string memory);
    function vestedAmount(uint64 timestamp) external view returns (uint256);
    function vestedAmount(address token, uint64 timestamp) external view returns (uint256);
}
