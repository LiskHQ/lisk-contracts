// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { L2Claim, MultisigKeys, ED25519Signature } from "src/L2/L2Claim.sol";

/// @title L2ClaimPaused - Paused version of L2Claim contract
/// @notice This contract is used to pause the L2Claim contract. In case of any emergency, the owner can upgrade and
///         pause the contract to prevent any further claims from being processed.
contract L2ClaimPaused is L2Claim {
    error ClaimIsPaused();

    /// @notice Setting global params.
    function initializePaused() public reinitializer(2) {
        version = "1.0.0-paused";
    }

    /// @notice Override the claimRegularAccount function to prevent any further claims from being processed.
    function claimRegularAccount(
        bytes32[] calldata,
        bytes32,
        uint64,
        address,
        ED25519Signature calldata
    )
        external
        virtual
        override
    {
        revert ClaimIsPaused();
    }

    /// @notice Override the claimRegularAccount function to prevent any further claims from being processed.
    function claimMultisigAccount(
        bytes32[] calldata,
        bytes20,
        uint64,
        MultisigKeys calldata,
        address,
        ED25519Signature[] calldata
    )
        external
        virtual
        override
    {
        revert ClaimIsPaused();
    }
}
