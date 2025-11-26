// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant eUSD = 0xf13DAcAdA8f45c2b2Cbf60eCb1D412d0C57bf2F8;
    address internal constant AUSD = 0x00000000eFE302BEAA2b3e6e1b18d08D69a9012a;
    address internal constant SOL = 0xea17E5a9efEBf1477dB45082d67010E2245217f1;
    address internal constant USDC = 0x754704Bc059F8C67012fEd69BC8A327a5aafb603;
    address internal constant USDT = 0xe7cd86e13AC4309349F30B3435a9d337750fC82D;
    address internal constant WETH = 0xEE8c0E9f1BFFb4Eb878d8f15f368A02a35481242;
    address internal constant WMON = 0x3bd359C1119dA7Da1D913D1C4D2B7c461115433A;
    address internal constant XAUT0 = 0x01bFF41798a0BcF287b996046Ca68b395DbC1071;
    address internal constant suBTC = 0xe85411C030fB32A9D8b14Bbbc6CB19417391F711;
    address internal constant suETH = 0x1c22531AA9747d76fFF8F0A43b37954ca67d28e0;
    address internal constant suUSD = 0x8BF591Eae535f93a242D5A954d3Cde648b48A5A8;
    address internal constant WBTC = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c;
    address internal constant FBTC = address(0);
    address internal constant LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;
    address internal constant BTCb = 0xB0F70C0bD6FD87dbEb7C10dC692a2a6106817072;
    address internal constant weETH = address(0);
    address internal constant wstETH = 0x10Aeaf63194db8d453d4D85a06E5eFE1dd0b5417;
    address internal constant shMON = 0x1B68626dCa36c7fE922fD2d55E4f631d962dE19c;
    address internal constant gMON = 0x8498312A6B3CbD158bf0c93AbdCF29E6e4F55081;
    address internal constant sMON = 0xA3227C5969757783154C60bF0bC1944180ed81B9;
    address internal constant MVT = 0x04f8c38AE80BcF690B947f60F62BdA18145c3D67;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
