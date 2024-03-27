// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { GovernorUpgradeable } from "@openzeppelin-upgradeable/contracts/governance/GovernorUpgradeable.sol";
import { GovernorSettingsUpgradeable } from
    "@openzeppelin-upgradeable/contracts/governance/extensions/GovernorSettingsUpgradeable.sol";
import { GovernorCountingSimpleUpgradeable } from
    "@openzeppelin-upgradeable/contracts/governance/extensions/GovernorCountingSimpleUpgradeable.sol";
import {
    IVotes,
    GovernorVotesUpgradeable
} from "@openzeppelin-upgradeable/contracts/governance/extensions/GovernorVotesUpgradeable.sol";
import {
    GovernorTimelockControlUpgradeable,
    TimelockControllerUpgradeable
} from "@openzeppelin-upgradeable/contracts/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

contract L2Governor is
    Initializable,
    GovernorUpgradeable,
    GovernorSettingsUpgradeable,
    GovernorCountingSimpleUpgradeable,
    GovernorVotesUpgradeable,
    GovernorTimelockControlUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    /// @notice Name of the governor contract.
    string public constant NAME = "Lisk Governor";

    /// @notice Voting delay for proposals (in EIP-6372 clock).
    uint48 public constant VOTING_DELAY = 0;

    /// @notice Voting period for proposals (in EIP-6372 clock).
    uint32 public constant VOTING_PERIOD = 604800; // 7 days

    /// @notice Threshold for a proposal to be successful.
    uint256 public constant PROPOSAL_THRESHOLD = 300_000 * 10 ** 18; // 300.000 vpLSK

    /// @notice Quorum required for a proposal to be successful (number of tokens).
    uint256 public constant QUORUM_THRESHOLD = 24_000_000 * 10 ** 18; // 24.000.000 vpLSK

    /// @notice Disabling initializers on implementation contract to prevent misuse.
    constructor() {
        _disableInitializers();
    }

    /// @notice Setting global params.
    /// @param token The address of the token contract used for voting (Voting Power Contract).
    /// @param timelock The address of the TimelockController contract used for time-controlled actions.
    /// @param initialOwner The address of the initial owner of the contract.
    function initialize(
        IVotes token,
        TimelockControllerUpgradeable timelock,
        address initialOwner
    )
        public
        initializer
    {
        __Governor_init(NAME);
        __GovernorSettings_init(VOTING_DELAY, VOTING_PERIOD, PROPOSAL_THRESHOLD);
        __GovernorCountingSimple_init();
        __GovernorVotes_init(token);
        __GovernorTimelockControl_init(timelock);
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function version() public pure virtual override returns (string memory) {
        return "1.0.0";
    }

    /// @notice Returns the quorum required for a proposal to be successful.
    function quorum(uint256) public pure virtual override returns (uint256) {
        return QUORUM_THRESHOLD;
    }

    /// @notice Ensures that only the owner can authorize a contract upgrade. It reverts if called by any address other
    ///         than the contract owner.
    /// @param _newImplementation The address of the new contract implementation to which the proxy will be upgraded.
    function _authorizeUpgrade(address _newImplementation) internal virtual override onlyOwner { }

    // The below functions are overrides required by Solidity.

    function state(uint256 proposalId)
        public
        view
        virtual
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        virtual
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    function proposalThreshold()
        public
        view
        virtual
        override(GovernorUpgradeable, GovernorSettingsUpgradeable)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        virtual
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (uint48)
    {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        virtual
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
    {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    )
        internal
        virtual
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        virtual
        override(GovernorUpgradeable, GovernorTimelockControlUpgradeable)
        returns (address)
    {
        return super._executor();
    }
}
