// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant AVAX = 0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7;
    address internal constant BTC_b = 0x152b9d0FdC40C096757F570A51E494bd4b943E50;
    address internal constant wETH_e = 0x49D5c2BdFfac6CE2BFdB6640F4F80f226bc10bAB;
    address internal constant USDC = 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E;
    address internal constant sAVAX = 0x2b2C81e08f1Af8835a78Bb2A90AE924ACE0eA4bE;
    address internal constant ggAVAX = 0xA25EaF2906FA1a3a13EdAc9B9657108Af7B703e3;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
