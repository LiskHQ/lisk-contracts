// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { PriceFeedWithoutRoundsForMultiFeedAdapter } from
    "@redstone-finance/on-chain-relayer/contracts/price-feeds/without-rounds/PriceFeedWithoutRoundsForMultiFeedAdapter.sol";
import { IRedstoneAdapter } from "@redstone-finance/on-chain-relayer/contracts/core/IRedstoneAdapter.sol";

/// @title L2PriceFeedLskWithoutRounds - L2PriceFeedLskWithoutRounds contract
/// @notice This contract represents PriceFeedWithoutRoundsForMultiFeedAdapter contract for LSK data feed.
contract L2PriceFeedLskWithoutRounds is
    Initializable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable,
    PriceFeedWithoutRoundsForMultiFeedAdapter
{
    /// @notice Disabling initializers on implementation contract to prevent misuse.
    constructor() {
        _disableInitializers();
    }

    /// @notice Setting global params.
    function initialize() public virtual override initializer {
        super.initialize();
        __Ownable2Step_init();
        __Ownable_init(msg.sender);
    }

    /// @notice Ensures that only the owner can authorize a contract upgrade. It reverts if called by any address other
    ///         than the contract owner.
    /// @param _newImplementation The address of the new contract implementation to which the proxy will be upgraded.
    function _authorizeUpgrade(address _newImplementation) internal virtual override onlyOwner { }

    /// @notice This function returns the data feed ID.
    /// @return The data feed ID.
    function getDataFeedId() public view virtual override returns (bytes32) {
        return bytes32("LSK");
    }

    /// @notice This function returns the price feed adapter.
    /// @return The price feed adapter.
    function getPriceFeedAdapter() public view virtual override returns (IRedstoneAdapter) {
        return IRedstoneAdapter(0x19664179Ad4823C6A51035a63C9032ed27ccA441);
    }
}
