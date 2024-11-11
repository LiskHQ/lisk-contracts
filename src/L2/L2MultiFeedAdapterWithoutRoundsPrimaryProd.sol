// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { MultiFeedAdapterWithoutRoundsPrimaryProd } from
    "@redstone-finance/on-chain-relayer/contracts/price-feeds/data-services/MultiFeedAdapterWithoutRoundsPrimaryProd.sol";
import { Constants } from "../utils/Constants.sol";

/// @title L2MultiFeedAdapterWithoutRoundsPrimaryProd - L2MultiFeedAdapterWithoutRoundsPrimaryProd contract
/// @notice This contract represents MultiFeedAdapterWithoutRounds contract for RedStone primary production environment.
///         It is used to manage multiple price feeds without rounds. This adapter contract allows updating any set of
///         data feeds, with each update being made independently.
contract L2MultiFeedAdapterWithoutRoundsPrimaryProd is
    Initializable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable,
    MultiFeedAdapterWithoutRoundsPrimaryProd,
    Constants
{
    /// @notice Disabling initializers on implementation contract to prevent misuse.
    constructor() {
        _disableInitializers();
    }

    /// @notice Setting global params.
    function initialize() public initializer {
        __Ownable2Step_init();
        __Ownable_init(msg.sender);
    }

    /// @notice Ensures that only the owner can authorize a contract upgrade. It reverts if called by any address other
    ///         than the contract owner.
    /// @param _newImplementation The address of the new contract implementation to which the proxy will be upgraded.
    function _authorizeUpgrade(address _newImplementation) internal virtual override onlyOwner { }

    /// @notice This function validates the block timestamp.
    /// @param lastBlockTimestamp The timestamp of the last block.
    /// @return A boolean value indicating whether the block timestamp is valid for price feed to be updated.
    function _validateBlockTimestamp(uint256 lastBlockTimestamp) internal view virtual override returns (bool) {
        if (msg.sender == owner() || msg.sender == DEDICATED_MESSAGE_SENDER_ADDRESS) {
            // For whitelisted addresses we only require a newer block
            return block.timestamp > lastBlockTimestamp;
        } else {
            // For non-whitelisted addresses we require some time to pass after the latest update
            return block.timestamp > lastBlockTimestamp + 40 seconds;
        }
    }

    /// @notice This function returns numeric oracle values for a given array of data feed ids.
    /// @param dataFeedIds An array of unique data feed identifiers.
    /// @return An array of the extracted and verified oracle values in the same order as they are requested in the
    ///         dataFeedIds array and data packages timestamp.
    function getLivePricesAndTimestamp(bytes32[] memory dataFeedIds)
        public
        view
        virtual
        returns (uint256[] memory, uint256)
    {
        return getOracleNumericValuesAndTimestampFromTxMsg(dataFeedIds);
    }
}
