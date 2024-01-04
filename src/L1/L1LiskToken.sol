// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title L1LiskToken
/// @notice L1LiskToken is an implementation of ERC20 token and is an extension of AccessControl, ERC20Permit and
///         ERC20Burnable token contracts.
///         It maintains the ownership of the deployed contract and only allows the owners to transfer the ownership.
///         L1LiskToken's only allows burners to burn the total supply and only the owner manages burner accounts.
contract L1LiskToken is ERC20Burnable, AccessControl, ERC20Permit {
    /// @notice Name of the token.
    string private constant NAME = "Lisk";

    /// @notice Symbol of the token.
    string private constant SYMBOL = "LSK";

    /// @notice Total supply of the token.
    uint256 private constant TOTAL_SUPPLY = 300_000_000 * 10 ** 18; //300 million LSK tokens

    /// @notice Burner role.
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Constructs the L1LiskToken contract.
    constructor() ERC20(NAME, SYMBOL) ERC20Permit(NAME) {
        _setRoleAdmin(BURNER_ROLE, DEFAULT_ADMIN_ROLE);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    /// @notice Allows the owner to transfer the ownership of the contract.
    /// @param account The new owner of the contract.
    function transferOwnership(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DEFAULT_ADMIN_ROLE, account);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /// @notice Verifies if an account is a burner.
    /// @param account Account to be verified.
    /// @return Whether or not the provided account is a burner.
    function isBurner(address account) public view returns (bool) {
        return hasRole(BURNER_ROLE, account);
    }

    /// @notice Allows the owner to grant burner role to an account.
    /// @param account Account to be added as a burner.
    function addBurner(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(BURNER_ROLE, account);
    }

    /// @notice Allows the owner to revoke burner role from an account.
    /// @param account Account to removed as a burner.
    function renounceBurner(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(BURNER_ROLE, account);
    }

    /// @notice Allows a burner to burn token.
    /// @param value Amount to be burned.
    function burn(uint256 value) public override onlyRole(BURNER_ROLE) {
        super.burn(value);
    }

    /// @notice Allows a burner to burn its allowance from an account.
    /// @param account Account to burn tokens from.
    /// @param value Amount to burned.
    function burnFrom(address account, uint256 value) public override onlyRole(BURNER_ROLE) {
        super.burnFrom(account, value);
    }
}
