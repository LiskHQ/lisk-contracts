// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { MultiFeedAdapterWithoutRounds } from
    "@redstone-finance/on-chain-relayer/contracts/price-feeds/without-rounds/MultiFeedAdapterWithoutRounds.sol";

/// @title L2MultiFeedAdapterWithoutRoundsPrimaryProd - L2MultiFeedAdapterWithoutRoundsPrimaryProd contract
/// @notice This contract represents MultiFeedAdapterWithoutRounds contract for RedStone primary production environment.
///         It is used to manage multiple price feeds without rounds. This adapter contract allows updating any set of
///         data feeds, with each update being made independently.
contract L2MultiFeedAdapterWithoutRoundsPrimaryProd is
    Initializable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable,
    MultiFeedAdapterWithoutRounds
{
    /// @notice The address of the Dedicated Message Sender (Gelato).
    address internal constant DEDICATED_MESSAGE_SENDER_ADDRESS = 0x57D2460f4f401F1a675A2DC282344F926797e8e7;

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

    /// @notice This function returns the number of unique signers required to update the data feeds.
    /// @return The number of unique signers required to update the data feeds.
    function getUniqueSignersThreshold() public view virtual override returns (uint8) {
        return 2;
    }

    /// @notice This function returns the index of the signer in the list of authorised signers.
    /// @param signerAddress The address of the signer.
    /// @return The index of the signer in the list of authorised signers.
    function getAuthorisedSignerIndex(address signerAddress) public view virtual override returns (uint8) {
        if (signerAddress == 0x8BB8F32Df04c8b654987DAaeD53D6B6091e3B774) return 0;
        else if (signerAddress == 0xdEB22f54738d54976C4c0fe5ce6d408E40d88499) return 1;
        else if (signerAddress == 0x51Ce04Be4b3E32572C4Ec9135221d0691Ba7d202) return 2;
        else if (signerAddress == 0xDD682daEC5A90dD295d14DA4b0bec9281017b5bE) return 3;
        else if (signerAddress == 0x9c5AE89C4Af6aA32cE58588DBaF90d18a855B6de) return 4;
        else revert SignerNotAuthorised(signerAddress);
    }

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
}
