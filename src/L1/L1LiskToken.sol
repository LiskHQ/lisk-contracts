// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

contract L1LiskToken is ERC20Burnable, AccessControl, ERC20Permit {
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    string private constant NAME = "Lisk";
    string private constant SYMBOL = "LSK";
    uint256 private constant TOTAL_SUPPLY = 200_000_000 * 10 ** 18; //200 million LSK tokens

    constructor() ERC20(NAME, SYMBOL) ERC20Permit(NAME) {
        bytes32 admin = bytes32(uint256(uint160(_msgSender())));
        _setRoleAdmin(DEFAULT_ADMIN_ROLE, admin);
        _setRoleAdmin(BURNER_ROLE, admin);
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _mint(_msgSender(), TOTAL_SUPPLY);
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

    function getBurnerRole() external pure returns (bytes32) {
        return BURNER_ROLE;
    }
}
