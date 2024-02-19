// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC20VotesUpgradeable } from
    "@openzeppelin-upgradeable/contracts/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import { ERC20Upgradeable } from "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ISemver } from "../utils/ISemver.sol";

// TODO use this from staking contract
/// @title LockingPosition
/// @notice Struct for locking position.
struct LockingPosition {
    uint256 amount;
    uint256 lockingDuration;
    uint256 expDate;
}

contract L2VotingPower is ERC20VotesUpgradeable, OwnableUpgradeable, UUPSUpgradeable, ISemver {
    /// @notice Address of the staking contract.
    address public stakingContractAddress;

    /// @notice Semantic version of the contract.
    string public version;

    /// @notice Emitted when approve is called.
    error ApproveDisabled();

    /// @notice Emitted when transfer or transferFrom is called.
    error TransferDisabled();

    /// @notice A modifier that only allows the staking contract to call.
    modifier onlyStakingContract() {
        require(msg.sender == stakingContractAddress, "L2VotingPower: only staking contract can call this function");
        _;
    }

    /// @notice Disabling initializers on implementation contract to prevent misuse.
    constructor() {
        _disableInitializers();
    }

    /// @notice Setting global params.
    /// @param _stakingContractAddress Address of the staking contract.
    function initialize(address _stakingContractAddress) public initializer {
        __Ownable_init(msg.sender);
        __ERC20_init("Lisk Voting Power", "vpLSK");
        __ERC20Votes_init();
        stakingContractAddress = _stakingContractAddress;
        version = "1.0.0";
    }

    /// @notice Ensures that only the owner can authorize a contract upgrade. It reverts if called by any address other
    ///         than the contract owner.
    /// @param _newImplementation The address of the new contract implementation to which the proxy will be upgraded.
    function _authorizeUpgrade(address _newImplementation) internal virtual override onlyOwner { }

    /// @notice Checks if the locking position is null.
    /// @dev A locking position is null if all of its fields are zero.
    /// @param position Locking position.
    /// @return True if the locking position is null, false otherwise.
    function isLockingPositionNull(LockingPosition memory position) internal pure virtual returns (bool) {
        return position.amount == 0 && position.lockingDuration == 0 && position.expDate == 0;
    }

    /// @notice Calculates the voting power of a locking position.
    /// @param position Locking position.
    /// @return Voting power of the locking position.
    function votingPower(LockingPosition memory position) internal pure virtual returns (uint256) {
        if (position.expDate == 0) {
            // locked
            // return pos.amount * (1 + pos.lockingDuration/365) but to avoid large rounding errors the following is
            // used:
            return position.amount + (position.amount * position.lockingDuration) / 365;
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
        onlyStakingContract
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
