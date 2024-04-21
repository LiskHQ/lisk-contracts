// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.23;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title L1LiskToken
/// @notice L1LiskToken is an implementation of ERC20 token and is an extension of AccessControl, Ownable2Step,
/// ERC20Permit and ERC20Burnable token contracts. It maintains the ownership of the deployed contract and only allows
/// the owners to transfer the ownership. The L1LiskToken exclusively authorizes burners to reduce the total supply,
/// while the management of burner accounts is solely under the domain of the owner.
contract L1LiskToken is ERC20Burnable, AccessControl, Ownable2Step, ERC20Permit {
    /// @notice Name of the token.
    string private constant NAME = "Lisk";

    /// @notice Symbol of the token.
    string private constant SYMBOL = "LSK";

    /// @notice Total supply of the token.
    uint256 private constant TOTAL_SUPPLY = 400_000_000 * 10 ** 18; //400 million LSK tokens

    /// @notice A unique role identifier for accounts with the ability to burn tokens.
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Constructs the L1LiskToken contract.
    constructor() ERC20(NAME, SYMBOL) ERC20Permit(NAME) Ownable(msg.sender) {
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    /// @notice Check if an account has the burner role.
    /// @param account The account to check.
    /// @return True if the account has the burner role, false otherwise.
    function isBurner(address account) public view returns (bool) {
        return hasRole(BURNER_ROLE, account);
    }

    /// @notice Assign the burner role to an account.
    /// @param account The account to be assigned the burner role.
    /// @dev Only callable by the owner.
    function addBurner(address account) public onlyOwner {
        _grantRole(BURNER_ROLE, account);
    }

    /// @notice Remove the burner role from an account.
    /// @param account The account to remove the burner role from.
    /// @dev Only callable by the owner.
    function renounceBurner(address account) public onlyOwner {
        _revokeRole(BURNER_ROLE, account);
    }

    /// @notice Burn tokens from the caller's account.
    /// @param value The amount of tokens to burn.
    /// @dev Requires BURNER_ROLE.
    function burn(uint256 value) public override onlyRole(BURNER_ROLE) {
        super.burn(value);
    }

    /// @notice Burn tokens from another account, deducting from the caller's allowance.
    /// @param account The account to burn tokens from.
    /// @param value   The amount of tokens to be burned.
    /// @dev Requires BURNER_ROLE.
    function burnFrom(address account, uint256 value) public override onlyRole(BURNER_ROLE) {
        super.burnFrom(account, value);
    }
}
