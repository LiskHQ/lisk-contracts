// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./interfaces/IDivETH.sol";

/**
 * @title DivETH token wrapper with static balances.
 * @dev It's an ERC20 token that represents the account's share of the total
 * supply of divETH tokens. WdivETH token's balance only changes on transfers,
 * unlike DivETH that is also changed when oracles report staking rewards and
 * penalties. It's a "power user" token for DeFi protocols which don't
 * support rebasable tokens.
 *
 * The contract is also a trustless wrapper that accepts divETH tokens and mints
 * wdivETH in return. Then the user unwraps, the contract burns user's wdivETH
 * and sends user locked divETH in return.
 *
 * The contract provides the staking shortcut: user can send ETH with regular
 * transfer and get wdivETH in return. The contract will send ETH to Diva submit
 * method, staking it and wrapping the received divETH.
 *
 */
contract WdivETH is ERC20Permit {
    IDivETH public divETH;

    error CannotWrapZeroDivETH();
    error CannotUnwrapZeroWdivETH();

    /**
     * @param _divETH address of the DivETH token to wrap
     */
    constructor(IDivETH _divETH) ERC20Permit("Wrapped Diva Ether") ERC20("Wrapped Diva Ether", "wdivETH") {
        divETH = _divETH;
    }

    /**
     * @notice Exchanges divETH to wdivETH
     * @param _divETHAmount amount of divETH to wrap in exchange for wdivETH
     * @dev Requirements:
     *  - `_divETHAmount` must be non-zero
     *  - msg.sender must approve at least `_divETHAmount` divETH to this
     *    contract.
     *  - msg.sender must have at least `_divETHAmount` of divETH.
     * User should first approve _divETHAmount to the WdivETH contract
     * @return Amount of wdivETH user receives after wrap
     */
    function wrap(uint256 _divETHAmount) external returns (uint256) {
        if (_divETHAmount == 0) revert CannotWrapZeroDivETH();

        uint256 wdivETHAmount = divETH.getSharesByEth(_divETHAmount);
        _mint(msg.sender, wdivETHAmount);
        divETH.transferFrom(msg.sender, address(this), _divETHAmount);
        return wdivETHAmount;
    }

    /**
     * @notice Exchanges wdivETH to divETH
     * @param _wdivETHAmount amount of wdivETH to uwrap in exchange for divETH
     * @dev Requirements:
     *  - `_wdivETHAmount` must be non-zero
     *  - msg.sender must have at least `_wdivETHAmount` wdivETH.
     * @return Amount of divETH user receives after unwrap
     */
    function unwrap(uint256 _wdivETHAmount) external returns (uint256) {
        if (_wdivETHAmount == 0) revert CannotUnwrapZeroWdivETH();
        uint256 divETHAmount = divETH.getEthByShares(_wdivETHAmount);
        _burn(msg.sender, _wdivETHAmount);
        divETH.transfer(msg.sender, divETHAmount);
        return divETHAmount;
    }

    /**
     * @notice Shortcut to stake ETH and auto-wrap returned divETH
     */
    receive() external payable {
        uint256 shares = divETH.submit{ value: msg.value }();
        _mint(msg.sender, shares);
    }

    /**
     * @notice Get amount of wdivETH for a given amount of divETH
     * @param _divETHAmount amount of divETH
     * @return Amount of wdivETH for a given divETH amount
     */
    function getWdivETHByDivETH(uint256 _divETHAmount) external view returns (uint256) {
        return divETH.getSharesByEth(_divETHAmount);
    }

    /**
     * @notice Get amount of divETH for a given amount of wdivETH
     * @param _wdivETHAmount amount of wdivETH
     * @return Amount of divETH for a given wdivETH amount
     */
    function getDivETHByWdivETH(uint256 _wdivETHAmount) external view returns (uint256) {
        return divETH.getEthByShares(_wdivETHAmount);
    }

    /**
     * @notice Get amount of divETH for a one wdivETH
     * @return Amount of divETH for 1 wdivETH
     */
    function divETHPerToken() external view returns (uint256) {
        return divETH.getEthByShares(1 ether);
    }

    /**
     * @notice Get amount of wdivETH for a one divETH
     * @return Amount of wdivETH for a 1 divETH
     */
    function tokensPerDivEth() external view returns (uint256) {
        return divETH.getSharesByEth(1 ether);
    }
}
