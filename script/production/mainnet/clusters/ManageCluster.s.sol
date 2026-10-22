// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant ezETH = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
    address internal constant rsETH = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
    address internal constant tETH = 0xD11c452fc99cF405034ee446803b6F6c1F6d5ED8;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant USDtb = 0xC139190F447e929f090Edeb554D95AbB8b18aC1C;
    address internal constant TBILL = 0xdd50C053C096CB04A3e3362E2b622529EC5f2e8a;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant LBTC = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address internal constant xAUt = 0x68749665FF8D2d112Fa859AA293F07A622782F38;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
