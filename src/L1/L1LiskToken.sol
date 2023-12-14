// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract L1LiskToken is ERC20Burnable, AccessControl, ERC20Permit {
    string private constant NAME = "Lisk";
    string private constant SYMBOL = "LSK";
    uint256 private constant TOTAL_SUPPLY = 300_000_000 * 10 ** 18; //300 million LSK tokens

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor() ERC20(NAME, SYMBOL) ERC20Permit(NAME) {
        _setRoleAdmin(BURNER_ROLE, DEFAULT_ADMIN_ROLE);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    function transferOwnership(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(DEFAULT_ADMIN_ROLE, account);
        _revokeRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function isBurner(address account) public view returns (bool) {
        return hasRole(BURNER_ROLE, account);
    }

    function addBurner(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(BURNER_ROLE, account);
    }

    function renounceBurner(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(BURNER_ROLE, account);
    }

    function burn(uint256 value) public override onlyRole(BURNER_ROLE) {
        super.burn(value);
    }

    function burnFrom(address account, uint256 value) public override onlyRole(BURNER_ROLE) {
        super.burnFrom(account, value);
    }
}
