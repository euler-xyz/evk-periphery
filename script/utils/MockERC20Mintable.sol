// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

contract MockERC20Mintable is Ownable, ERC20 {
    uint8 internal immutable _decimals;

    constructor(address owner_, string memory name_, string memory symbol_, uint8 decimals_)
        Ownable(owner_)
        ERC20(name_, symbol_)
    {
        _decimals = decimals_;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }
}
