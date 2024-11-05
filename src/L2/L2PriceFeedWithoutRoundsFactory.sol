// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { Initializable } from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/contracts/access/Ownable2StepUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { L2PriceFeedWithoutRounds } from "./L2PriceFeedWithoutRounds.sol";

/// @title L2PriceFeedWithoutRoundsFactory - L2PriceFeedWithoutRoundsFactory contract
/// @notice This contract is a factory contract that generates L2PriceFeedWithoutRounds contracts on the network it's
///         deployed to. It simplifies the process of creating new L2PriceFeedWithoutRounds contracts.
contract L2PriceFeedWithoutRoundsFactory is Initializable, Ownable2StepUpgradeable, UUPSUpgradeable {
    /// @notice The array of L2PriceFeedWithoutRounds contract addresses.
    address[] public l2PriceFeedWithoutRoundsContracts;

    /// @notice The mapping of L2PriceFeedWithoutRounds contract addresses to array of data feed IDs.
    mapping(address => string[]) public l2PriceFeedWithoutRoundsDataFeedIds;

    /// @notice Disabling initializers on implementation contract to prevent misuse.
    constructor() {
        _disableInitializers();
    }

    /// @notice Setting global params.
    function initialize() public virtual initializer {
        __Ownable2Step_init();
        __Ownable_init(msg.sender);
    }

    /// @notice Ensures that only the owner can authorize a contract upgrade. It reverts if called by any address other
    ///         than the contract owner.
    /// @param _newImplementation The address of the new contract implementation to which the proxy will be upgraded.
    function _authorizeUpgrade(address _newImplementation) internal virtual override onlyOwner { }

    /// @notice This function creates a new L2PriceFeedWithoutRounds contract.
    /// @param _feedId The data feed ID.
    /// @param _adapter The address of the MultiFeedAdapter contract.
    /// @return The address of the newly created L2PriceFeedWithoutRounds contract.
    function createL2PriceFeedWithoutRounds(string memory _feedId, address _adapter) public virtual returns (address) {
        require(bytes(_feedId).length > 0, "L2PriceFeedWithoutRoundsFactory: data feed ID can not be empty");
        require(_adapter != address(0), "L2PriceFeedWithoutRoundsFactory: adapter contract address can not be zero");

        // deploy L2PriceFeedWithoutRounds implementation contract
        L2PriceFeedWithoutRounds newL2PriceFeedImplementation = new L2PriceFeedWithoutRounds();
        require(address(newL2PriceFeedImplementation) != address(0));

        // deploy L2PriceFeedWithoutRounds contract via proxy and initialize it
        ERC1967Proxy newL2PriceFeedProxy = new ERC1967Proxy(address(newL2PriceFeedImplementation), "");
        L2PriceFeedWithoutRounds newL2PriceFeed = L2PriceFeedWithoutRounds(address(newL2PriceFeedProxy));
        require(address(newL2PriceFeed) != address(0));
        newL2PriceFeed.initialize(_feedId, _adapter);

        // transfer ownership to the caller
        newL2PriceFeed.transferOwnership(msg.sender);

        l2PriceFeedWithoutRoundsContracts.push(address(newL2PriceFeed));
        l2PriceFeedWithoutRoundsDataFeedIds[address(newL2PriceFeed)].push(_feedId);

        return address(newL2PriceFeed);
    }
}
