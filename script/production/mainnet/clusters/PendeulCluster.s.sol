// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../../utils/PerspectiveCheck.s.sol";

import {SnapshotRegistry} from "../../../../src/SnapshotRegistry/SnapshotRegistry.sol";

contract Cluster is ManageCluster {
    function configureCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/mainnet/clusters/PendeulCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            USDC,
            LBTC,
            eBTC,
            WBTC,
            cbBTC,
            tBTC,
            pumpBTC,
            SOLVBTC,
            USD0,
            USD0PlusPlus,
            PT_LBTC_27MAR2025,
            PT_corn_LBTC_26DEC2024,
            PT_eBTC_26DEC2024,
            PT_corn_eBTC_27MAR2025,
            PT_corn_pumpBTC_26DEC2024,
            PT_pumpBTC_27MAR2025,
            PT_solvBTC_26DEC2024,
            PT_USD0PlusPlus_27MAR2025,
            PT_USD0PlusPlus_26JUN2025
        ];

        // define the governors here
        cluster.oracleRoutersGovernor = EULER_DAO_MULTISIG;
        cluster.vaultsGovernor = EULER_DAO_MULTISIG;

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
        cluster.oracleProviders[USDC                     ] = "PythOracle";
        cluster.oracleProviders[LBTC                     ] = "CrossAdapter=RedstoneClassicOracle+PythOracle";
        cluster.oracleProviders[eBTC                     ] = "CrossAdapter=RateProviderOracle+PythOracle";
        cluster.oracleProviders[WBTC                     ] = "PythOracle";
        cluster.oracleProviders[cbBTC                    ] = "PythOracle";
        cluster.oracleProviders[tBTC                     ] = "PythOracle";
        cluster.oracleProviders[pumpBTC                  ] = "CrossAdapter=FixedRateOracle+PythOracle";
        cluster.oracleProviders[SOLVBTC                  ] = "CrossAdapter=FixedRateOracle+PythOracle";
        cluster.oracleProviders[USD0                     ] = "PythOracle";
        cluster.oracleProviders[USD0PlusPlus             ] = "PythOracle";
        cluster.oracleProviders[PT_LBTC_27MAR2025        ] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_corn_LBTC_26DEC2024   ] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_eBTC_26DEC2024        ] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_corn_eBTC_27MAR2025   ] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_corn_pumpBTC_26DEC2024] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_pumpBTC_27MAR2025     ] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_solvBTC_26DEC2024     ] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_USD0PlusPlus_27MAR2025] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[PT_USD0PlusPlus_26JUN2025] = "CrossAdapter=PendleOracle+PythOracle";
        cluster.oracleProviders[WETH                     ] = "PythOracle";
        cluster.oracleProviders[wstETH                   ] = "PythOracle";
        cluster.oracleProviders[cbETH                    ] = "PythOracle";
        cluster.oracleProviders[WEETH                    ] = "PythOracle";
        cluster.oracleProviders[USDT                     ] = "PythOracle";
        cluster.oracleProviders[USDS                     ] = "ChronicleOracle";
        cluster.oracleProviders[sUSDS                    ] = "ExternalVault|ChronicleOracle";
        cluster.oracleProviders[mTBILL                   ] = "0x256f8fA018e8e6F5B54b1fF708efd5ec73E20AC6";
        cluster.oracleProviders[USDY                     ] = "PythOracle";
        cluster.oracleProviders[wM                       ] = "FixedRateOracle";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[USDC                     ] = 12_000_000;
        cluster.supplyCaps[LBTC                     ] = 150;
        cluster.supplyCaps[eBTC                     ] = 150;
        cluster.supplyCaps[WBTC                     ] = 150;
        cluster.supplyCaps[cbBTC                    ] = 150;
        cluster.supplyCaps[tBTC                     ] = 150;
        cluster.supplyCaps[pumpBTC                  ] = 150;
        cluster.supplyCaps[SOLVBTC                  ] = 150;
        cluster.supplyCaps[USD0                     ] = 12_000_000;
        cluster.supplyCaps[USD0PlusPlus             ] = 10_000_000;
        cluster.supplyCaps[PT_LBTC_27MAR2025        ] = 175;
        cluster.supplyCaps[PT_corn_LBTC_26DEC2024   ] = 175;
        cluster.supplyCaps[PT_eBTC_26DEC2024        ] = 175;
        cluster.supplyCaps[PT_corn_eBTC_27MAR2025   ] = 175;
        cluster.supplyCaps[PT_corn_pumpBTC_26DEC2024] = 175;
        cluster.supplyCaps[PT_pumpBTC_27MAR2025     ] = 175;
        cluster.supplyCaps[PT_solvBTC_26DEC2024     ] = 175;
        cluster.supplyCaps[PT_USD0PlusPlus_27MAR2025] = 20_000_000;
        cluster.supplyCaps[PT_USD0PlusPlus_26JUN2025] = 5_000_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[USDC                     ] = 10_560_000;
        cluster.borrowCaps[LBTC                     ] = 128;
        cluster.borrowCaps[eBTC                     ] = 128;
        cluster.borrowCaps[WBTC                     ] = 128;
        cluster.borrowCaps[cbBTC                    ] = 128;
        cluster.borrowCaps[tBTC                     ] = 128;
        cluster.borrowCaps[pumpBTC                  ] = 128;
        cluster.borrowCaps[SOLVBTC                  ] = 128;
        cluster.borrowCaps[USD0                     ] = 9_840_000;
        cluster.borrowCaps[USD0PlusPlus             ] = 2_500_000;
        cluster.borrowCaps[PT_LBTC_27MAR2025        ] = type(uint256).max;
        cluster.borrowCaps[PT_corn_LBTC_26DEC2024   ] = type(uint256).max;
        cluster.borrowCaps[PT_eBTC_26DEC2024        ] = type(uint256).max;
        cluster.borrowCaps[PT_corn_eBTC_27MAR2025   ] = type(uint256).max;
        cluster.borrowCaps[PT_corn_pumpBTC_26DEC2024] = type(uint256).max;
        cluster.borrowCaps[PT_pumpBTC_27MAR2025     ] = type(uint256).max;
        cluster.borrowCaps[PT_solvBTC_26DEC2024     ] = type(uint256).max;
        cluster.borrowCaps[PT_USD0PlusPlus_27MAR2025] = type(uint256).max;
        cluster.borrowCaps[PT_USD0PlusPlus_26JUN2025] = type(uint256).max;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY,  Kink(85%)=2.79% APY  Max=122.55% APY
            uint256[4] memory irmBTC        = [uint256(0), uint256(238858791), uint256(37995478916), uint256(3650722201)];

            // Base=0% APY,  Kink(85%)=4.60% APY  Max=232.01% APY
            uint256[4] memory irmBTCPendeul = [uint256(0), uint256(390374595), uint256(56812501546), uint256(3650722201)];

            // Base=0% APY,  Kink(88%)=5.13% APY  Max=101.38% APY
            uint256[4] memory irmRWA_1     = [uint256(0), uint256(419441267),  uint256(39964512631), uint256(3779571220)];

            // Base=0% APY,  Kink(82%)=6.72% APY  Max=122.55% APY
            uint256[4] memory irmRWA_2     = [uint256(0), uint256(585195609),  uint256(30124952282), uint256(3521873182)];

            // Base=0% APY,  Kink(25%)=4.08% APY  Max=145.96% APY
            uint256[4] memory irmRWA_YLD_2 = [uint256(0), uint256(1180191988), uint256(8460321485),  uint256(1073741824)];

            cluster.kinkIRMParams[USDC        ] = irmRWA_1;
            cluster.kinkIRMParams[LBTC        ] = irmBTCPendeul;
            cluster.kinkIRMParams[eBTC        ] = irmBTCPendeul;
            cluster.kinkIRMParams[WBTC        ] = irmBTC;
            cluster.kinkIRMParams[cbBTC       ] = irmBTC;
            cluster.kinkIRMParams[tBTC        ] = irmBTC;
            cluster.kinkIRMParams[pumpBTC     ] = irmBTCPendeul;
            cluster.kinkIRMParams[SOLVBTC     ] = irmBTCPendeul;
            cluster.kinkIRMParams[USD0        ] = irmRWA_2;
            cluster.kinkIRMParams[USD0PlusPlus] = irmRWA_YLD_2;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                                 0               1       2       3       4       5       6       7       8       9       10                11                     12                13                     14                        15                   16                    17                   18
        //                                 USDC            LBTC    eBTC    WBTC    cbBTC   tBTC    pumpBTC SOLVBTC USD0,   USD0++, PT_LBTC_27MAR2025 PT_corn_LBTC_26DEC2024 PT_eBTC_26DEC2024 PT_corn_eBTC_27MAR2025 PT_corn_pumpBTC_26DEC2024 PT_pumpBTC_27MAR2025 PT_solvBTC_26DEC2024, PT_USD0++_27MAR2025, PT_USD0++_26JUN2025
        /* 0  USDC                     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.80e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  LBTC                     */ [uint16(0.80e4), 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.80e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  eBTC                     */ [uint16(0.00e4), 0.80e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 3  WBTC                     */ [uint16(0.80e4), 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.80e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 4  cbBTC                    */ [uint16(0.80e4), 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.80e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 5  tBTC                     */ [uint16(0.80e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.80e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 6  pumpBTC                  */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 7  SOLVBTC                  */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 8  USD0                     */ [uint16(0.80e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.80e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 9  USD0++                   */ [uint16(0.80e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 10 PT_LBTC_27MAR2025        */ [uint16(0.00e4), 0.90e4, 0.00e4, 0.80e4, 0.80e4, 0.80e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 11 PT_corn_LBTC_26DEC2024   */ [uint16(0.00e4), 0.85e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 12 PT_eBTC_26DEC2024        */ [uint16(0.00e4), 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 13 PT_corn_eBTC_27MAR2025   */ [uint16(0.00e4), 0.00e4, 0.85e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 14 PT_corn_pumpBTC_26DEC2024*/ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.85e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 15 PT_pumpBTC_27MAR2025     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 16 PT_solvBTC_26DEC2024     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 17 PT_USD0++_27MAR2025      */ [uint16(0.85e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.85e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 18 PT_USD0++_26JUN2025      */ [uint16(0.85e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.85e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
        cluster.externalLTVs = [
        //                    0               1       2       3       4       5       6       7       8       9       10                11                     12                13                     14                        15                   16                    17                   18
        //                    USDC            LBTC    eBTC    WBTC    cbBTC   tBTC    pumpBTC SOLVBTC USD0,   USD0++, PT_LBTC_27MAR2025 PT_corn_LBTC_26DEC2024 PT_eBTC_26DEC2024 PT_corn_eBTC_27MAR2025 PT_corn_pumpBTC_26DEC2024 PT_pumpBTC_27MAR2025 PT_solvBTC_26DEC2024, PT_USD0++_27MAR2025, PT_USD0++_26JUN2025
        /* 0  Prime WETH  */ [uint16(0.85e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  Prime wstETH*/ [uint16(0.85e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  Prime cbETH */ [uint16(0.83e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 3  Prime weETH */ [uint16(0.83e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 4  Prime USDC  */ [uint16(0.95e4), 0.89e4, 0.77e4, 0.82e4, 0.89e4, 0.77e4, 0.77e4, 0.77e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 5  Prime USDT  */ [uint16(0.95e4), 0.89e4, 0.77e4, 0.82e4, 0.89e4, 0.77e4, 0.77e4, 0.77e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 6  Prime USDS  */ [uint16(0.92e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 7  Prime sUSDs */ [uint16(0.92e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 8  Prime mTBILL*/ [uint16(0.92e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
      ///* 9  Prime USDY  */ [uint16(0.92e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 10 Prime wM    */ [uint16(0.90e4), 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 11 Prime tBTC  */ [uint16(0.80e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.95e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 12 Prime WBTC  */ [uint16(0.83e4), 0.92e4, 0.90e4, 0.95e4, 0.92e4, 0.85e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 13 Prime cbBTC */ [uint16(0.80e4), 0.90e4, 0.90e4, 0.90e4, 0.95e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 14 Prime LBTC  */ [uint16(0.80e4), 0.95e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];
    }

    function verifyCluster() internal override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            perspectiveVerify(peripheryAddresses.governedPerspective, cluster.vaults[i]);
        }
        executeBatchPrank(EULER_DEPLOYER);

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i]);

            if (i < 10) {
                PerspectiveVerifier.verifyPerspective(
                    peripheryAddresses.eulerUngovernedNzxPerspective,
                    cluster.vaults[i],
                    PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | PerspectiveVerifier.E__GOVERNOR,
                    PerspectiveVerifier.E__LTV_COLLATERAL_RAMPING | PerspectiveVerifier.E__ORACLE_INVALID_ADAPTER
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
