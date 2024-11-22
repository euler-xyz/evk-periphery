// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageClusterBase} from "../../ManageClusterBase.s.sol";

abstract contract Addresses {
    address internal constant EULER_DEPLOYER = 0xEe009FAF00CF54C1B4387829aF7A8Dc5f0c8C8C5;
    address internal constant EULER_DAO_MULTISIG = 0xcAD001c30E96765aC90307669d578219D4fb1DCe;

    address internal constant USD = address(840);
    address internal constant BTC = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant cbETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address internal constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant ezETH = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
    address internal constant RETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address internal constant METH = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa;
    address internal constant RSETH = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
    address internal constant sfrxETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address internal constant ETHx = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
    address internal constant rswETH = 0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant PYUSD = 0x6c3ea9036406852006290770BEdFcAbA0e23A0e8;
    address internal constant USDY = 0x96F6eF951840721AdBF46Ac996b59E0235CB985C;
    address internal constant wM = 0x437cc33344a0B27A429f795ff6B469C72698B291;
    address internal constant mTBILL = 0xDD629E5241CbC5919847783e6C96B2De4754e438;
    address internal constant USDe = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address internal constant wUSDM = 0x57F5E098CaD7A3D1Eed53991D4d66C45C9AF7812;
    address internal constant EURC = 0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c;
    address internal constant sUSDe = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address internal constant USDS = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address internal constant sUSDS = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address internal constant stUSD = 0x0022228a2cc5E7eF0274A7Baa600d44da5aB5776;
    address internal constant stEUR = 0x004626A008B1aCdC4c74ab51644093b155e59A23;
    address internal constant FDUSD = 0xc5f0f7b66764F6ec8C8Dff7BA683102295E16409;
    address internal constant USD0 = 0x73A15FeD60Bf67631dC6cd7Bc5B6e8da8190aCF5;
    address internal constant USD0PlusPlus = 0x35D8949372D46B7a3D5A56006AE77B215fc69bC0;
    address internal constant GHO = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    address internal constant crvUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    address internal constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address internal constant tBTC = 0x18084fbA666a33d37592fA2633fD49a74DD93a88;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant LBTC = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address internal constant eBTC = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642;
    address internal constant SOLVBTC = 0x7A56E1C57C7475CCf742a1832B028F0456652F97;
    address internal constant pumpBTC = 0xF469fBD2abcd6B9de8E169d128226C0Fc90a012e;
    address internal constant PT_LBTC_27MAR2025 = 0xEc5a52C685CC3Ad79a6a347aBACe330d69e0b1eD;
    address internal constant PT_corn_LBTC_26DEC2024 = 0x332A8ee60EdFf0a11CF3994b1b846BBC27d3DcD6;
    address internal constant PT_eBTC_26DEC2024 = 0xB997B3418935A1Df0F914Ee901ec83927c1509A0;
    address internal constant PT_corn_eBTC_27MAR2025 = 0x44A7876cA99460ef3218bf08b5f52E2dbE199566;
    address internal constant PT_corn_pumpBTC_26DEC2024 = 0xa76f0C6e5f286bFF151b891d2A0245077F1Ad74c;
    address internal constant PT_pumpBTC_27MAR2025 = 0x997Ec6Bf18a30Ef01ed8D9c90718C7726a213527;
    address internal constant PT_solvBTC_26DEC2024 = 0x23e479ddcda990E8523494895759bD98cD2fDBF6;
    address internal constant PT_USD0PlusPlus_27MAR2025 = 0x5BaE9a5D67d1CA5b09B14c91935f635CFBF3b685;
    address internal constant PT_USD0PlusPlus_26JUN2025 = 0xf696FE29Ef85E892b5926313897D178288faA07e;
}

abstract contract ManageCluster is ManageClusterBase, Addresses {}
