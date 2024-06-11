// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { TimelockControllerUpgradeable } from
    "@openzeppelin-upgradeable/contracts/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import { L2Governor } from "../L2Governor.sol";

contract L2GovernorPaused is L2Governor {
    /// @notice Setting global params.
    function initializePaused() public reinitializer(2) { }

    function version() public pure virtual override returns (string memory) {
        return string.concat(super.version(), "-paused");
    }

    /// @notice Override the cancel function to prevent staking from being processed.
    function cancel(
        address[] memory,
        uint256[] memory,
        bytes[] memory,
        bytes32
    )
        public
        virtual
        override
        returns (uint256)
    {
        revert("L2GovernorPaused: Governor is paused");
    }

    /// @notice Override the castVote function to prevent staking from being processed.
    function castVote(uint256, uint8) public virtual override returns (uint256) {
        revert("L2GovernorPaused: Governor is paused");
    }

    /// @notice Override the castVoteBySig function to prevent staking from being processed.
    function castVoteBySig(uint256, uint8, address, bytes memory) public virtual override returns (uint256) {
        revert("L2GovernorPaused: Governor is paused");
    }

    /// @notice Override the castVoteWithReason function to prevent staking from being processed.
    function castVoteWithReason(uint256, uint8, string calldata) public virtual override returns (uint256) {
        revert("L2GovernorPaused: Governor is paused");
    }

    /// @notice Override the castVoteWithReasonAndParams function to prevent staking from being processed.
    function castVoteWithReasonAndParams(
        uint256,
        uint8,
        string calldata,
        bytes memory
    )
        public
        virtual
        override
        returns (uint256)
    {
        revert("L2GovernorPaused: Governor is paused");
    }

    /// @notice Override the castVoteWithReasonAndParamsBySig function to prevent staking from being processed.
    function castVoteWithReasonAndParamsBySig(
        uint256,
        uint8,
        address,
        string calldata,
        bytes memory,
        bytes memory
    )
        public
        virtual
        override
        returns (uint256)
    {
        revert("L2GovernorPaused: Governor is paused");
    }

    /// @notice Override the execute function to prevent staking from being processed.
    function execute(
        address[] memory,
        uint256[] memory,
        bytes[] memory,
        bytes32
    )
        public
        payable
        virtual
        override
        returns (uint256)
    {
        revert("L2GovernorPaused: Governor is paused");
    }

    /// @notice Override the propose function to prevent staking from being processed.
    function propose(
        address[] memory,
        uint256[] memory,
        bytes[] memory,
        string memory
    )
        public
        virtual
        override
        returns (uint256)
    {
        revert("L2GovernorPaused: Governor is paused");
    }

    /// @notice Override the queue function to prevent staking from being processed.
    function queue(
        address[] memory,
        uint256[] memory,
        bytes[] memory,
        bytes32
    )
        public
        virtual
        override
        returns (uint256)
    {
        revert("L2GovernorPaused: Governor is paused");
    }

    /// @notice Override the relay function to prevent staking from being processed.
    function relay(address, uint256, bytes memory) public payable virtual override {
        revert("L2GovernorPaused: Governor is paused");
    }

    /// @notice Override the setProposalThreshold function to prevent staking from being processed.
    function setProposalThreshold(uint256) public virtual override {
        revert("L2GovernorPaused: Governor is paused");
    }

    /// @notice Override the setVotingDelay function to prevent staking from being processed.
    function setVotingDelay(uint48) public virtual override {
        revert("L2GovernorPaused: Governor is paused");
    }

    /// @notice Override the setVotingPeriod function to prevent staking from being processed.
    function setVotingPeriod(uint32) public virtual override {
        revert("L2GovernorPaused: Governor is paused");
    }

    /// @notice Override the updateTimelock function to prevent staking from being processed.
    function updateTimelock(TimelockControllerUpgradeable) public virtual override {
        revert("L2GovernorPaused: Governor is paused");
    }
}
