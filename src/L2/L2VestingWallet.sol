// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import { VestingWalletUpgradeable } from "@openzeppelin-upgradeable/contracts/finance/VestingWalletUpgradeable.sol";
import { IL2LockingPosition } from "../interfaces/L2/IL2LockingPosition.sol";
import { ISemver } from "../utils/ISemver.sol";

/// @title L2VestingWallet
/// @notice This contract handles the Vesting functionality of LSK Token for the L2 network.
contract L2VestingWallet is Ownable2StepUpgradeable, UUPSUpgradeable, VestingWalletUpgradeable, ISemver {
    /// @notice Name of the contract, solely used for readability on Explorer for users.
    string public name;

    /// @notice Semantic version of the contract.
    string public version;

    /// @notice Disabling initializers on implementation contract to prevent misuse.
    constructor() {
        _disableInitializers();
    }

    /// @notice Setting vesting params.
    /// @param  _beneficiary            Beneficiary of the Vesting Plan, which is also the initial owner of this
    /// contract.
    /// @param  _startTimestamp         Timestamp the vesting starts.
    /// @param  _durationSeconds        Duration of the vesting period.
    /// @param  _name                   Name of this contract.
    function initialize(
        address _beneficiary,
        uint64 _startTimestamp,
        uint64 _durationSeconds,
        string memory _name
    )
        public
        initializer
    {
        __Ownable2Step_init();
        __UUPSUpgradeable_init();
        __VestingWallet_init(_beneficiary, _startTimestamp, _durationSeconds);
        version = "1.0.0";
        name = _name;
    }

    /// @notice Since `Ownable2StepUpgradeable` is enforced on top of `OwnableUpgradeable`. Overriding is required.
    /// @param  _newOwner        New proposed owner.
    function transferOwnership(address _newOwner)
        public
        override(Ownable2StepUpgradeable, OwnableUpgradeable)
        onlyOwner
    {
        Ownable2StepUpgradeable.transferOwnership(_newOwner);
    }

    // Overriding _transferOwnership and solely uses `Ownable2StepUpgradeable`.
    /// @param  _newOwner        New proposed owner.
    function _transferOwnership(address _newOwner) internal override(Ownable2StepUpgradeable, OwnableUpgradeable) {
        Ownable2StepUpgradeable._transferOwnership(_newOwner);
    }

    /// @notice Ensures that only the owner can authorize a contract upgrade. It reverts if called by any address other
    ///         than the contract owner.
    /// @param _newImplementation The address of the new contract implementation to which the proxy will be upgraded.
    function _authorizeUpgrade(address _newImplementation) internal virtual override onlyOwner { }
}
