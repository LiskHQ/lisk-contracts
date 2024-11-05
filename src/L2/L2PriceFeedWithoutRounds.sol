// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { PriceFeedWithoutRoundsForMultiFeedAdapter } from
    "@redstone-finance/on-chain-relayer/contracts/price-feeds/without-rounds/PriceFeedWithoutRoundsForMultiFeedAdapter.sol";
import { IRedstoneAdapter } from "@redstone-finance/on-chain-relayer/contracts/core/IRedstoneAdapter.sol";

/// @title L2PriceFeedWithoutRounds - L2PriceFeedWithoutRounds contract
/// @notice This contract represents PriceFeedWithoutRoundsForMultiFeedAdapter contract.
contract L2PriceFeedWithoutRounds is
    Initializable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable,
    PriceFeedWithoutRoundsForMultiFeedAdapter
{
    /// @notice The address of the MultiFeedAdapter contract.
    address internal priceFeedAdapter;

    /// @notice The data feed ID.
    string internal dataFeedId;

    /// @notice Disabling initializers on implementation contract to prevent misuse.
    constructor() {
        _disableInitializers();
    }

    /// @notice Setting global params.
    /// @param _feedId The data feed ID.
    /// @param _adapter The address of the MultiFeedAdapter contract.
    function initialize(string memory _feedId, address _adapter) public virtual initializer {
        require(bytes(_feedId).length > 0, "L2PriceFeedWithoutRounds: data feed ID can not be empty");
        require(_adapter != address(0), "L2PriceFeedWithoutRounds: adapter contract address can not be zero");
        __Ownable2Step_init();
        __Ownable_init(msg.sender);
        dataFeedId = _feedId;
        priceFeedAdapter = _adapter;
    }

    /// @notice Ensures that only the owner can authorize a contract upgrade. It reverts if called by any address other
    ///         than the contract owner.
    /// @param _newImplementation The address of the new contract implementation to which the proxy will be upgraded.
    function _authorizeUpgrade(address _newImplementation) internal virtual override onlyOwner { }

    /// @notice This function returns the data feed ID.
    /// @return The data feed ID.
    function getDataFeedId() public view virtual override returns (bytes32) {
        return bytes32(abi.encodePacked(dataFeedId));
    }

    /// @notice This function returns the price feed adapter.
    /// @return The price feed adapter.
    function getPriceFeedAdapter() public view virtual override returns (IRedstoneAdapter) {
        return IRedstoneAdapter(priceFeedAdapter);
    }
}
