// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    //uint16 internal constant LTV_ZERO = 0.0e4;
    //uint16 internal constant LTV__LOW = 0.91e4;
    //uint16 internal constant LTV_HIGH = 0.95e4;
    //uint16 internal constant LTV_SELF = 0.97e4;

    //address internal immutable IRM_ADAPTIVE_USD = 0xf41D1f354f04A2887682ba3585Bf6cCca0a24551;
    //address internal immutable IRM_ADAPTIVE_PT_7 = 0x32fd5B7a2C75aFc3Bd929c2746cF9E4522E75690;
    //address internal immutable IRM_ADAPTIVE_PT_30 = 0xe2C4daAeeBd8e45E49c8768D50da7646d8B28514;
    //address internal immutable IRM_ADAPTIVE_ETH = 0x3e1c4532134Bf9c2cA864C98C52a830E0571E0E1;
    //address internal immutable IRM_ADAPTIVE_ETH_YB = 0x6D30Bf70411dE9d527E67E6bfD5304B1e1d0c4Be;
    //address internal immutable IRM_ADAPTIVE_DEFI = 0x2a6f7b01d64bB308f3a70e7183246C49EAa102b0;

    address internal constant USD = address(840);
    address internal constant eUSD = 0xf13DAcAdA8f45c2b2Cbf60eCb1D412d0C57bf2F8;
    address internal constant AUSD = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a;
    address internal constant MON = 0x0000000000000000000000000000000000000000;
    address internal constant SOL = 0xea17E5a9efEBf1477dB45082d67010E2245217f1;
    address internal constant USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;
    address internal constant USDT = 0xe7cd86e13AC4309349F30B3435a9d337750fC82D;
    address internal constant WETH = 0xEE8c0E9f1BFFb4Eb878d8f15f368A02a35481242;
    address internal constant WMON = 0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A;
    address internal constant XAUT0 = 0x01bFF41798a0BcF287b996046Ca68b395DbC1071;
    address internal constant suBTC = 0xe85411C030fB32A9D8b14Bbbc6CB19417391F711;
    address internal constant suETH = 0x1c22531AA9747d76fFF8F0A43b37954ca67d28e0;
    address internal constant suUSD = 0x8BF591Eae535f93a242D5A954d3Cde648b48A5A8;
    address internal constant WBTC = address(0);
    address internal constant FBTC = address(0);
    address internal constant weETH = address(0);
    address internal constant wstETH = address(0);
    address internal constant shMON = address(0);
    address internal constant gMON = address(0);
    address internal constant sMON = address(0);
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
