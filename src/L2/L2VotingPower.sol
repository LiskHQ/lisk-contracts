// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC20VotesUpgradeable } from
    "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { LockingPosition } from "./L2LockingPosition.sol";
import { ISemver } from "../utils/ISemver.sol";

contract L2VotingPower is ERC20VotesUpgradeable, Ownable2StepUpgradeable, UUPSUpgradeable, ISemver {
    /// @notice Address of the LockingPosition contract.
    address public lockingPositionAddress;

    /// @notice Semantic version of the contract.
    string public version;

    /// @notice Emitted when the LockingPosition contract address is changed.
    event LockingPositionContractAddressChanged(address indexed oldAddress, address indexed newAddress);

    /// @notice Emitted when approve is called.
    error ApproveDisabled();

    /// @notice Emitted when transfer or transferFrom is called.
    error TransferDisabled();

    /// @notice A modifier that only allows the LockingPosition contract to call.
    modifier onlyLockingPositionContract() {
        require(
            msg.sender == lockingPositionAddress, "L2VotingPower: only LockingPosition contract can call this function"
        );
        _;
    }

    /// @notice Disabling initializers on implementation contract to prevent misuse.
    constructor() {
        _disableInitializers();
    }

    /// @notice Setting global params.
    /// @param _lockingPositionAddresss Address of the LockingPosition contract.
    function initialize(address _lockingPositionAddresss) public initializer {
        require(_lockingPositionAddresss != address(0), "L2VotingPower: LockingPosition contract address cannot be 0");
        __Ownable2Step_init();
        __Ownable_init(msg.sender);
        __ERC20_init("Lisk Voting Power", "vpLSK");
        __ERC20Votes_init();
        lockingPositionAddress = _lockingPositionAddresss;
        version = "1.0.0";
        emit LockingPositionContractAddressChanged(address(0), _lockingPositionAddresss);
    }

    /// @notice Ensures that only the owner can authorize a contract upgrade. It reverts if called by any address other
    ///         than the contract owner.
    /// @param _newImplementation The address of the new contract implementation to which the proxy will be upgraded.
    function _authorizeUpgrade(address _newImplementation) internal virtual override onlyOwner { }

    /// @notice Calculates the voting power of a locking position.
    /// @param position Locking position.
    /// @return Voting power of the locking position.
    function votingPower(LockingPosition memory position) internal pure virtual returns (uint256) {
        if (position.pausedLockingDuration > 0) {
            // countdown of locking duration is paused
            // return pos.amount * (1 + pos.pausedLockingDuration/365) but to avoid large rounding errors the following
            // is used:
            return position.amount + (position.amount * position.pausedLockingDuration) / 365;
        } else {
            // unlocked
            return position.amount;
        }
    }

    /// @notice Adjusts the voting power of the owner address. It calculates the difference between the voting power
    ///         before and after the adjustment and mints or burns the difference.
    /// @param ownerAddress Address of the locking position owner.
    /// @param positionBefore Locking position before the adjustment.
    /// @param positionAfter Locking position after the adjustment.
    function adjustVotingPower(
        address ownerAddress,
        LockingPosition memory positionBefore,
        LockingPosition memory positionAfter
    )
        public
        virtual
        onlyLockingPositionContract
    {
        uint256 votingPowerAfter = votingPower(positionAfter);
        uint256 votingPowerBefore = votingPower(positionBefore);

        if (votingPowerAfter > votingPowerBefore) {
            _mint(ownerAddress, votingPowerAfter - votingPowerBefore);
        } else if (votingPowerAfter < votingPowerBefore) {
            _burn(ownerAddress, votingPowerBefore - votingPowerAfter);
        }
    }

    /// @notice Overrides clock() function to make the token & governor timestamp-based
    function clock() public view virtual override returns (uint48) {
        return uint48(block.timestamp);
    }

    /// @notice Overrides CLOCK_MODE() function to make the token & governor timestamp-based
    function CLOCK_MODE() public pure virtual override returns (string memory) {
        return "mode=timestamp";
    }

    /// @notice Always reverts to disable ERC20 token transfer feature.
    /// @dev This function always reverts.
    function approve(address, uint256) public pure virtual override(ERC20Upgradeable) returns (bool) {
        revert ApproveDisabled();
    }

    ///  @notice Always reverts to disable ERC20 token transfer feature.
    ///  @dev This function always reverts.
    function transfer(address, uint256) public pure virtual override(ERC20Upgradeable) returns (bool) {
        revert TransferDisabled();
    }

    ///  @notice Always reverts to disable ERC20 token transfer feature.
    ///  @dev This function always reverts.
    function transferFrom(address, address, uint256) public pure virtual override(ERC20Upgradeable) returns (bool) {
        revert TransferDisabled();
    }
}
