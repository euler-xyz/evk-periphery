// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant WETH = 0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590;
    address internal constant WBERA = 0x6969696969696969696969696969696969696969;
    address internal constant beraETH = 0x6fc6545d5cDE268D5C7f1e476D444F39c995120d;
    address internal constant WBTC = 0x0555E30da8f98308EdB960aa94C0Db47230d2B9c;
    address internal constant HONEY = 0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce;
    address internal constant USDC = 0x549943e04f40284185054145c6E4e9568C1D3241;
    address internal constant STONE = 0xEc901DA9c68E90798BbBb74c11406A32A70652C3;
    address internal constant BYUSD = 0x688e72142674041f8f6Af4c808a4045cA1D6aC82;
    address internal constant NECT = 0x1cE0a25D13CE4d52071aE7e02Cf1F6606F4C79d3;
    address internal constant USDe = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address internal constant sUSDe = 0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2;
    address internal constant rUSD = 0x09D4214C03D01F49544C0448DBE3A27f768F2b34;
    address internal constant srUSD = 0x5475611Dffb8ef4d697Ae39df9395513b6E947d7;
    address internal constant PT_sUSDE = 0x2719e657ec3B3CbE521a18E640CA55799836376f;
    address internal constant iBERA = 0x9b6761bf2397Bb5a6624a856cC84A3A14Dcd3fe5;
    address internal constant iBGT = 0xac03CABA51e17c86c921E1f6CBFBdC91F8BB2E6b;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
