// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";

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
            FDUSD,
            PYUSD,
            rlUSD,
            wUSDM,
            wUSDL,
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
            deUSD,
            sdeUSD,
            rUSD,
            srUSD,
            syrupUSDC,
            mBASIS,
            mEDGE,
            mMEV,
            PT_USD0PlusPlus_30JAN2025,
            PT_USD0PlusPlus_27MAR2025,
            PT_USD0PlusPlus_26JUN2025,
            PT_sUSDe_27MAR2025,
            PT_sUSDe_29MAY2025,
            PT_sUSDe_31JULY2025,
            PT_USDe_27MAR2025,
            PT_eUSDe_29MAY2025,
            PT_cUSDO_19JUN2025,
            PT_syrupUSDC_28AUG2025
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
        cluster.interestFeeOverride[FDUSD       ] = 0;
        cluster.interestFeeOverride[PYUSD       ] = 0;
        cluster.interestFeeOverride[rlUSD       ] = 0;
        cluster.interestFeeOverride[wUSDM       ] = 0;
        cluster.interestFeeOverride[wUSDL       ] = 0;
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
        cluster.interestFeeOverride[deUSD       ] = 0.15e4;
        cluster.interestFeeOverride[sdeUSD      ] = 0.15e4;
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
        cluster.oracleProviders[USDC                     ] = "PythOracle";
        cluster.oracleProviders[USDT                     ] = "PythOracle";
        cluster.oracleProviders[FDUSD                    ] = "PythOracle";
        cluster.oracleProviders[PYUSD                    ] = "PythOracle";
        cluster.oracleProviders[rlUSD                    ] = "FixedRateOracle";
        cluster.oracleProviders[wUSDM                    ] = "ExternalVault|FixedRateOracle";
        cluster.oracleProviders[wUSDL                    ] = "ExternalVault|FixedRateOracle";
        cluster.oracleProviders[wM                       ] = "FixedRateOracle";
        cluster.oracleProviders[USDS                     ] = "PythOracle";
        cluster.oracleProviders[sUSDS                    ] = "ExternalVault|PythOracle";
        cluster.oracleProviders[DAI                      ] = "PythOracle";
        cluster.oracleProviders[sDAI                     ] = "ExternalVault|PythOracle";
        cluster.oracleProviders[USD0                     ] = "PythOracle";
        cluster.oracleProviders[USD0PlusPlus             ] = "PythOracle";
        cluster.oracleProviders[USDe                     ] = "PythOracle";
        cluster.oracleProviders[eUSDe                    ] = "ExternalVault|PythOracle";
        cluster.oracleProviders[sUSDe                    ] = "ExternalVault|PythOracle";
        cluster.oracleProviders[USDtb                    ] = "FixedRateOracle";
        cluster.oracleProviders[deUSD                    ] = "PythOracle";
        cluster.oracleProviders[sdeUSD                   ] = "ExternalVault|PythOracle";
        cluster.oracleProviders[rUSD                     ] = "0x01dBD40296C232C2C58c99Ff69084B256BeE33EE";
        cluster.oracleProviders[srUSD                    ] = "0xd54bc197150487a40d4ebd4fb215ca4fa996173e";
        cluster.oracleProviders[syrupUSDC                ] = "ExternalVault|PythOracle";
        cluster.oracleProviders[mBASIS                   ] = "0xfd63eED8Db6F5Bae46B2860C4B8a8a07eD8BF8bb";
        cluster.oracleProviders[mEDGE                    ] = "0xc8228b83f1d97a431a48bd9bc3e971c8b418d889";
        cluster.oracleProviders[mMEV                     ] = "0xf5c2dfd1740d18ad7cf23fba76cc11d877802937";
        cluster.oracleProviders[PT_USD0PlusPlus_30JAN2025] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_USD0PlusPlus_27MAR2025] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_USD0PlusPlus_26JUN2025] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_sUSDe_27MAR2025       ] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_sUSDe_29MAY2025       ] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_sUSDe_31JULY2025      ] = "CrossAdapter=PendleUniversalOracle+PythOracle";
        cluster.oracleProviders[PT_USDe_27MAR2025        ] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_eUSDe_29MAY2025       ] = "CrossAdapter=PendleUniversalOracle+PythOracle";
        cluster.oracleProviders[PT_cUSDO_19JUN2025       ] = "CrossAdapter=PendleUniversalOracle+FixedRateOracle";
        cluster.oracleProviders[PT_syrupUSDC_28AUG2025   ] = "0xee307d24a721f418a57a494a85c29a0e81f430a2"; //"CrossAdapter=PendleUniversalOracle+PythOracle";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[USDC                     ] = 150_000_000;
        cluster.supplyCaps[USDT                     ] = 50_000_000;
        cluster.supplyCaps[FDUSD                    ] = 0;
        cluster.supplyCaps[PYUSD                    ] = 10_000_000;
        cluster.supplyCaps[rlUSD                    ] = 100_000_000;
        cluster.supplyCaps[wUSDM                    ] = 5_000_000;
        cluster.supplyCaps[wUSDL                    ] = 5_000_000;
        cluster.supplyCaps[wM                       ] = 5_000_000;
        cluster.supplyCaps[USDS                     ] = 10_000_000;
        cluster.supplyCaps[sUSDS                    ] = 8_000_000;
        cluster.supplyCaps[DAI                      ] = 10_000_000;
        cluster.supplyCaps[sDAI                     ] = 10_000_000;
        cluster.supplyCaps[USD0                     ] = 10_000_000;
        cluster.supplyCaps[USD0PlusPlus             ] = 12_000_000;
        cluster.supplyCaps[USDe                     ] = 40_000_000;
        cluster.supplyCaps[eUSDe                    ] = 60_000_000;
        cluster.supplyCaps[sUSDe                    ] = 30_000_000;
        cluster.supplyCaps[USDtb                    ] = 20_000_000;
        cluster.supplyCaps[deUSD                    ] = 0;
        cluster.supplyCaps[sdeUSD                   ] = 0;
        cluster.supplyCaps[rUSD                     ] = 30_000_000;
        cluster.supplyCaps[srUSD                    ] = 30_000_000;
        cluster.supplyCaps[syrupUSDC                ] = 20_000_000;
        cluster.supplyCaps[mBASIS                   ] = 6_000_000;
        cluster.supplyCaps[mEDGE                    ] = 2_000_000;
        cluster.supplyCaps[mMEV                     ] = 2_000_000;
        cluster.supplyCaps[PT_USD0PlusPlus_30JAN2025] = 0;
        cluster.supplyCaps[PT_USD0PlusPlus_27MAR2025] = 4_000_000;
        cluster.supplyCaps[PT_USD0PlusPlus_26JUN2025] = 6_000_000;
        cluster.supplyCaps[PT_sUSDe_27MAR2025       ] = 4_000_000;
        cluster.supplyCaps[PT_sUSDe_29MAY2025       ] = 40_000_000;
        cluster.supplyCaps[PT_sUSDe_31JULY2025      ] = 40_000_000;
        cluster.supplyCaps[PT_USDe_27MAR2025        ] = 4_000_000;
        cluster.supplyCaps[PT_eUSDe_29MAY2025       ] = 45_000_000;
        cluster.supplyCaps[PT_cUSDO_19JUN2025       ] = 54_000_000;
        cluster.supplyCaps[PT_syrupUSDC_28AUG2025   ] = 15_000_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[USDC                     ] = 135_000_000;
        cluster.borrowCaps[USDT                     ] = 45_000_000;
        cluster.borrowCaps[FDUSD                    ] = 0;
        cluster.borrowCaps[PYUSD                    ] = 9_000_000;
        cluster.borrowCaps[rlUSD                    ] = 9_000_000;
        cluster.borrowCaps[wUSDM                    ] = 0;
        cluster.borrowCaps[wUSDL                    ] = 0;
        cluster.borrowCaps[wM                       ] = 4_500_000;
        cluster.borrowCaps[USDS                     ] = 9_000_000;
        cluster.borrowCaps[sUSDS                    ] = 2_400_000;
        cluster.borrowCaps[DAI                      ] = 9_000_000;
        cluster.borrowCaps[sDAI                     ] = 3_000_000;
        cluster.borrowCaps[USD0                     ] = 9_000_000;
        cluster.borrowCaps[USD0PlusPlus             ] = 3_600_000;
        cluster.borrowCaps[USDe                     ] = 36_000_000;
        cluster.borrowCaps[eUSDe                    ] = 51_000_000;
        cluster.borrowCaps[sUSDe                    ] = 9_000_000;
        cluster.borrowCaps[USDtb                    ] = 18_000_000;
        cluster.borrowCaps[deUSD                    ] = 0;
        cluster.borrowCaps[sdeUSD                   ] = 0;
        cluster.borrowCaps[rUSD                     ] = 27_000_000;
        cluster.borrowCaps[srUSD                    ] = type(uint256).max;
        cluster.borrowCaps[syrupUSDC                ] = 18_000_000;
        cluster.borrowCaps[mBASIS                   ] = 1_800_000;
        cluster.borrowCaps[mEDGE                    ] = type(uint256).max;
        cluster.borrowCaps[mMEV                     ] = type(uint256).max;
        cluster.borrowCaps[PT_USD0PlusPlus_30JAN2025] = type(uint256).max;
        cluster.borrowCaps[PT_USD0PlusPlus_27MAR2025] = type(uint256).max;
        cluster.borrowCaps[PT_USD0PlusPlus_26JUN2025] = type(uint256).max;
        cluster.borrowCaps[PT_sUSDe_27MAR2025       ] = type(uint256).max;
        cluster.borrowCaps[PT_sUSDe_29MAY2025       ] = type(uint256).max;
        cluster.borrowCaps[PT_sUSDe_31JULY2025      ] = type(uint256).max;
        cluster.borrowCaps[PT_USDe_27MAR2025        ] = type(uint256).max;
        cluster.borrowCaps[PT_eUSDe_29MAY2025       ] = type(uint256).max;
        cluster.borrowCaps[PT_cUSDO_19JUN2025       ] = type(uint256).max;
        cluster.borrowCaps[PT_syrupUSDC_28AUG2025   ] = type(uint256).max;

        // define IRM classes here and assign them to the assets
        {
            // Base=0.00% APY,  Kink(90.00%)=7.00% APY  Max=40.00% APY
            uint256[4] memory irm_USD_1_MEGA_YIELD = [uint256(0), uint256(554658784), uint256(19833360540), uint256(3865470566)];

            // Base=0% APY,  Kink(90%)=16.18% APY  Max=101.38% APY
            uint256[4] memory irm_USD_1_MEGA_YIELD_OLD = [uint256(0), uint256(1229443272), uint256(40583508868), uint256(3865470566)];

            // Base=0% APY,  Kink(30%)=12.75% APY  Max=848.77% APY
            uint256[4] memory irm_USD_3_MEGA_YIELD = [uint256(0), uint256(2951312420), uint256(22450463582), uint256(1288490188)];

            // Base=0.00% APY,  Kink(85.00%)=7.00% APY  Max=40.00% APY
            uint256[4] memory irm_eUSDe            = [uint256(0), uint256(587285771), uint256(13222240360), uint256(3650722201)];

            // Base=0% APY,  Kink(30%)=2.00% APY  Max=80.00% APY
            uint256[4] memory irm_sUSDe            = [uint256(0), uint256(487019827), uint256(5986640502), uint256(1288490188)];

            // Base=0% APY,  Kink(90%)=6.00% APY  Max=80.00% APY
            uint256[4] memory irm_rUSD             = [uint256(0), uint256(477682641), uint256(39068399204), uint256(3865470566)];

            // Base=0% APY,  Kink(90%)=1.50% APY  Max=80.00% APY
            uint256[4] memory irm_syrupUSDC        = [uint256(0), uint256(137312259), uint256(23129091833), uint256(3435973836)];

            cluster.kinkIRMParams[USDC        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USDT        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[FDUSD       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[PYUSD       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[rlUSD       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[wUSDM       ] = irm_USD_1_MEGA_YIELD_OLD;
            cluster.kinkIRMParams[wUSDL       ] = irm_USD_1_MEGA_YIELD_OLD;
            cluster.kinkIRMParams[wM          ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USDS        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[sUSDS       ] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[DAI         ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[sDAI        ] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[USD0        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USD0PlusPlus] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[USDe        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[eUSDe       ] = irm_eUSDe;
            cluster.kinkIRMParams[sUSDe       ] = irm_sUSDe;
            cluster.kinkIRMParams[USDtb       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[deUSD       ] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[sdeUSD      ] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[rUSD        ] = irm_rUSD;
            cluster.kinkIRMParams[syrupUSDC   ] = irm_syrupUSDC;
            cluster.kinkIRMParams[mBASIS      ] = irm_USD_3_MEGA_YIELD;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 30 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            cluster.spreadLTVOverride[30][i] = 0.025e4; // PT_sUSDe_29MAY2025 as collateral
            cluster.spreadLTVOverride[31][i] = 0.025e4; // PT_sUSDe_31JULY2025 as collateral
            cluster.spreadLTVOverride[33][i] = 0.025e4; // PT_eUSDe_29MAY2025 as collateral
        }

        cluster.spreadLTVOverride[15][14] = 0.01e4; // eUSDe/USDe

        cluster.spreadLTVOverride[21][20] = 0.015e4; // srUSD/rUSD

        cluster.spreadLTVOverride[30][14] = 0.01e4; // PT_sUSDe_29MAY2025/USDe
        cluster.spreadLTVOverride[30][15] = 0.01e4; // PT_sUSDe_29MAY2025/eUSDe
        cluster.spreadLTVOverride[30][16] = 0.01e4; // PT_sUSDe_29MAY2025/sUSDe
        
        cluster.spreadLTVOverride[31][14] = 0.01e4; // PT_sUSDe_31JULY2025/USDe
        cluster.spreadLTVOverride[31][15] = 0.01e4; // PT_sUSDe_31JULY2025/eUSDe
        cluster.spreadLTVOverride[31][16] = 0.01e4; // PT_sUSDe_31JULY2025/sUSDe

        cluster.spreadLTVOverride[33][14] = 0.01e4; // PT_eUSDe_29MAY2025/USDe
        cluster.spreadLTVOverride[33][15] = 0.01e4; // PT_eUSDe_29MAY2025/eUSDe

        cluster.spreadLTVOverride[35][22] = 0.01e4; // PT_syrupUSDC_28AUG2025/syrupUSDC
        
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            cluster.borrowLTVsOverride[13][i] = 0.84e4; // USD0PlusPlus as collateral
        }

        cluster.borrowLTVsOverride[13][12] = 0.86e4; // USD0PlusPlus/USD0
        cluster.borrowLTVsOverride[28][12] = 0.84e4; // PT_USD0PlusPlus_26JUN2025/USD0
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                                  0               1       2       3       4       5       6       7       8       9       10      11      12      13      14       15      16      17      18      19      20       21      22      23      24      25      26      27      28      29      30      31      32      33      34      35
        //                                  USDC            USDT    FDUSD   PYUSD   rlUSD   wUSDM   wUSDL   wM      USDS    sUSDS   DAI     sDAI    USD0    USD0++  USDe     eUSDe   sUSDe   USDtb   deUSD   sdeUSD  rUSD     srUSD syrupUSDC mBASIS  mEDGE   mMEV    PT_USD0PlusPlus_30JAN2025 PT_USD0PlusPlus_27MAR2025 PT_USD0PlusPlus_26JUN2025 PT_sUSDe_27MAR2025 PT_sUSDe_29MAY2025 PT_sUSDe_31JULY2025 PT_USDe_27MAR2025 PT_eUSDe_29MAY2025 PT_cUSDO_19JUN2025 PT_syrupUSDC_28AUG2025
        /* 0  USDC                      */ [uint16(0.00e4), 0.95e4, 0.00e4, 0.95e4, 0.95e4, 0.00e4, 0.00e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  USDT                      */ [uint16(0.95e4), 0.00e4, 0.00e4, 0.95e4, 0.95e4, 0.00e4, 0.00e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  FDUSD                     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 3  PYUSD                     */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.930e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.930e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 4  rlUSD                     */ [uint16(0.95e4), 0.95e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 5  wUSDM                     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 6  wUSDL                     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 7  wM                        */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.930e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.930e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 8  USDS                      */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.930e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.930e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 9  sUSDS                     */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.930e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.930e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 10 DAI                       */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.930e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.930e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 11 sDAI                      */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.930e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.930e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 12 USD0                      */ [uint16(0.90e4), 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.900e4, 0.00e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.900e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 13 USD0PlusPlus              */ [uint16(0.90e4), 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.900e4, 0.00e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.900e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 14 USDe                      */ [uint16(0.90e4), 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.900e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 15 eUSDe                     */ [uint16(0.88e4), 0.88e4, 0.00e4, 0.88e4, 0.88e4, 0.00e4, 0.00e4, 0.88e4, 0.88e4, 0.00e4, 0.88e4, 0.00e4, 0.88e4, 0.00e4, 0.940e4, 0.00e4, 0.00e4, 0.88e4, 0.00e4, 0.00e4, 0.880e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 16 sUSDe                     */ [uint16(0.90e4), 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.900e4, 0.00e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.900e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 17 USDtb                     */ [uint16(0.95e4), 0.95e4, 0.00e4, 0.95e4, 0.95e4, 0.00e4, 0.00e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.950e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 18 deUSD                     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 19 sdeUSD                    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 20 rUSD                      */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 21 srUSD                     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.975e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 22 syrupUSDC                 */ [uint16(0.92e4), 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.00e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.920e4, 0.00e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.920e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 23 mBASIS                    */ [uint16(0.90e4), 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.900e4, 0.00e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.900e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 24 mEDGE                     */ [uint16(0.95e4), 0.95e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.95e4, 0.00e4, 0.90e4, 0.00e4, 0.900e4, 0.00e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 25 mMEV                      */ [uint16(0.95e4), 0.95e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.95e4, 0.00e4, 0.90e4, 0.00e4, 0.900e4, 0.00e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 26 PT_USD0PlusPlus_30JAN2025 */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 27 PT_USD0PlusPlus_27MAR2025 */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 28 PT_USD0PlusPlus_26JUN2025 */ [uint16(0.84e4), 0.84e4, 0.00e4, 0.84e4, 0.84e4, 0.00e4, 0.00e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.90e4, 0.00e4, 0.840e4, 0.00e4, 0.00e4, 0.84e4, 0.00e4, 0.00e4, 0.840e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 29 PT_sUSDe_27MAR2025        */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 30 PT_sUSDe_29MAY2025        */ [uint16(0.88e4), 0.88e4, 0.00e4, 0.88e4, 0.88e4, 0.00e4, 0.00e4, 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.00e4, 0.925e4, 0.92e4, 0.94e4, 0.88e4, 0.00e4, 0.00e4, 0.880e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 31 PT_sUSDe_31JULY2025       */ [uint16(0.88e4), 0.88e4, 0.00e4, 0.88e4, 0.88e4, 0.00e4, 0.00e4, 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.00e4, 0.925e4, 0.92e4, 0.94e4, 0.88e4, 0.00e4, 0.00e4, 0.880e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 32 PT_USDe_27MAR2025         */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.000e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 33 PT_eUSDe_29MAY2025        */ [uint16(0.88e4), 0.88e4, 0.00e4, 0.88e4, 0.88e4, 0.00e4, 0.00e4, 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.00e4, 0.935e4, 0.94e4, 0.00e4, 0.88e4, 0.00e4, 0.00e4, 0.880e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 34 PT_cUSDO_19JUN2025        */ [uint16(0.88e4), 0.88e4, 0.00e4, 0.88e4, 0.88e4, 0.00e4, 0.00e4, 0.88e4, 0.88e4, 0.00e4, 0.88e4, 0.00e4, 0.88e4, 0.00e4, 0.880e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.880e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 35 PT_syrupUSDC_28AUG2025    */ [uint16(0.88e4), 0.88e4, 0.00e4, 0.88e4, 0.88e4, 0.00e4, 0.00e4, 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.88e4, 0.00e4, 0.880e4, 0.00e4, 0.00e4, 0.88e4, 0.00e4, 0.00e4, 0.880e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
        cluster.externalLTVs = [
        //                                 0                1       2       3       4       5       6       7       8       9       10      11      12      13      14      15      16      17      18      19      20      21      22      23      24      25      26      27      28      29      30      31      32      33      34      35
        //                                 USDC             USDT    FDUSD   PYUSD   rlUSD   wUSDM   wUSDL   wM      USDS    sUSDS   DAI     sDAI    USD0    USD0++  USDe    eUSDe   sUSDe   USDtb   deUSD   sdeUSD  rUSD    srUSD syrupUSDC mBASIS  mEDGE   mMEV    PT_USD0PlusPlus_30JAN2025 PT_USD0PlusPlus_27MAR2025 PT_USD0PlusPlus_26JUN2025 PT_sUSDe_27MAR2025 PT_sUSDe_29MAY2025 PT_sUSDe_31JULY2025 PT_USDe_27MAR2025 PT_eUSDe_29MAY2025 PT_cUSDO_19JUN2025 PT_syrupUSDC_28AUG2025
        /* 0  Prime USDC                */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  Prime USDT                */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];
    }

    function postOperations() internal view override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }
    }
}
