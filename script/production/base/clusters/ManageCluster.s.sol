// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant EULER_DAO_MULTISIG = 0x1e13B0847808045854Ddd908F2d770Dc902Dcfb8;
    address internal constant GOVERNOR_ACCESS_CONTROL = 0x223c87de4e41448adfDe6F4F93D9bD4DEA9d88d1;

    address internal constant USD = address(840);
    address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant WETH = 0x4200000000000000000000000000000000000006;
    address internal constant wstETH = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452;
    address internal constant cbETH = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22;
    address internal constant WEETH = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A;
    address internal constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address internal constant EURC = 0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42;
    address internal constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
