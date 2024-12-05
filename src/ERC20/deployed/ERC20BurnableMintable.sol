// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "openzeppelin-contracts/access/extensions/AccessControlEnumerable.sol";
import {ERC20, ERC20Burnable} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Permit} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Permit.sol";

contract ERC20BurnableMintable is AccessControlEnumerable, ERC20Burnable, ERC20Permit {
    bytes32 public constant REVOKE_MINTER_ROLE = keccak256("REVOKE_MINTER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint8 internal immutable _decimals;

    constructor(address admin_, string memory name_, string memory symbol_, uint8 decimals_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _decimals = decimals_;
    }

    function revokeMinterRole(address minter) external onlyRole(REVOKE_MINTER_ROLE) {
        _revokeRole(MINTER_ROLE, minter);
    }

    function mint(address _account, uint256 _amount) external onlyRole(MINTER_ROLE) {
        _mint(_account, _amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }
}
