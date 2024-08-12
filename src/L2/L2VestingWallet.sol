// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { VestingWalletUpgradeable } from "@openzeppelin-upgradeable/contracts/finance/VestingWalletUpgradeable.sol";
import { AccessControlEnumerableUpgradeable } from
    "@openzeppelin-upgradeable/contracts/access/extensions/AccessControlEnumerableUpgradeable.sol";
import { ISemver } from "../utils/ISemver.sol";

/// @title L2VestingWallet
/// @notice This contract handles the Vesting functionality of LSK Token for the L2 network.
contract L2VestingWallet is
    Ownable2StepUpgradeable,
    UUPSUpgradeable,
    VestingWalletUpgradeable,
    AccessControlEnumerableUpgradeable,
    ISemver
{
    /// @notice Name of the contract, solely used for readability on Explorer for users.
    string public name;

    /// @notice Semantic version of the contract.
    string public version;

    /// @notice A unique role identifier for accounts with the ability to upgrade this contract.
    bytes32 public constant CONTRACT_ADMIN_ROLE = keccak256("CONTRACT_ADMIN_ROLE");

    /// @notice The next contractAdmin, assigned by current contractAdmin
    address public pendingContractAdmin;

    /// @notice Disabling initializers on implementation contract to prevent misuse.
    constructor() {
        _disableInitializers();
    }

    /// @notice Setting vesting params.
    /// @param  _beneficiary        Beneficiary of the Vesting Plan, which is also the initial owner of this contract.
    /// @param  _startTimestamp     Timestamp the vesting starts.
    /// @param  _durationSeconds    Duration of the vesting period.
    /// @param  _name               Name of this contract.
    /// @param  _contractAdmin      Initial contractAdmin who can upgrade the contract.
    function initialize(
        address _beneficiary,
        uint64 _startTimestamp,
        uint64 _durationSeconds,
        string memory _name,
        address _contractAdmin
    )
        public
        initializer
    {
        require(_beneficiary != address(0), "VestingWallet: _beneficiary address cannot be 0");
        require(_contractAdmin != address(0), "VestingWallet: _contractAdmin address cannot be 0");

        __Ownable2Step_init();
        __UUPSUpgradeable_init();
        __VestingWallet_init(_beneficiary, _startTimestamp, _durationSeconds);
        version = "1.0.0";
        name = _name;

        _grantRole(CONTRACT_ADMIN_ROLE, _contractAdmin);
    }

    /// @notice Since `Ownable2StepUpgradeable` is enforced on top of `OwnableUpgradeable`. Overriding is required.
    /// @param  _newOwner        New proposed owner.
    function transferOwnership(
        address _newOwner
    )
        public
        virtual
        override(Ownable2StepUpgradeable, OwnableUpgradeable)
        onlyOwner
    {
        Ownable2StepUpgradeable.transferOwnership(_newOwner);
    }

    // Overriding _transferOwnership and solely uses `Ownable2StepUpgradeable`.
    /// @param  _newOwner        New proposed owner.
    function _transferOwnership(
        address _newOwner
    )
        internal
        virtual
        override(Ownable2StepUpgradeable, OwnableUpgradeable)
    {
        Ownable2StepUpgradeable._transferOwnership(_newOwner);
    }

    /// @notice Transfer contractAdmin to a new address.
    /// @param  _pendingContractAdmin        New proposed contractAdmin.
    function transferContractAdminRole(address _pendingContractAdmin) public virtual onlyRole(CONTRACT_ADMIN_ROLE) {
        pendingContractAdmin = _pendingContractAdmin;
    }

    /// @notice Accept contractAdmin Role and revoke old contractAdmin right.
    function acceptContractAdminRole() public virtual {
        require(msg.sender == pendingContractAdmin, "VestingWallet: Not pendingContractAdmin");
        _revokeRole(CONTRACT_ADMIN_ROLE, getRoleMember(CONTRACT_ADMIN_ROLE, 0));
        _grantRole(CONTRACT_ADMIN_ROLE, pendingContractAdmin);
        pendingContractAdmin = address(0);
    }

    /// @notice Ensures that only the contractAdmin can authorize a contract upgrade. It reverts if called by any
    ///         address other than the address with CONTRACT_ADMIN_ROLE.
    /// @param _newImplementation The address of the new contract implementation to which the proxy will be upgraded.
    function _authorizeUpgrade(address _newImplementation) internal virtual override onlyRole(CONTRACT_ADMIN_ROLE) { }
}
