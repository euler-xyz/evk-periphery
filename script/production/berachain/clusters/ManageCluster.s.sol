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
    address internal constant LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;
    address internal constant HONEY = 0xFCBD14DC51f0A4d49d5E53C2E0950e0bC26d0Dce;
    address internal constant USDC = 0x549943e04f40284185054145c6E4e9568C1D3241;
    address internal constant STONE = 0xEc901DA9c68E90798BbBb74c11406A32A70652C3;
    address internal constant BYUSD = 0x688e72142674041f8f6Af4c808a4045cA1D6aC82;
    address internal constant oriBGT = 0x69f1E971257419B1E9C405A553f252c64A29A30a;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
