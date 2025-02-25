// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant SolvBTC = 0x541FD749419CA806a8bc7da8ac23D346f2dF8B77;
    address internal constant SolvBTC_BBN = 0xCC0966D8418d412c599A6421b760a847eB169A8c;
    address internal constant tBTC = 0xBBa2eF945D523C4e2608C9E1214C2Cc64D4fc2e2;
    address internal constant uniBTC = 0x236f8c0a61dA474dB21B693fB2ea7AAB0c803894;
    address internal constant WBTC = 0x03C7054BCB39f7b2e5B2c7AcB37583e32D70Cfa3;
    address internal constant USDCe = 0xe75D0fB2C24A55cA1e3F96781a2bCC7bdba058F0;
    address internal constant HybridBTC_pendle = 0x9998e05030Aee3Af9AD3df35A34F5C51e1628779;
    address internal constant LBTC = 0xA45d4121b3D47719FF57a947A9d961539Ba33204;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
