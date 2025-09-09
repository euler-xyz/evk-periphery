// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal constant USDT0 = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address internal constant USDS = 0x6491c05A82219b8D1479057361ff1654749b876b;
    address internal constant sUSDS = 0xdDb46999F8891663a8F2828d25298f70416d7610;
    address internal constant sUSDC = 0x940098b108fB7D0a7E374f6eDED7760787464609;
    address internal constant USDe = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address internal constant sUSDe = 0x211Cc4DD073734dA055fbF44a2b4667d5E5fE5d2;
    address internal constant USR = 0x2492D0006411Af6C8bbb1c8afc1B0197350a79e9;
    address internal constant wstUSR = 0x66CFbD79257dC5217903A36293120282548E2254;
    address internal constant RLP = 0x35E5dB674D8e93a03d814FA0ADa70731efe8a4b9;
    address internal constant USDai = 0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF;
    address internal constant sUSDai = 0x0B2b2B2076d95dda7817e785989fE353fe955ef9;
    address internal constant thBILL = 0xfDD22Ce6D1F66bc0Ec89b20BF16CcB6670F55A5a;
    address internal constant syrupUSDC = 0x41CA7586cC1311807B4605fBB748a3B8862b42b5;
    address internal constant wstETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address internal constant weETH = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe;
    address internal constant rsETH = 0x4186BFC76E2E237523CBC30FD220FE055156b41F;
    address internal constant tETH = 0xd09ACb80C1E8f2291862c4978A008791c9167003;
    address internal constant ezETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
    address internal constant rETH = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8;
    address internal constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address internal constant ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;
    address internal constant PT_USDai_20NOV2025 = 0x8b4Ca42bB3B1d789859f106222CF7DC5EEd48CCb;
    address internal constant PT_sUSDai_20NOV2025 = 0x936F210d277bf489A3211CeF9AB4BC47a7B69C96;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
