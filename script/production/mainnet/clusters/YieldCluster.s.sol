// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";

import "forge-std/console.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/mainnet/clusters/YieldCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            USDC,
            USDT,
            rlUSD,
            wM,
            USD0PlusPlus,
            USDe,
            eUSDe,
            sUSDe,
            frxUSD,
            sfrxUSD,
            USD1,
            mUSD,
            TBILL,
            PT_USDe_27NOV2025,
            PT_USDe_05FEB2026,
            PT_sUSDe_27NOV2025,
            PT_sUSDe_05FEB2026,
            PT_cUSDO_20NOV2025,
            PT_cUSDO_28MAY2026,
            PT_tUSDe_18DEC2025,
            PT_pUSDe_16OCT2025,
            PT_srUSDe_15JAN2026,
            PT_jrUSDe_15JAN2026,
            PT_srUSDe_02APR2026,
            PT_jrUSDe_02APR2026,
            PT_alUSD_11DEC2025,
            PT_cUSD_29JAN2026,
            PT_stcUSD_29JAN2026
        ];
    }

    function configureCluster() internal override {

        // define the governors here
        cluster.oracleRoutersGovernor = governorAddresses.accessControlEmergencyGovernor;
        cluster.vaultsGovernor = governorAddresses.accessControlEmergencyGovernor;

        // define unit of account here
        cluster.unitOfAccount = USD;

        // define fee receiver here and interest fee here. if needed to be defined per asset, populate the feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = address(0);
        cluster.interestFee = 0.1e4;

        // define max liquidation discount here. if needed to be defined per asset, populate the maxLiquidationDiscountOverride mapping
        cluster.maxLiquidationDiscount = 0.15e4;

        // define liquidation cool off time here. if needed to be defined per asset, populate the liquidationCoolOffTimeOverride mapping
        cluster.liquidationCoolOffTime = 1;

        // define hook target and hooked ops here. if needed to be defined per asset, populate the hookTargetOverride and hookedOpsOverride mappings
        cluster.hookTarget = address(0);
        cluster.hookedOps = 0;

        // define config flags here. if needed to be defined per asset, populate the configFlagsOverride mapping
        cluster.configFlags = 0;

        // define oracle providers here. 
        // adapter names can be found in the relevant adapter contract (as returned by the `name` function).
        // for cross adapters, use the following format: "CrossAdapter=<adapterName1>+<adapterName2>".
        // although Redstone Classic oracles reuse the ChainlinkOracle contract and returns "ChainlinkOracle" name, 
        // they should be referred to as "RedstoneClassicOracle".
        // in case the asset is an ERC4626 vault itself (i.e. sUSDS) and is recognized as a valid external vault as per 
        // External Vaults Registry, the string should be preceeded by "ExternalVault|" prefix. this is in order to resolve 
        // the asset (vault) in the oracle router.
        // in case the adapter is not present in the Adapter Registry, the adapter address can be passed instead in form of a string.
        cluster.oracleProviders[USDC                     ] = "0x6213f24332D35519039f2afa7e3BffE105a37d3F";
        cluster.oracleProviders[USDT                     ] = "0x587CABe0521f5065b561A6e68c25f338eD037FF9";
        cluster.oracleProviders[rlUSD                    ] = "0x3bDcB804Fd42Ccb2B7Cf329fa07724bEcB872970";
        cluster.oracleProviders[wM                       ] = "FixedRateOracle";
        cluster.oracleProviders[USD0PlusPlus             ] = "PythOracle";
        cluster.oracleProviders[USDe                     ] = "0x93840A424aBc32549809Dd0Bc07cEb56E137221C";
        cluster.oracleProviders[eUSDe                    ] = "ExternalVault|0x93840A424aBc32549809Dd0Bc07cEb56E137221C";
        cluster.oracleProviders[sUSDe                    ] = "ExternalVault|0x93840A424aBc32549809Dd0Bc07cEb56E137221C";
        cluster.oracleProviders[frxUSD                   ] = "0x252e25BD698EA17945419A705a783242e1e656a7";
        cluster.oracleProviders[sfrxUSD                  ] = "ExternalVault|0x252e25BD698EA17945419A705a783242e1e656a7";
        cluster.oracleProviders[USD1                     ] = "0x1d55c9DeaE096e2D5D2427E67505238334Fa0eaB";
        cluster.oracleProviders[mUSD                     ] = "0xb5004f2e4bcb95be4ba61a891ca3bb63bb31ffb4";
        cluster.oracleProviders[TBILL                    ] = "0x3577A7eA55fD30D489640791BA903B6FA278B840";
        cluster.oracleProviders[PT_USDe_27NOV2025        ] = "0x3FC2228E67D131dE974A0A42FB2E1A94D71b4F12";
        cluster.oracleProviders[PT_USDe_05FEB2026        ] = "0x6a569EfB73AeA68a3B93Fb9Deb659074Aaa84DC7";
        cluster.oracleProviders[PT_sUSDe_27NOV2025       ] = "0x56292911Ae5993C25948EE24273734e6abEc1832";
        cluster.oracleProviders[PT_sUSDe_05FEB2026       ] = "0xF6151700c3C1d5de33319171Bfe5174b705E6683";
        cluster.oracleProviders[PT_cUSDO_20NOV2025       ] = "0x673222872a407775feab95a7a98f930a2cec53f4";
        cluster.oracleProviders[PT_cUSDO_28MAY2026       ] = "0xA625CbAEFFe19374ED9df500C9ed87D4d962c564";
        cluster.oracleProviders[PT_tUSDe_18DEC2025       ] = "0xd7440B786f38ab805d94f6A8F3ee398B8340CD22";
        cluster.oracleProviders[PT_pUSDe_16OCT2025       ] = "0xCA5B7044BE73671FD6707C2312cEC7C07556B85f";
        cluster.oracleProviders[PT_srUSDe_15JAN2026      ] = "0x5ae8C1300245eAE3f64625FAA20EC9c35A78c275";
        cluster.oracleProviders[PT_jrUSDe_15JAN2026      ] = "0xffE3b09B0647cD496D37815F9C8540Dca9FaB24E";
        cluster.oracleProviders[PT_srUSDe_02APR2026      ] = "0xb0BAa4DC6AF4f2C1541Ee4eA4AfE01A4183254F0";
        cluster.oracleProviders[PT_jrUSDe_02APR2026      ] = "0x566C246475B853B7DaFf705ad5c5E78753EeF5Dd";
        cluster.oracleProviders[PT_alUSD_11DEC2025       ] = "0xa5263145d8c9bfc89c7a55ea21fb5b617c7b6cff";
        cluster.oracleProviders[PT_cUSD_29JAN2026        ] = "0x55757d7db2811dd57b4edd5f3594aa7a9058dcc1";
        cluster.oracleProviders[PT_stcUSD_29JAN2026      ] = "0xcf8f3a674063c9cb253911718e4d120884972785";
        
        cluster.oracleProviders[sBUIDL                   ] = "ExternalVault|0x1CF7192cF739675186653D453828C0A670ed5Cd9";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[USDC                     ] = 300_000_000;
        cluster.supplyCaps[USDT                     ] = 100_000_000;
        cluster.supplyCaps[rlUSD                    ] = 200_000_000;
        cluster.supplyCaps[wM                       ] = 100_000;
        cluster.supplyCaps[USD0PlusPlus             ] = 100_000;
        cluster.supplyCaps[USDe                     ] = 20_000_000;
        cluster.supplyCaps[eUSDe                    ] = 60_000_000;
        cluster.supplyCaps[sUSDe                    ] = 100_000;
        cluster.supplyCaps[frxUSD                   ] = 10_000_000;
        cluster.supplyCaps[sfrxUSD                  ] = 100_000;
        cluster.supplyCaps[USD1                     ] = 100_000;
        cluster.supplyCaps[mUSD                     ] = 100_000;
        cluster.supplyCaps[TBILL                    ] = 0;//45_000_000;
        cluster.supplyCaps[PT_USDe_27NOV2025        ] = 100_000;
        cluster.supplyCaps[PT_USDe_05FEB2026        ] = 100_000;
        cluster.supplyCaps[PT_sUSDe_27NOV2025       ] = 100_000;
        cluster.supplyCaps[PT_sUSDe_05FEB2026       ] = 100_000;
        cluster.supplyCaps[PT_cUSDO_20NOV2025       ] = 0;
        cluster.supplyCaps[PT_cUSDO_28MAY2026       ] = 100_000;
        cluster.supplyCaps[PT_tUSDe_18DEC2025       ] = 100_000;
        cluster.supplyCaps[PT_pUSDe_16OCT2025       ] = 90_000_000;
        cluster.supplyCaps[PT_srUSDe_15JAN2026      ] = 10_000;
        cluster.supplyCaps[PT_jrUSDe_15JAN2026      ] = 10_000;
        cluster.supplyCaps[PT_srUSDe_02APR2026      ] = 20_000_000;
        cluster.supplyCaps[PT_jrUSDe_02APR2026      ] = 8_000_000;
        cluster.supplyCaps[PT_alUSD_11DEC2025       ] = 100_000;
        cluster.supplyCaps[PT_cUSD_29JAN2026        ] = 12_000_000;
        cluster.supplyCaps[PT_stcUSD_29JAN2026      ] = 5_000_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[USDC                     ] = 270_000_000;
        cluster.borrowCaps[USDT                     ] = 75_000_000;
        cluster.borrowCaps[rlUSD                    ] = 180_000_000;
        cluster.borrowCaps[wM                       ] = 0;
        cluster.borrowCaps[USD0PlusPlus             ] = 0;
        cluster.borrowCaps[USDe                     ] = 18_000_000;
        cluster.borrowCaps[eUSDe                    ] = 51_000_000;
        cluster.borrowCaps[sUSDe                    ] = 0;
        cluster.borrowCaps[frxUSD                   ] = 9_000_000;
        cluster.borrowCaps[sfrxUSD                  ] = 0;
        cluster.borrowCaps[USD1                     ] = 0;
        cluster.borrowCaps[mUSD                     ] = 0;
        cluster.borrowCaps[TBILL                    ] = 0;//type(uint256).max;
        cluster.borrowCaps[PT_USDe_27NOV2025        ] = 0;
        cluster.borrowCaps[PT_USDe_05FEB2026        ] = 0;
        cluster.borrowCaps[PT_sUSDe_27NOV2025       ] = 0;
        cluster.borrowCaps[PT_sUSDe_05FEB2026       ] = 0;
        cluster.borrowCaps[PT_cUSDO_20NOV2025       ] = 0;
        cluster.borrowCaps[PT_cUSDO_28MAY2026       ] = 0;
        cluster.borrowCaps[PT_tUSDe_18DEC2025       ] = 0;
        cluster.borrowCaps[PT_pUSDe_16OCT2025       ] = type(uint256).max;
        cluster.borrowCaps[PT_srUSDe_15JAN2026      ] = 0;
        cluster.borrowCaps[PT_jrUSDe_15JAN2026      ] = 0;
        cluster.borrowCaps[PT_srUSDe_02APR2026      ] = type(uint256).max;
        cluster.borrowCaps[PT_jrUSDe_02APR2026      ] = type(uint256).max;
        cluster.borrowCaps[PT_alUSD_11DEC2025       ] = 0;
        cluster.borrowCaps[PT_cUSD_29JAN2026        ] = type(uint256).max;
        cluster.borrowCaps[PT_stcUSD_29JAN2026      ] = type(uint256).max;

        // define IRM classes here and assign them to the assets
        {
            // Base=4.00% APY,  Kink(90.00%)=6.50% APY  Max=20.00% APY
            uint256[4] memory irm_USD_1_MEGA_YIELD = [uint256(1242854918307699700), uint256(194733605), uint256(8805534268), uint256(3865470566)];

            // Base=0% APY,  Kink(30%)=12.75% APY  Max=848.77% APY
            uint256[4] memory irm_USD_3_MEGA_YIELD = [uint256(0), uint256(2951312420), uint256(22450463582), uint256(1288490188)];

            // Base=0% APY,  Kink(30%)=2.00% APY  Max=80.00% APY
            uint256[4] memory irm_sUSDe            = [uint256(0), uint256(487019827), uint256(5986640502), uint256(1288490188)];

            cluster.kinkIRMParams[USDC        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USDT        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[rlUSD       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[wM          ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USD0PlusPlus] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[USDe        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[eUSDe       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[sUSDe       ] = irm_sUSDe;
            cluster.kinkIRMParams[frxUSD      ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USD1        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[mUSD        ] = irm_USD_1_MEGA_YIELD;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 30 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            cluster.spreadLTVOverride[24][i] = 0.050e4; // PT_jrUSDe_02APR2026 as collateral
        }

        cluster.spreadLTVOverride[6][5] = 0.01e4; // eUSDe/USDe
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                                  0               1       2       3       4       5       6        7       8       9       10      11      12      13      14      15      16      17      18      19      20      21      22      23      24      25      26      27      28      29      30      31      32      33      34      35      36      37      38      39
        //                                  USDC            USDT    rlUSD   wM      USD0++  USDe     eUSDe   sUSDe   AUSD    frxUSD  sfrxUSD USD1    mUSD    TBILL   PT_USDe_27NOV2025 PT_USDe_05FEB2026 PT_sUSDe_27NOV2025 PT_sUSDe_05FEB2026 PT_cUSDO_20NOV2025 PT_cUSDO_28MAY2026 PT_tUSDe_18DEC2025 PT_pUSDe_16OCT2025 PT_srUSDe_15JAN2026 PT_jrUSDe_15JAN2026 PT_srUSDe_02APR2026 PT_jrUSDe_02APR2026 PT_alUSD_11DEC2025 PT_cUSD_29JAN2026 PT_stcUSD_29JAN2026
        /* 0  USDC                      */ [uint16(0.00e4), 0.95e4, 0.95e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  USDT                      */ [uint16(0.95e4), 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  rlUSD                     */ [uint16(0.95e4), 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 3  wM                        */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 4  USD0PlusPlus              */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 5  USDe                      */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.87e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 6  eUSDe                     */ [uint16(0.88e4), 0.88e4, 0.88e4, 0.00e4, 0.00e4, 0.940e4, 0.00e4, 0.00e4, 0.87e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 7  sUSDe                     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 8  frxUSD                    */ [uint16(0.92e4), 0.92e4, 0.92e4, 0.00e4, 0.00e4, 0.920e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 9  sfrxUSD                   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 10 USD1                      */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 11 mUSD                      */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 12 TBILL                     */ [uint16(0.95e4), 0.95e4, 0.95e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 13 PT_USDe_27NOV2025         */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 14 PT_USDe_05FEB2026         */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 15 PT_sUSDe_27NOV2025        */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 16 PT_sUSDe_05FEB2026        */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 17 PT_cUSDO_20NOV2025        */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 18 PT_cUSDO_28MAY2026        */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 19 PT_tUSDe_18DEC2025        */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 20 PT_pUSDe_16OCT2025        */ [uint16(0.87e4), 0.87e4, 0.87e4, 0.00e4, 0.00e4, 0.925e4, 0.92e4, 0.00e4, 0.84e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 21 PT_srUSDe_15JAN2026       */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 22 PT_jrUSDe_15JAN2026       */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 23 PT_srUSDe_02APR2026       */ [uint16(0.87e4), 0.87e4, 0.87e4, 0.00e4, 0.00e4, 0.925e4, 0.92e4, 0.00e4, 0.84e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 24 PT_jrUSDe_02APR2026       */ [uint16(0.65e4), 0.65e4, 0.65e4, 0.00e4, 0.00e4, 0.650e4, 0.65e4, 0.00e4, 0.65e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 25 PT_alUSD_11DEC2025        */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 26 PT_cUSD_29JAN2026         */ [uint16(0.85e4), 0.85e4, 0.85e4, 0.00e4, 0.00e4, 0.850e4, 0.85e4, 0.00e4, 0.82e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 27 PT_stcUSD_29JAN2026       */ [uint16(0.85e4), 0.85e4, 0.85e4, 0.00e4, 0.00e4, 0.850e4, 0.85e4, 0.00e4, 0.82e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
        cluster.externalLTVs = [
        //                                  0                1       2       3       4       5       6       7       8       9       10      11      12      13      14      15      16      17      18      19      20      21      22      23      24      25      26      27      28      29      30      31      32      33      34      35      36      37      38      39
        //                                  USDC            USDT    rlUSD   wM      USD0++  USDe    eUSDe   sUSDe   frxUSD  sfrxUSD USD1    mUSD    TBILL   PT_USDe_27NOV2025 PT_USDe_05FEB2026 PT_sUSDe_27NOV2025 PT_sUSDe_05FEB2026 PT_cUSDO_20NOV2025 PT_cUSDO_28MAY2026 PT_tUSDe_18DEC2025 PT_pUSDe_16OCT2025 PT_srUSDe_15JAN2026 PT_jrUSDe_15JAN2026 PT_srUSDe_02APR2026 PT_jrUSDe_02APR2026 PT_alUSD_11DEC2025 PT_cUSD_29JAN2026 PT_stcUSD_29JAN2026
        /* 0  Prime USDC                */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  Prime USDT                */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  RWA sBUIDL                */ [uint16(0.95e4), 0.95e4, 0.95e4, 0.00e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.94e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];
    }

    function postOperations() internal view override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }
    }
}
