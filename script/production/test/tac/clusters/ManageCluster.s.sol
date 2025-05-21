// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant mUSDC = 0x990e64388dB00EFf7a9C9f01c3748d5401Df5082;
    address internal constant mWETH = 0x3B0DE40DdCAa337CEBc1ba435c77c656AF286CA8;
    address internal constant mTON = 0xc981cd0aC047D1Bc55aF4B6A9cF7fA82465363D0;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
