// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../../utils/PerspectiveCheck.s.sol";

contract Cluster is ManageCluster {
    function configureCluster() internal override {
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
            USDa,
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
            sUSDe,
            deUSD,
            sdeUSD,
            mBASIS,
            PT_USD0PlusPlus_30JAN2025,
            PT_USD0PlusPlus_27MAR2025,
            PT_USD0PlusPlus_26JUN2025,
            PT_sUSDe_27MAR2025,
            PT_sUSDe_29MAY2025,
            PT_USDe_27MAR2025
        ];

        // define the governors here
        cluster.oracleRoutersGovernor = EULER_DAO_MULTISIG;
        cluster.vaultsGovernor = EULER_DAO_MULTISIG;

        // define unit of account here
        cluster.unitOfAccount = USD;

        // define fee receiver here and interest fee here. if needed to be defined per asset, populate the feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = address(0);
        cluster.interestFee = 0.1e4;

        //cluster.interestFeeOverride[USDC        ] = 1;
        //cluster.interestFeeOverride[USDT        ] = 1;
        //cluster.interestFeeOverride[FDUSD       ] = 1;
        //cluster.interestFeeOverride[PYUSD       ] = 1;
        //cluster.interestFeeOverride[rlUSD       ] = 1;
        //cluster.interestFeeOverride[USDa        ] = 1;
        //cluster.interestFeeOverride[wUSDM       ] = 1;
        //cluster.interestFeeOverride[wUSDL       ] = 1;
        //cluster.interestFeeOverride[wM          ] = 1;
        //cluster.interestFeeOverride[USDS        ] = 1;
        cluster.interestFeeOverride[sUSDS       ] = 0.15e4;
        //cluster.interestFeeOverride[DAI         ] = 1;
        cluster.interestFeeOverride[sDAI        ] = 0.15e4;
        //cluster.interestFeeOverride[USD0        ] = 1;
        cluster.interestFeeOverride[USD0PlusPlus] = 0.15e4;
        cluster.interestFeeOverride[USDe        ] = 0.15e4;
        cluster.interestFeeOverride[sUSDe       ] = 0.15e4;
        cluster.interestFeeOverride[deUSD       ] = 0.15e4;
        cluster.interestFeeOverride[sdeUSD      ] = 0.15e4;
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
        cluster.oracleProviders[USDa                     ] = "FixedRateOracle";
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
        cluster.oracleProviders[sUSDe                    ] = "ExternalVault|PythOracle";
        cluster.oracleProviders[deUSD                    ] = "PythOracle";
        cluster.oracleProviders[sdeUSD                   ] = "ExternalVault|PythOracle";
        cluster.oracleProviders[mBASIS                   ] = "0xfd63eED8Db6F5Bae46B2860C4B8a8a07eD8BF8bb";
        cluster.oracleProviders[PT_USD0PlusPlus_30JAN2025] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_USD0PlusPlus_27MAR2025] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_USD0PlusPlus_26JUN2025] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_sUSDe_27MAR2025       ] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_sUSDe_29MAY2025       ] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_USDe_27MAR2025        ] = "CrossAdapter=PendleOracle+PythOracle";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[USDC                     ] = 20_000_000;
        cluster.supplyCaps[USDT                     ] = 20_000_000;
        cluster.supplyCaps[FDUSD                    ] = 20_000_000;
        cluster.supplyCaps[PYUSD                    ] = 20_000_000;
        cluster.supplyCaps[rlUSD                    ] = 20_000_000;
        cluster.supplyCaps[USDa                     ] = 20_000_000;
        cluster.supplyCaps[wUSDM                    ] = 20_000_000;
        cluster.supplyCaps[wUSDL                    ] = 20_000_000;
        cluster.supplyCaps[wM                       ] = 20_000_000;
        cluster.supplyCaps[USDS                     ] = 20_000_000;
        cluster.supplyCaps[sUSDS                    ] = 20_000_000;
        cluster.supplyCaps[DAI                      ] = 20_000_000;
        cluster.supplyCaps[sDAI                     ] = 20_000_000;
        cluster.supplyCaps[USD0                     ] = 20_000_000;
        cluster.supplyCaps[USD0PlusPlus             ] = 16_000_000;
        cluster.supplyCaps[USDe                     ] = 20_000_000;
        cluster.supplyCaps[sUSDe                    ] = 16_000_000;
        cluster.supplyCaps[deUSD                    ] = 12_000_000;
        cluster.supplyCaps[sdeUSD                   ] = 9_600_000;
        cluster.supplyCaps[mBASIS                   ] = 6_000_000;
        cluster.supplyCaps[PT_USD0PlusPlus_30JAN2025] = 4_000_000;
        cluster.supplyCaps[PT_USD0PlusPlus_27MAR2025] = 4_000_000;
        cluster.supplyCaps[PT_USD0PlusPlus_26JUN2025] = 4_000_000;
        cluster.supplyCaps[PT_sUSDe_27MAR2025       ] = 4_000_000;
        cluster.supplyCaps[PT_sUSDe_29MAY2025       ] = 4_000_000;
        cluster.supplyCaps[PT_USDe_27MAR2025        ] = 4_000_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[USDC                     ] = 18_000_000;
        cluster.borrowCaps[USDT                     ] = 18_000_000;
        cluster.borrowCaps[FDUSD                    ] = 18_000_000;
        cluster.borrowCaps[PYUSD                    ] = 18_000_000;
        cluster.borrowCaps[rlUSD                    ] = 18_000_000;
        cluster.borrowCaps[USDa                     ] = 18_000_000;
        cluster.borrowCaps[wUSDM                    ] = 18_000_000;
        cluster.borrowCaps[wUSDL                    ] = 18_000_000;
        cluster.borrowCaps[wM                       ] = 18_000_000;
        cluster.borrowCaps[USDS                     ] = 18_000_000;
        cluster.borrowCaps[sUSDS                    ] = 6_000_000;
        cluster.borrowCaps[DAI                      ] = 18_000_000;
        cluster.borrowCaps[sDAI                     ] = 6_000_000;
        cluster.borrowCaps[USD0                     ] = 18_000_000;
        cluster.borrowCaps[USD0PlusPlus             ] = 4_800_000;
        cluster.borrowCaps[USDe                     ] = 6_000_000;
        cluster.borrowCaps[sUSDe                    ] = 4_800_000;
        cluster.borrowCaps[deUSD                    ] = 3_600_000;
        cluster.borrowCaps[sdeUSD                   ] = 2_880_000;
        cluster.borrowCaps[mBASIS                   ] = 1_800_000;
        cluster.borrowCaps[PT_USD0PlusPlus_30JAN2025] = type(uint256).max;
        cluster.borrowCaps[PT_USD0PlusPlus_27MAR2025] = type(uint256).max;
        cluster.borrowCaps[PT_USD0PlusPlus_26JUN2025] = type(uint256).max;
        cluster.borrowCaps[PT_sUSDe_27MAR2025       ] = type(uint256).max;
        cluster.borrowCaps[PT_sUSDe_29MAY2025       ] = type(uint256).max;
        cluster.borrowCaps[PT_USDe_27MAR2025        ] = type(uint256).max;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY,  Kink(90%)=16.18% APY  Max=101.38% APY
            uint256[4] memory irm_USD_1_MEGA_YIELD = [uint256(0), uint256(1229443272), uint256(40583508868), uint256(3865470566)];

            // Base=0% APY,  Kink(30%)=12.75% APY  Max=848.77% APY
            uint256[4] memory irm_USD_3_MEGA_YIELD = [uint256(0), uint256(2951312420), uint256(22450463582), uint256(1288490188)];

            cluster.kinkIRMParams[USDC        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USDT        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[FDUSD       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[PYUSD       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[rlUSD       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USDa        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[wUSDM       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[wUSDL       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[wM          ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USDS        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[sUSDS       ] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[DAI         ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[sDAI        ] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[USD0        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USD0PlusPlus] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[USDe        ] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[sUSDe       ] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[deUSD       ] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[sdeUSD      ] = irm_USD_3_MEGA_YIELD;
            cluster.kinkIRMParams[mBASIS      ] = irm_USD_3_MEGA_YIELD;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                                 0                1       2       3       4       5       6       7       8       9       10      11      12      13      14      15      16      17      18      19      20      21      22      23      24      25
        //                                 USDC             USDT    FDUSD   PYUSD   rlUSD   USDA    wUSDM   wUSDL   wM      USDS    sUSDS   DAI     sDAI    USD0    USD0++  USDe    sUSDe   deUSD   sdeUSD  mBASIS  PT_USD0PlusPlus_30JAN2025 PT_USD0PlusPlus_27MAR2025 PT_USD0PlusPlus_26JUN2025 PT_sUSDe_27MAR2025 PT_sUSDe_29MAY2025 PT_USDe_27MAR2025
        /* 0  USDC                      */ [uint16(0.00e4), 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.00e4, 0.95e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  USDT                      */ [uint16(0.95e4), 0.00e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.00e4, 0.95e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  FDUSD                     */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 3  PYUSD                     */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 4  rlUSD                     */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 5  USDa                      */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 6  wUSDM                     */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 7  wUSDL                     */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 8  wM                        */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 9  USDS                      */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 10 sUSDS                     */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 11 DAI                       */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 12 sDAI                      */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 13 USD0                      */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 14 USD0PlusPlus              */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 15 USDe                      */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 16 sUSDe                     */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 17 deUSD                     */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 18 sdeUSD                    */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 19 mBASIS                    */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 20 PT_USD0PlusPlus_30JAN2025 */ [uint16(0.84e4), 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.90e4, 0.90e4, 0.84e4, 0.00e4, 0.84e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 21 PT_USD0PlusPlus_27MAR2025 */ [uint16(0.84e4), 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.90e4, 0.90e4, 0.84e4, 0.00e4, 0.84e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 22 PT_USD0PlusPlus_26JUN2025 */ [uint16(0.84e4), 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.90e4, 0.90e4, 0.84e4, 0.00e4, 0.84e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 23 PT_sUSDe_27MAR2025        */ [uint16(0.81e4), 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.81e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 24 PT_sUSDe_29MAY2025        */ [uint16(0.81e4), 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.81e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 25 PT_USDe_27MAR2025         */ [uint16(0.81e4), 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.81e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
        cluster.externalLTVs = [
        //                                 0                1       2       3       4       5       6       7       8       9       10      11      12      13      14      15      16      17      18      19      20      21      22      23      24      25
        //                                 USDC             USDT    FDUSD   PYUSD   rlUSD   USDA    wUSDM   wUSDL   wM      USDS    sUSDS   DAI     sDAI    USD0    USD0++  USDe    sUSDe   deUSD   sdeUSD  mBASIS  PT_USD0PlusPlus_30JAN2025 PT_USD0PlusPlus_27MAR2025 PT_USD0PlusPlus_26JUN2025 PT_sUSDe_27MAR2025 PT_sUSDe_29MAY2025 PT_USDe_27MAR2025
        /* 0  Prime USDC                */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  Prime USDT                */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];
    }

    function postOperations() internal override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            perspectiveVerify(peripheryAddresses.governedPerspective, cluster.vaults[i]);
        }
        executeBatchPrank(Ownable(peripheryAddresses.governedPerspective).owner());

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i]);

            if (i < 20) {
                PerspectiveVerifier.verifyPerspective(
                    peripheryAddresses.eulerUngovernedNzxPerspective,
                    cluster.vaults[i],
                    PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | PerspectiveVerifier.E__GOVERNOR,
                    PerspectiveVerifier.E__LTV_COLLATERAL_RAMPING | PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_LENGTH | 
                    PerspectiveVerifier.E__ORACLE_INVALID_ADAPTER
                );
            } else {
                PerspectiveVerifier.verifyPerspective(
                    peripheryAddresses.escrowedCollateralPerspective,
                    cluster.vaults[i],
                    PerspectiveVerifier.E__ORACLE_INVALID_ROUTER | PerspectiveVerifier.E__UNIT_OF_ACCOUNT | 
                    PerspectiveVerifier.E__GOVERNOR | PerspectiveVerifier.E__LIQUIDATION_DISCOUNT | 
                    PerspectiveVerifier.E__LIQUIDATION_COOL_OFF_TIME,
                    PerspectiveVerifier.E__SINGLETON
                );
            }
        }
    }
}
