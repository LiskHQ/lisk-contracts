// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { L2PriceFeedWithoutRounds } from "../L2PriceFeedWithoutRounds.sol";

/// @title L2PriceFeedWithoutRoundsV3 - Upgradeable price feed with feed ID modification
/// @notice Allows updating the data feed ID while maintaining the same contract address and interface.
contract L2PriceFeedWithoutRoundsV3 is L2PriceFeedWithoutRounds {
    /// @notice Reinitializes the contract with a new data feed ID.
    /// @param _newFeedId The new data feed ID (e.g., "BTC" for BTC/USD).
    function initializeV3(string memory _newFeedId) public virtual reinitializer(3) {
        require(bytes(_newFeedId).length > 0, "L2PriceFeedWithoutRoundsV3: data feed ID can not be empty");
        dataFeedId = _newFeedId;
    }
}
