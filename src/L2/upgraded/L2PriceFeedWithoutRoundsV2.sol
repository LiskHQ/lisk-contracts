// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { L2PriceFeedWithoutRounds } from "../L2PriceFeedWithoutRounds.sol";

/// @title L2PriceFeedWithoutRoundsV2 - L2PriceFeedWithoutRoundsV2 contract
/// @notice This contract represents PriceFeedWithoutRoundsForMultiFeedAdapter contract. It is an upgradeable version of
///         the L2PriceFeedWithoutRounds contract, allowing for updates to the adapter contract address while
///         maintaining the same interface and functionality.
contract L2PriceFeedWithoutRoundsV2 is L2PriceFeedWithoutRounds {
    /// @notice Setting global params.
    /// @param _newAdapter The address of the new MultiFeedAdapter contract.
    function initializeV2(address _newAdapter) public virtual reinitializer(2) {
        require(_newAdapter != address(0), "L2PriceFeedWithoutRoundsV2: new adapter contract address can not be zero");
        priceFeedAdapter = _newAdapter;
    }
}
