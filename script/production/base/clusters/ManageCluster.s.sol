// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant USD = address(840);
    address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant wstETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
    address internal constant cbETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address internal constant weETH = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;
    address internal constant ezETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
    address internal constant RETH = 0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c;
    address internal constant wsuperOETHb = 0x7FcD174E80f264448ebeE8c88a7C4476AAF58Ea6;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant USDT0 = 0x102d758f688a4C1C5a80b116bD945d4455460282;
    address internal constant USDS = 0x820C137fa70C8691f0e44Dc420a5e53c168921Dc;
    address internal constant SUSDS = 0x5875eEE11Cf8398102FdAd704C9E96607675467a;
    address internal constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
    address internal constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant LBTC = 0xecAc9C5F704e954931349Da37F60E39f515c11c1;
    address internal constant AERO = 0x940181a94A35A4569E4529A3CDfB74e38FD98631;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
