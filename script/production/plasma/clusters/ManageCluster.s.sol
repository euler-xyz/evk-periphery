// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    uint16 internal constant LTV_ZERO = 0.0e4;
    uint16 internal constant LTV__LOW = 0.91e4;
    uint16 internal constant LTV_HIGH = 0.95e4;
    uint16 internal constant LTV_SELF = 0.97e4;

    address internal immutable IRM_ADAPTIVE_USD = 0xf41D1f354f04A2887682ba3585Bf6cCca0a24551;
    address internal immutable IRM_ADAPTIVE_PT_7 = 0x32fd5B7a2C75aFc3Bd929c2746cF9E4522E75690;
    address internal immutable IRM_ADAPTIVE_PT_30 = 0xe2C4daAeeBd8e45E49c8768D50da7646d8B28514;
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
    address internal constant syrupUSDT = 0xC4374775489CB9C56003BF2C9b12495fC64F0771;
    address internal constant wstUSR = 0x2a52B289bA68bBd02676640aA9F605700c9e5699;
    address internal constant USR = 0xb1b385542B6E80F77B94393Ba8342c3Af699f15c;
    address internal constant RLP = 0x35533f54740F1F1aA4179E57bA37039dfa16868B;
    address internal constant rUSD = 0x09D4214C03D01F49544C0448DBE3A27f768F2b34;
    address internal constant wsrUSD = 0x4809010926aec940b550D34a46A52739f996D75D;
    address internal constant deUSD = 0x4ac60586C3e245fF5593cf99241395bf42509274;
    address internal constant sdeUSD = 0x7884A8457f0E63e82C89A87fE48E8Ba8223DB069;
    address internal constant plUSD = 0xf91c31299E998C5127Bc5F11e4a657FC0cF358CD;
    address internal constant splUSD = 0x616185600989Bf8339b58aC9e539d49536598343;
    address internal constant yUSD = 0x4772D2e014F9fC3a820C444e3313968e9a5C8121;
    address internal constant sxyUSD = address(0);
    address internal constant xyUSD = address(0);
    address internal constant NUSD = address(0);
    address internal constant EUROP = address(0);
    address internal constant GHO = 0xfc421aD3C883Bf9E7C4f42dE845C4e4405799e73;
    address internal constant PT_USDe_15JAN2026 = 0x93B544c330F60A2aa05ceD87aEEffB8D38FD8c9a;
    address internal constant PT_sUSDe_15JAN2026 = 0x02FCC4989B4C9D435b7ceD3fE1Ba4CF77BBb5Dd8;
    address internal constant PT_syrupUSDT_29JAN2026 = 0x8dFb9A39dFab16bFFE77f15544B5bf03e377e419;
    address internal constant PT_USDai_19MAR2026 = 0xD516188daf64EFa04a8d60872F891f2cC811A561;
    address internal constant PT_sUSDai_19MAR2026 = 0xedac81b27790e0728f54dEa3B7718e5437E85353;
    address internal constant PT_RLP_26FEB2026 = 0x48F119b3fCA8244274531f2e06B74AC4B1F5fe58;
    address internal constant PT_wstUSR_26FEB2026 = 0xFFaF49f320b8Ae1Bb9Ea596197040077a3666105;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
