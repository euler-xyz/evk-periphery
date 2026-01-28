// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ERC4626EVCCollateralCapped} from "../implementation/ERC4626EVCCollateralCapped.sol";

contract ERC4626EVCCollatralCork is ERC4626EVCCollateralCapped{
    address immutable public controller;

    constructor(address _admin, address _controller) ERC4626EVCCollateralCapped(_admin) {
        controller = _controller;
    }

    function balanceOf(address account) view public virtual override returns (uint256) {
        return msg.sender == controller ? uint256(uint160(account)) : super.balanceOf(account);
    }
}