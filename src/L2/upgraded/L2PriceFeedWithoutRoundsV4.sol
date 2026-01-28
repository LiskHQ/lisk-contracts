// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { L2PriceFeedWithoutRoundsV3 } from "./L2PriceFeedWithoutRoundsV3.sol";

/// @title L2PriceFeedWithoutRoundsV4 - Static price feed returning fixed value
/// @notice Returns a fixed value of 100000000 (1.0 with 8 decimals) for all price queries.
contract L2PriceFeedWithoutRoundsV4 is L2PriceFeedWithoutRoundsV3 {
    /// @notice Fixed answer value representing 1.0 with 8 decimals
    int256 private constant FIXED_ANSWER = 100000000;

    /// @notice Reinitializes the contract for V4 upgrade.
    function initializeV4() public reinitializer(4) { }

    /// @notice Returns the fixed answer value.
    /// @return The fixed value of 100000000 (1.0 with 8 decimals).
    function latestAnswer() public pure override returns (int256) {
        return FIXED_ANSWER;
    }

    /// @notice Returns the latest round data with fixed answer.
    /// @return roundId Always returns 1.
    /// @return answer Always returns 100000000.
    /// @return startedAt Current block timestamp.
    /// @return updatedAt Current block timestamp.
    /// @return answeredInRound Always returns 1.
    function latestRoundData()
        public
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        roundId = 1;
        answer = FIXED_ANSWER;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = 1;
    }

}
