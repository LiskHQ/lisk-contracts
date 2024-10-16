// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { PriceFeedWithoutRoundsForMultiFeedAdapter } from
    "@redstone-finance/on-chain-relayer/contracts/price-feeds/without-rounds/PriceFeedWithoutRoundsForMultiFeedAdapter.sol";
import { IRedstoneAdapter } from "@redstone-finance/on-chain-relayer/contracts/core/IRedstoneAdapter.sol";

contract L2PriceFeedLskWithoutRounds is PriceFeedWithoutRoundsForMultiFeedAdapter {
    function getDataFeedId() public view virtual override returns (bytes32) {
        return bytes32("LSK");
    }

    function getPriceFeedAdapter() public view virtual override returns (IRedstoneAdapter) {
        return IRedstoneAdapter(0xb5192ebA1DE69DA66A6C05Ba01C2514381a38c04);
    }
}
