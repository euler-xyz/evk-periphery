// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal constant USDT0 = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address internal constant sUSDS = 0xdDb46999F8891663a8F2828d25298f70416d7610;
    address internal constant sUSDC = 0x940098b108fB7D0a7E374f6eDED7760787464609;
    address internal constant wstETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address internal constant weETH = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
    address internal constant rsETH = 0x4186BFC76E2E237523CBC30FD220FE055156b41F;
    address internal constant tETH = 0xd09ACb80C1E8f2291862c4978A008791c9167003;
    address internal constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address internal constant ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
