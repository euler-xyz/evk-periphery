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
            PYUSD,
            rlUSD,
            wM,
            USDS,
            sUSDS,
            DAI,
            sDAI,
            USD0,
            USD0PlusPlus,
            USDe,
            eUSDe,
            sUSDe,
            USDtb,
            rUSD,
            srUSD,
            syrupUSDC,
            mBASIS,
            AUSD,
            frxUSD,
            sfrxUSD,
            USD1,
            TBILL,
            PT_USDe_31JUL2025,
            PT_USDe_25SEP2025,
            PT_sUSDe_31JULY2025,
            PT_sUSDe_25SEP2025,
            PT_eUSDe_14AUG2025,
            PT_cUSDO_20NOV2025,
            PT_syrupUSDC_28AUG2025,
            PT_USDS_14AUG2025,
            PT_tUSDe_25SEP2025,
            PT_pUSDe_16OCT2025
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

        cluster.interestFeeOverride[USDC        ] = 0;
        cluster.interestFeeOverride[USDT        ] = 0;
        cluster.interestFeeOverride[PYUSD       ] = 0;
        cluster.interestFeeOverride[rlUSD       ] = 0;
        cluster.interestFeeOverride[wM          ] = 0;
        cluster.interestFeeOverride[USDS        ] = 0;
        cluster.interestFeeOverride[sUSDS       ] = 0.15e4;
        cluster.interestFeeOverride[DAI         ] = 0;
        cluster.interestFeeOverride[sDAI        ] = 0.15e4;
        cluster.interestFeeOverride[USD0        ] = 0;
        cluster.interestFeeOverride[USD0PlusPlus] = 0.15e4;
        cluster.interestFeeOverride[USDe        ] = 0;
        cluster.interestFeeOverride[eUSDe       ] = 0;
        cluster.interestFeeOverride[sUSDe       ] = 0;
        cluster.interestFeeOverride[rUSD        ] = 0;
        cluster.interestFeeOverride[syrupUSDC   ] = 0;
        cluster.interestFeeOverride[mBASIS      ] = 0.15e4;

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
        cluster.oracleProviders[PYUSD                    ] = "0x27895A6295a5117CB989d610DF1Df39DC2CDBf8F";
        cluster.oracleProviders[rlUSD                    ] = "0x3bDcB804Fd42Ccb2B7Cf329fa07724bEcB872970";
        cluster.oracleProviders[wM                       ] = "FixedRateOracle";
        cluster.oracleProviders[USDS                     ] = "0xD0dAb9eDb2b1909802B03090eFBF14743E7Ff967";
        cluster.oracleProviders[sUSDS                    ] = "ExternalVault|0xD0dAb9eDb2b1909802B03090eFBF14743E7Ff967";
        cluster.oracleProviders[DAI                      ] = "0xBb918933b510CDF9008E0f1B6AFE50A587CD9224";
        cluster.oracleProviders[sDAI                     ] = "ExternalVault|0xBb918933b510CDF9008E0f1B6AFE50A587CD9224";
        cluster.oracleProviders[USD0                     ] = "PythOracle";
        cluster.oracleProviders[USD0PlusPlus             ] = "PythOracle";
        cluster.oracleProviders[USDe                     ] = "0x93840A424aBc32549809Dd0Bc07cEb56E137221C";
        cluster.oracleProviders[eUSDe                    ] = "ExternalVault|0x93840A424aBc32549809Dd0Bc07cEb56E137221C";
        cluster.oracleProviders[sUSDe                    ] = "ExternalVault|0x93840A424aBc32549809Dd0Bc07cEb56E137221C";
        cluster.oracleProviders[USDtb                    ] = "0xE3Dce6a38A529B97B69cA47778c933b61b17535E";
        cluster.oracleProviders[rUSD                     ] = "0x01dBD40296C232C2C58c99Ff69084B256BeE33EE";
        cluster.oracleProviders[srUSD                    ] = "0xd54bc197150487a40d4ebd4fb215ca4fa996173e";
        cluster.oracleProviders[syrupUSDC                ] = "ExternalVault|0x6213f24332D35519039f2afa7e3BffE105a37d3F";
        cluster.oracleProviders[mBASIS                   ] = "0xfd63eED8Db6F5Bae46B2860C4B8a8a07eD8BF8bb";
        cluster.oracleProviders[AUSD                     ] = "0xbd33656CC2a1096024203485945A60224A2121DC";
        cluster.oracleProviders[frxUSD                   ] = "0x252e25BD698EA17945419A705a783242e1e656a7";
        cluster.oracleProviders[sfrxUSD                  ] = "ExternalVault|0x252e25BD698EA17945419A705a783242e1e656a7";
        cluster.oracleProviders[USD1                     ] = "0x1d55c9DeaE096e2D5D2427E67505238334Fa0eaB";
        cluster.oracleProviders[TBILL                    ] = "0x3577A7eA55fD30D489640791BA903B6FA278B840";
        cluster.oracleProviders[PT_USDe_31JUL2025        ] = "0xd9df01449ba6e3a4b2ad2b4e92e9b5d6a7c8b66b";
        cluster.oracleProviders[PT_USDe_25SEP2025        ] = "0x15226E1796C24a635A9662BFF2b8dc6Cc3aAc6bb";
        cluster.oracleProviders[PT_sUSDe_31JULY2025      ] = "0x7351d14f0d8ad684302578e3f8f7d2bd161da435";
        cluster.oracleProviders[PT_sUSDe_25SEP2025       ] = "0xd6B5eba2282836BFBd73d65Bf5203f91cc1179c5";
        cluster.oracleProviders[PT_eUSDe_14AUG2025       ] = "0x29e1163590eb05c84747ede225a11ce555b36ce8";
        cluster.oracleProviders[PT_cUSDO_20NOV2025       ] = "0x673222872a407775feab95a7a98f930a2cec53f4";
        cluster.oracleProviders[PT_syrupUSDC_28AUG2025   ] = "0xe635E116D38ED5db736E620dD5c839a9A119f3F5";
        cluster.oracleProviders[PT_USDS_14AUG2025        ] = "0x011088B8725eef48cAdFf5fb290E186B2AEd83f5";
        cluster.oracleProviders[PT_tUSDe_25SEP2025       ] = "0x130eABADA6f4C663095C8e9E276AB5DA670ffAeD";
        cluster.oracleProviders[PT_pUSDe_16OCT2025       ] = "0xCA5B7044BE73671FD6707C2312cEC7C07556B85f";
        
        cluster.oracleProviders[sBUIDL                   ] = "ExternalVault|0x1CF7192cF739675186653D453828C0A670ed5Cd9";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[USDC                     ] = 300_000_000;
        cluster.supplyCaps[USDT                     ] = 100_000_000;
        cluster.supplyCaps[PYUSD                    ] = 5_000_000;
        cluster.supplyCaps[rlUSD                    ] = 200_000_000;
        cluster.supplyCaps[wM                       ] = 5_000_000;
        cluster.supplyCaps[USDS                     ] = 5_000_000;
        cluster.supplyCaps[sUSDS                    ] = 8_000_000;
        cluster.supplyCaps[DAI                      ] = 5_000_000;
        cluster.supplyCaps[sDAI                     ] = 5_000_000;
        cluster.supplyCaps[USD0                     ] = 5_000_000;
        cluster.supplyCaps[USD0PlusPlus             ] = 3_700_000;
        cluster.supplyCaps[USDe                     ] = 20_000_000;
        cluster.supplyCaps[eUSDe                    ] = 60_000_000;
        cluster.supplyCaps[sUSDe                    ] = 15_000_000;
        cluster.supplyCaps[USDtb                    ] = 10_000_000;
        cluster.supplyCaps[rUSD                     ] = 30_000_000;
        cluster.supplyCaps[srUSD                    ] = 30_000_000;
        cluster.supplyCaps[syrupUSDC                ] = 5_000_000;
        cluster.supplyCaps[mBASIS                   ] = 0;
        cluster.supplyCaps[AUSD                     ] = 1_000_000;
        cluster.supplyCaps[frxUSD                   ] = 10_000_000;
        cluster.supplyCaps[sfrxUSD                  ] = 15_000_000;
        cluster.supplyCaps[USD1                     ] = 10_000_000;
        cluster.supplyCaps[TBILL                    ] = 0;//45_000_000;
        cluster.supplyCaps[PT_USDe_31JUL2025        ] = 0;
        cluster.supplyCaps[PT_USDe_25SEP2025        ] = 130_000_000;
        cluster.supplyCaps[PT_sUSDe_31JULY2025      ] = 0;
        cluster.supplyCaps[PT_sUSDe_25SEP2025       ] = 40_000_000;
        cluster.supplyCaps[PT_eUSDe_14AUG2025       ] = 0;
        cluster.supplyCaps[PT_cUSDO_20NOV2025       ] = 120_000_000;
        cluster.supplyCaps[PT_syrupUSDC_28AUG2025   ] = 45_000_000;
        cluster.supplyCaps[PT_USDS_14AUG2025        ] = 0;
        cluster.supplyCaps[PT_tUSDe_25SEP2025       ] = 80_000_000;
        cluster.supplyCaps[PT_pUSDe_16OCT2025       ] = 70_000_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[USDC                     ] = 270_000_000;
        cluster.borrowCaps[USDT                     ] = 75_000_000;
        cluster.borrowCaps[PYUSD                    ] = 4_500_000;
        cluster.borrowCaps[rlUSD                    ] = 180_000_000;
        cluster.borrowCaps[wM                       ] = 4_500_000;
        cluster.borrowCaps[USDS                     ] = 0;
        cluster.borrowCaps[sUSDS                    ] = 0;
        cluster.borrowCaps[DAI                      ] = 0;
        cluster.borrowCaps[sDAI                     ] = 0;
        cluster.borrowCaps[USD0                     ] = 0;
        cluster.borrowCaps[USD0PlusPlus             ] = 3_600_000;
        cluster.borrowCaps[USDe                     ] = 18_000_000;
        cluster.borrowCaps[eUSDe                    ] = 51_000_000;
        cluster.borrowCaps[sUSDe                    ] = 4_500_000;
        cluster.borrowCaps[USDtb                    ] = 9_000_000;
        cluster.borrowCaps[rUSD                     ] = 27_000_000;
        cluster.borrowCaps[srUSD                    ] = type(uint256).max;
        cluster.borrowCaps[syrupUSDC                ] = 4_500_000;
        cluster.borrowCaps[mBASIS                   ] = 0;
        cluster.borrowCaps[AUSD                     ] = 900_000;
        cluster.borrowCaps[frxUSD                   ] = 9_000_000;
        cluster.borrowCaps[sfrxUSD                  ] = type(uint256).max;
        cluster.borrowCaps[USD1                     ] = 9_000_000;
        cluster.borrowCaps[TBILL                    ] = 0;//type(uint256).max;
        cluster.borrowCaps[PT_USDe_31JUL2025        ] = 0;
        cluster.borrowCaps[PT_USDe_25SEP2025        ] = type(uint256).max;
        cluster.borrowCaps[PT_sUSDe_31JULY2025      ] = 0;
        cluster.borrowCaps[PT_sUSDe_25SEP2025       ] = type(uint256).max;
        cluster.borrowCaps[PT_eUSDe_14AUG2025       ] = 0;
        cluster.borrowCaps[PT_cUSDO_20NOV2025       ] = type(uint256).max;
        cluster.borrowCaps[PT_syrupUSDC_28AUG2025   ] = type(uint256).max;
        cluster.borrowCaps[PT_USDS_14AUG2025        ] = 0;
        cluster.borrowCaps[PT_tUSDe_25SEP2025       ] = type(uint256).max;
        cluster.borrowCaps[PT_pUSDe_16OCT2025       ] = type(uint256).max;

        // define IRM classes here and assign them to the assets
        {
            // Base=0.00% APY,  Kink(90.00%)=8.00% APY  Max=15.00% APY
            uint256[4] memory irm_USD_1_MEGA_YIELD_OLD = [uint256(0), uint256(630918865), uint256(4633519165), uint256(3865470566)];

            // Base=5.00% APY,  Kink(90.00%)=10.00% APY  Max=20.00% APY
            uint256[4] memory irm_USD_1_MEGA_YIELD = [uint256(1546098748700445000), uint256(381366399), uint256(6419794564), uint256(3865470566)];

            // Base=0% APY,  Kink(30%)=12.75% APY  Max=848.77% APY
            uint256[4] memory irm_USD_3_MEGA_YIELD = [uint256(0), uint256(2951312420), uint256(22450463582), uint256(1288490188)];

            // Base=5.00% APY,  Kink(90.00%)=10.00% APY  Max=40.00% APY
            uint256[4] memory irm_eUSDe_rUSD       = [uint256(1546098748700445000), uint256(381366399), uint256(17793200339), uint256(3865470566)];

            // Base=0% APY,  Kink(30%)=2.00% APY  Max=80.00% APY
            uint256[4] memory irm_sUSDe            = [uint256(0), uint256(487019827), uint256(5986640502), uint256(1288490188)];

            // Base=0% APY,  Kink(90%)=1.50% APY  Max=80.00% APY
            uint256[4] memory irm_syrupUSDC        = [uint256(0), uint256(122055342), uint256(42269044890), uint256(3865470566)];

            cluster.kinkIRMParams[USDC        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USDT        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[PYUSD       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[rlUSD       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[wM          ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USDS        ] = irm_USD_1_MEGA_YIELD_OLD;
            cluster.kinkIRMParams[sUSDS       ] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[DAI         ] = irm_USD_1_MEGA_YIELD_OLD;
            cluster.kinkIRMParams[sDAI        ] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[USD0        ] = irm_USD_1_MEGA_YIELD_OLD;
            cluster.kinkIRMParams[USD0PlusPlus] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[USDe        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[eUSDe       ] = irm_eUSDe_rUSD;
            cluster.kinkIRMParams[sUSDe       ] = irm_sUSDe;
            cluster.kinkIRMParams[USDtb       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[rUSD        ] = irm_eUSDe_rUSD;
            cluster.kinkIRMParams[syrupUSDC   ] = irm_syrupUSDC;
            cluster.kinkIRMParams[mBASIS      ] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[AUSD        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[frxUSD      ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USD1        ] = irm_USD_1_MEGA_YIELD;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 30 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            cluster.spreadLTVOverride[27][i] = 0.025e4; // PT_sUSDe_25SEP2025 as collateral
            cluster.spreadLTVOverride[28][i] = 0.025e4; // PT_eUSDe_14AUG2025 as collateral
        }

        cluster.spreadLTVOverride[12][11] = 0.01e4; // eUSDe/USDe

        cluster.spreadLTVOverride[16][15] = 0.015e4; // srUSD/rUSD

        cluster.spreadLTVOverride[25][11] = 0.01e4; // PT_USDe_25SEP2025/USDe
        cluster.spreadLTVOverride[25][12] = 0.01e4; // PT_USDe_25SEP2025/eUSDe
        cluster.spreadLTVOverride[25][13] = 0.01e4; // PT_USDe_25SEP2025/sUSDe

        cluster.spreadLTVOverride[27][11] = 0.01e4; // PT_sUSDe_25SEP2025/USDe
        cluster.spreadLTVOverride[27][12] = 0.01e4; // PT_sUSDe_25SEP2025/eUSDe
        cluster.spreadLTVOverride[27][13] = 0.01e4; // PT_sUSDe_25SEP2025/sUSDe

        cluster.spreadLTVOverride[30][17] = 0.01e4; // PT_syrupUSDC_28AUG2025/syrupUSDC

        cluster.spreadLTVOverride[31][5] = 0.01e4; // PT_USDS_14AUG2025/USDS
        cluster.spreadLTVOverride[31][6] = 0.01e4; // PT_USDS_14AUG2025/sUSDS
        cluster.spreadLTVOverride[31][7] = 0.01e4; // PT_USDS_14AUG2025/DAI
        cluster.spreadLTVOverride[31][8] = 0.01e4; // PT_USDS_14AUG2025/sDAI
        
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            cluster.borrowLTVsOverride[10][i] = 0.84e4; // USD0PlusPlus as collateral
        }

        cluster.borrowLTVsOverride[10][9] = 0.86e4; // USD0PlusPlus/USD0
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                                  0               1       2       3       4       5       6       7       8       9       10      11       12      13      14       15      16      17      18      19      20      21      22      23      24      25      26      27      28      29      30      31      32      33      34      35
        //                                  USDC            USDT    PYUSD   rlUSD   wM      USDS    sUSDS   DAI     sDAI    USD0    USD0++  USDe     eUSDe   sUSDe   USDtb   rUSD     srUSD syrupUSDC mBASIS  AUSD    frxUSD  sfrxUSD USD1    TBILL   PT_USDe_31JUL2025 PT_USDe_25SEP2025 PT_sUSDe_31JULY2025 PT_sUSDe_25SEP2025 PT_eUSDe_14AUG2025 PT_cUSDO_20NOV2025 PT_syrupUSDC_28AUG2025 PT_USDS_14AUG2025 PT_tUSDe_25SEP2025 PT_pUSDe_16OCT2025
        /* 0  USDC                      */ [uint16(0.00e4), 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.95e4, 0.950e4, 0.00e4, 0.00e4, 0.00e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  USDT                      */ [uint16(0.95e4), 0.00e4, 0.95e4, 0.95e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.95e4, 0.950e4, 0.00e4, 0.00e4, 0.00e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  PYUSD                     */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.930e4, 0.00e4, 0.00e4, 0.93e4, 0.930e4, 0.00e4, 0.00e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 3  rlUSD                     */ [uint16(0.95e4), 0.95e4, 0.95e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.00e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 4  wM                        */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.930e4, 0.00e4, 0.00e4, 0.93e4, 0.930e4, 0.00e4, 0.00e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 5  USDS                      */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 6  sUSDS                     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 7  DAI                       */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 8  sDAI                      */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 9  USD0                      */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 10 USD0PlusPlus              */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.900e4, 0.00e4, 0.00e4, 0.90e4, 0.900e4, 0.00e4, 0.00e4, 0.00e4, 0.87e4, 0.87e4, 0.00e4, 0.87e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 11 USDe                      */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.90e4, 0.900e4, 0.00e4, 0.00e4, 0.00e4, 0.87e4, 0.87e4, 0.00e4, 0.87e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 12 eUSDe                     */ [uint16(0.88e4), 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.940e4, 0.00e4, 0.00e4, 0.88e4, 0.880e4, 0.00e4, 0.00e4, 0.00e4, 0.85e4, 0.87e4, 0.00e4, 0.87e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 13 sUSDe                     */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.900e4, 0.00e4, 0.00e4, 0.90e4, 0.900e4, 0.00e4, 0.00e4, 0.00e4, 0.87e4, 0.87e4, 0.00e4, 0.87e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 14 USDtb                     */ [uint16(0.95e4), 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.00e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 15 rUSD                      */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 16 srUSD                     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.975e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 17 syrupUSDC                 */ [uint16(0.92e4), 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.920e4, 0.00e4, 0.00e4, 0.92e4, 0.920e4, 0.00e4, 0.00e4, 0.00e4, 0.89e4, 0.89e4, 0.00e4, 0.89e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 18 mBASIS                    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 19 AUSD                      */ [uint16(0.92e4), 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.920e4, 0.00e4, 0.00e4, 0.92e4, 0.920e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 20 frxUSD                    */ [uint16(0.92e4), 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.920e4, 0.00e4, 0.00e4, 0.92e4, 0.920e4, 0.00e4, 0.00e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 21 sfrxUSD                   */ [uint16(0.92e4), 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.920e4, 0.00e4, 0.00e4, 0.92e4, 0.920e4, 0.00e4, 0.00e4, 0.00e4, 0.92e4, 0.95e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 22 USD1                      */ [uint16(0.92e4), 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.920e4, 0.00e4, 0.00e4, 0.92e4, 0.920e4, 0.00e4, 0.00e4, 0.00e4, 0.92e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 23 TBILL                     */ [uint16(0.95e4), 0.95e4, 0.95e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.95e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 24 PT_USDe_31JUL2025         */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 25 PT_USDe_25SEP2025         */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.940e4, 0.92e4, 0.92e4, 0.90e4, 0.900e4, 0.00e4, 0.00e4, 0.00e4, 0.87e4, 0.87e4, 0.00e4, 0.87e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 26 PT_sUSDe_31JULY2025       */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 27 PT_sUSDe_25SEP2025        */ [uint16(0.88e4), 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.925e4, 0.92e4, 0.94e4, 0.88e4, 0.880e4, 0.00e4, 0.00e4, 0.00e4, 0.85e4, 0.85e4, 0.00e4, 0.85e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 28 PT_eUSDe_14AUG2025        */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 29 PT_cUSDO_20NOV2025        */ [uint16(0.88e4), 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.880e4, 0.00e4, 0.00e4, 0.00e4, 0.880e4, 0.00e4, 0.00e4, 0.00e4, 0.85e4, 0.85e4, 0.00e4, 0.85e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 30 PT_syrupUSDC_28AUG2025    */ [uint16(0.88e4), 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.880e4, 0.00e4, 0.00e4, 0.88e4, 0.880e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 31 PT_USDS_14AUG2025         */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 32 PT_tUSDe_25SEP2025        */ [uint16(0.87e4), 0.87e4, 0.87e4, 0.87e4, 0.87e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.925e4, 0.92e4, 0.00e4, 0.87e4, 0.870e4, 0.00e4, 0.00e4, 0.00e4, 0.84e4, 0.84e4, 0.00e4, 0.84e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 33 PT_pUSDe_16OCT2025        */ [uint16(0.87e4), 0.87e4, 0.87e4, 0.87e4, 0.87e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.925e4, 0.92e4, 0.00e4, 0.87e4, 0.870e4, 0.00e4, 0.00e4, 0.00e4, 0.84e4, 0.84e4, 0.00e4, 0.84e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
        cluster.externalLTVs = [
        //                                 0                1       2       3       4       5       6       7       8       9       10      11      12      13      14      15      16      17      18      19      20      21      22      23      24      25      26      27      28      29      30      31      32      33      34      35
        //                                 USDC             USDT    PYUSD   rlUSD   wM      USDS    sUSDS   DAI     sDAI    USD0    USD0++  USDe    eUSDe   sUSDe   USDtb   rUSD    srUSD syrupUSDC mBASIS  AUSD    frxUSD  sfrxUSD USD1    TBILL   PT_USDe_31JUL2025 PT_USDe_25SEP2025 PT_sUSDe_31JULY2025 PT_sUSDe_25SEP2025 PT_eUSDe_14AUG2025 PT_cUSDO_20NOV2025 PT_syrupUSDC_28AUG2025 PT_USDS_14AUG2025 PT_tUSDe_25SEP2025 PT_pUSDe_16OCT2025
        /* 0  Prime USDC                */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  Prime USDT                */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  RWA sBUIDL                */ [uint16(0.95e4), 0.95e4, 0.95e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.94e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];
    }

    function postOperations() internal view override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }
    }
}
