// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    uint16 internal constant LTV_ZERO = 0.0e4;
    uint16 internal constant LTV__LOW = 0.91e4;
    uint16 internal constant LTV_HIGH = 0.95e4;

    address internal immutable IRM_ADAPTIVE_USD = 0xf41D1f354f04A2887682ba3585Bf6cCca0a24551;
    address internal immutable IRM_ADAPTIVE_ETH = 0x3e1c4532134Bf9c2cA864C98C52a830E0571E0E1;
    address internal immutable IRM_ADAPTIVE_ETH_YB = 0x6D30Bf70411dE9d527E67E6bfD5304B1e1d0c4Be;
    address internal immutable IRM_ADAPTIVE_DEFI = 0x2a6f7b01d64bB308f3a70e7183246C49EAa102b0;

    address internal constant USD = address(840);
    address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant WETH = 0x9895D81bB462A195b4922ED7De0e3ACD007c32CB;
    address internal constant WXPL = 0x6100E367285b01F48D07953803A2d8dCA5D19873;
    address internal constant USDT0 = 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb;
    address internal constant WEETH = 0xA3D68b74bF0528fdD07263c60d6488749044914b;
    address internal constant XAUT0 = 0x1B64B9025EEbb9A6239575dF9Ea4b9Ac46D4d193;
    address internal constant USDe = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address internal constant sUSDe = 0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2;
    address internal constant ENA = 0x58538e6A46E07434d7E7375Bc268D3cb839C0133;
    address internal constant USDai = 0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF;
    address internal constant sUSDai = 0x0B2b2B2076d95dda7817e785989fE353fe955ef9;
    address internal constant USDO = 0x87e617C7484aDE79FcD90db58BEB82B057facb48;
    address internal constant cUSDO = 0xbEeE5862649eF24c1F1d5e799505F67F1e7bAB9a;
    address internal constant rsETH = 0x9eCaf80c1303CCA8791aFBc0AD405c8a35e8d9f1;
    address internal constant wrsETH = 0xe561FE05C39075312Aa9Bc6af79DdaE981461359;
    address internal constant syrupUSDT = address(0);
    address internal constant wstUSR = address(0);
    address internal constant USR = address(0);
    address internal constant RLP = address(0);
    address internal constant sxyUSD = address(0);
    address internal constant xyUSD = address(0);
    address internal constant NUSD = address(0);
    address internal constant EUROP = address(0);
    address internal constant GHO = address(0);
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
