// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { TimelockControllerUpgradeable } from
    "@openzeppelin-upgradeable/contracts/governance/extensions/GovernorTimelockControlUpgradeable.sol";
import { L2Governor } from "../L2Governor.sol";

contract L2GovernorPaused is L2Governor {
    error GovernorIsPaused();

    /// @notice Setting global params.
    function initializePaused() public reinitializer(2) { }

    /// @notice Marking version as paused.
    function version() public pure virtual override returns (string memory) {
        return "1.0.0-paused";
    }

    /// @notice Override the cancel function to pause Governor interactions.
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
        revert GovernorIsPaused();
    }

    /// @notice Override the castVote function to pause Governor interactions.
    function castVote(uint256, uint8) public virtual override returns (uint256) {
        revert GovernorIsPaused();
    }

    /// @notice Override the castVoteBySig function to pause Governor interactions.
    function castVoteBySig(uint256, uint8, address, bytes memory) public virtual override returns (uint256) {
        revert GovernorIsPaused();
    }

    /// @notice Override the castVoteWithReason function to pause Governor interactions.
    function castVoteWithReason(uint256, uint8, string calldata) public virtual override returns (uint256) {
        revert GovernorIsPaused();
    }

    /// @notice Override the castVoteWithReasonAndParams function to pause Governor interactions.
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
        revert GovernorIsPaused();
    }

    /// @notice Override the castVoteWithReasonAndParamsBySig function to pause Governor interactions.
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
        revert GovernorIsPaused();
    }

    /// @notice Override the execute function to pause Governor interactions.
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
        revert GovernorIsPaused();
    }

    /// @notice Override the onERC1155BatchReceived function to pause Governor interactions.
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    )
        public
        virtual
        override
        returns (bytes4)
    {
        revert GovernorIsPaused();
    }

    /// @notice Override the onERC1155Received function to pause Governor interactions.
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    )
        public
        virtual
        override
        returns (bytes4)
    {
        revert GovernorIsPaused();
    }

    /// @notice Override the onERC721Received function to pause Governor interactions.
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        revert GovernorIsPaused();
    }

    /// @notice Override the propose function to pause Governor interactions.
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
        revert GovernorIsPaused();
    }

    /// @notice Override the queue function to pause Governor interactions.
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
        revert GovernorIsPaused();
    }

    /// @notice Override the relay function to pause Governor interactions.
    function relay(address, uint256, bytes memory) public payable virtual override {
        revert GovernorIsPaused();
    }

    /// @notice Override the setProposalThreshold function to pause Governor interactions.
    function setProposalThreshold(uint256) public virtual override {
        revert GovernorIsPaused();
    }

    /// @notice Override the setVotingDelay function to pause Governor interactions.
    function setVotingDelay(uint48) public virtual override {
        revert GovernorIsPaused();
    }

    /// @notice Override the setVotingPeriod function to pause Governor interactions.
    function setVotingPeriod(uint32) public virtual override {
        revert GovernorIsPaused();
    }

    /// @notice Override the updateTimelock function to pause Governor interactions.
    function updateTimelock(TimelockControllerUpgradeable) public virtual override {
        revert GovernorIsPaused();
    }
}
