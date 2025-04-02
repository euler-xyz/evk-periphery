// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant WBTC = 0x03C7054BCB39f7b2e5B2c7AcB37583e32D70Cfa3;
    address internal constant LBTC = 0xA45d4121b3D47719FF57a947A9d961539Ba33204;
    address internal constant HybridBTC = 0x9998e05030Aee3Af9AD3df35A34F5C51e1628779;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}