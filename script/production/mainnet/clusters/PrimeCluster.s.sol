// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../../utils/PerspectiveCheck.s.sol";

contract Cluster is ManageCluster {
    function configureCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/mainnet/clusters/PrimeCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [WETH, wstETH, cbETH, WEETH, USDC, USDT, USDS, sUSDS, mTBILL, wM, tBTC, WBTC, cbBTC, LBTC];

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
        cluster.oracleProviders[WETH   ] = "ChainlinkOracle";
        cluster.oracleProviders[wstETH ] = "CrossAdapter=LidoOracle+ChainlinkOracle";
        cluster.oracleProviders[cbETH  ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[WEETH  ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[USDC   ] = "ChainlinkOracle";
        cluster.oracleProviders[USDT   ] = "ChainlinkOracle";
        cluster.oracleProviders[USDS   ] = "ChronicleOracle";
        cluster.oracleProviders[sUSDS  ] = "ExternalVault|ChronicleOracle";
        cluster.oracleProviders[mTBILL ] = "0x256f8fA018e8e6F5B54b1fF708efd5ec73E20AC6";
        cluster.oracleProviders[wM     ] = "FixedRateOracle";
        cluster.oracleProviders[tBTC   ] = "ChainlinkOracle";
        cluster.oracleProviders[WBTC   ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[cbBTC  ] = "CrossAdapter=ChronicleOracle+ChainlinkOracle";
        cluster.oracleProviders[LBTC   ] = "CrossAdapter=RedstoneClassicOracle+ChainlinkOracle";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[WETH   ] = 378_000;
        cluster.supplyCaps[wstETH ] = 160_000;
        cluster.supplyCaps[cbETH  ] = 8_740;
        cluster.supplyCaps[WEETH  ] = 36_000;
        cluster.supplyCaps[USDC   ] = 1_000_000_000;
        cluster.supplyCaps[USDT   ] = 1_000_000_000;
        cluster.supplyCaps[USDS   ] = 50_000_000;
        cluster.supplyCaps[sUSDS  ] = 45_000_000;
        cluster.supplyCaps[mTBILL ] = 15_000_000;
        cluster.supplyCaps[wM     ] = 2_500_000;
        cluster.supplyCaps[tBTC   ] = 157;
        cluster.supplyCaps[WBTC   ] = 1_570;
        cluster.supplyCaps[cbBTC  ] = 157;
        cluster.supplyCaps[LBTC   ] = 157;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[WETH   ] = 321_000;
        cluster.borrowCaps[wstETH ] = 64_000;
        cluster.borrowCaps[cbETH  ] = 3_490;
        cluster.borrowCaps[WEETH  ] = 9_010;
        cluster.borrowCaps[USDC   ] = 880_000_000;
        cluster.borrowCaps[USDT   ] = 880_000_000;
        cluster.borrowCaps[USDS   ] = 41_000_000;
        cluster.borrowCaps[sUSDS  ] = 18_000_000;
        cluster.borrowCaps[mTBILL ] = 6_000_000;
        cluster.borrowCaps[wM     ] = 2_050_000;
        cluster.borrowCaps[tBTC   ] = 133;
        cluster.borrowCaps[WBTC   ] = 1_330;
        cluster.borrowCaps[cbBTC  ] = 133;
        cluster.borrowCaps[LBTC   ] = 39;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(85%)=2.79% APY  Max=122.55% APY
            uint256[4] memory irmETH       = [uint256(0), uint256(238858791),  uint256(37995478916), uint256(3650722201)];

            // Base=0% APY,  Kink(85%)=2.79% APY  Max=122.55% APY
            uint256[4] memory irmBTC       = [uint256(0), uint256(238858791),  uint256(37995478916), uint256(3650722201)];

            // Base=0% APY,  Kink(88%)=5.13% APY  Max=101.38% APY
            uint256[4] memory irmRWA_1     = [uint256(0), uint256(419441267),  uint256(39964512631), uint256(3779571220)];

            // Base=0% APY,  Kink(40%)=4.60% APY  Max=145.96% APY
            uint256[4] memory irmETH_LST   = [uint256(0), uint256(829546015),  uint256(10514117840), uint256(1717986918)];

            // Base=0% APY,  Kink(25%)=4.60% APY  Max=848.77% APY
            uint256[4] memory irmETH_LRT   = [uint256(0), uint256(1327273625), uint256(21691866441), uint256(1073741824)];

            // Base=0% APY,  Kink(25%)=4.60% APY  Max=848.77% APY
            uint256[4] memory irmBTC_LRT   = [uint256(0), uint256(1327273625), uint256(21691866441), uint256(1073741824)];

            // Base=0% APY,  Kink(82%)=6.72% APY  Max=122.55% APY
            uint256[4] memory irmRWA_2     = [uint256(0), uint256(585195609),  uint256(30124952282), uint256(3521873182)];

            // Base=0% APY,  Kink(40%)=2.79% APY  Max=145.96% APY
            uint256[4] memory irmRWA_YLD_1 = [uint256(0), uint256(507574932),  uint256(10728765229), uint256(1717986918)];

            cluster.kinkIRMParams[WETH   ] = irmETH;
            cluster.kinkIRMParams[wstETH ] = irmETH_LST;
            cluster.kinkIRMParams[cbETH  ] = irmETH_LST;
            cluster.kinkIRMParams[WEETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[USDC   ] = irmRWA_1;
            cluster.kinkIRMParams[USDT   ] = irmRWA_1;
            cluster.kinkIRMParams[USDS   ] = irmRWA_2;
            cluster.kinkIRMParams[sUSDS  ] = irmRWA_YLD_1;
            cluster.kinkIRMParams[mTBILL ] = irmRWA_YLD_1;
            cluster.kinkIRMParams[wM     ] = irmRWA_2;
            cluster.kinkIRMParams[tBTC   ] = irmBTC;
            cluster.kinkIRMParams[WBTC   ] = irmBTC;
            cluster.kinkIRMParams[cbBTC  ] = irmBTC;
            cluster.kinkIRMParams[LBTC   ] = irmBTC_LRT;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 30 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0       1       2       3       4       5       6       7       8       9       10      11      12      13
        //                WETH    wstETH  cbETH   WEETH   USDC    USDT    USDS    sUSDS   mTBILL  wM      tBTC    WBTC    cbBTC   LBTC
        /* 0  WETH    */ [0.00e4, 0.90e4, 0.93e4, 0.88e4, 0.85e4, 0.85e4, 0.89e4, 0.77e4, 0.89e4, 0.89e4, 0.80e4, 0.82e4, 0.83e4, 0.83e4],
        /* 1  wstETH  */ [0.93e4, 0.00e4, 0.93e4, 0.88e4, 0.85e4, 0.85e4, 0.86e4, 0.77e4, 0.86e4, 0.86e4, 0.79e4, 0.79e4, 0.79e4, 0.79e4],
        /* 2  cbETH   */ [0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.83e4, 0.83e4, 0.83e4, 0.83e4, 0.83e4, 0.83e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* 3  WEETH   */ [0.92e4, 0.90e4, 0.92e4, 0.00e4, 0.83e4, 0.83e4, 0.83e4, 0.77e4, 0.83e4, 0.83e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* 4  USDC    */ [0.85e4, 0.82e4, 0.89e4, 0.80e4, 0.00e4, 0.95e4, 0.95e4, 0.85e4, 0.95e4, 0.95e4, 0.77e4, 0.82e4, 0.89e4, 0.89e4],
        /* 5  USDT    */ [0.85e4, 0.82e4, 0.89e4, 0.80e4, 0.95e4, 0.00e4, 0.95e4, 0.85e4, 0.95e4, 0.95e4, 0.77e4, 0.82e4, 0.89e4, 0.89e4],
        /* 6  USDS    */ [0.83e4, 0.83e4, 0.83e4, 0.83e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.83e4, 0.83e4, 0.83e4, 0.83e4],
        /* 7  sUSDS   */ [0.83e4, 0.82e4, 0.83e4, 0.80e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.77e4, 0.82e4, 0.83e4, 0.83e4],
        /* 8  mTBILL  */ [0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 9  wM      */ [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4],
        /* 10 tBTC    */ [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.80e4, 0.80e4, 0.80e4, 0.77e4, 0.80e4, 0.80e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4],
        /* 11 WBTC    */ [0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.83e4, 0.83e4, 0.83e4, 0.77e4, 0.83e4, 0.83e4, 0.85e4, 0.00e4, 0.92e4, 0.92e4],
        /* 12 cbBTC   */ [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4],
        /* 13 LBTC    */ [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
        cluster.externalLTVs = [
            //                       0       1       2       3       4       5       6       7       8       9       10      11      12      13
            //                       WETH    wstETH  cbETH   WEETH   USDC    USDT    USDS    sUSDS   mTBILL  wM      tBTC    WBTC    cbBTC   LBTC
            /* 0  Escrow WETH    */ [0.00e4, 0.92e4, 0.95e4, 0.90e4, 0.87e4, 0.87e4, 0.91e4, 0.79e4, 0.91e4, 0.91e4, 0.82e4, 0.84e4, 0.85e4, 0.85e4],
            /* 1  Escrow wstETH  */ [0.95e4, 0.00e4, 0.95e4, 0.90e4, 0.87e4, 0.87e4, 0.88e4, 0.79e4, 0.88e4, 0.88e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
            /* 2  Escrow cbETH   */ [0.94e4, 0.94e4, 0.00e4, 0.94e4, 0.85e4, 0.85e4, 0.85e4, 0.85e4, 0.85e4, 0.85e4, 0.77e4, 0.77e4, 0.77e4, 0.77e4],
            /* 3  Escrow WEETH   */ [0.94e4, 0.92e4, 0.94e4, 0.00e4, 0.85e4, 0.85e4, 0.85e4, 0.79e4, 0.85e4, 0.85e4, 0.77e4, 0.77e4, 0.77e4, 0.77e4],
            /* 4  Escrow USDC    */ [0.87e4, 0.84e4, 0.91e4, 0.82e4, 0.00e4, 0.97e4, 0.97e4, 0.87e4, 0.97e4, 0.97e4, 0.79e4, 0.84e4, 0.91e4, 0.91e4],
            /* 5  Escrow USDT    */ [0.87e4, 0.84e4, 0.91e4, 0.82e4, 0.97e4, 0.00e4, 0.97e4, 0.87e4, 0.97e4, 0.97e4, 0.79e4, 0.84e4, 0.91e4, 0.91e4],
            /* 6  Escrow USDS    */ [0.85e4, 0.85e4, 0.85e4, 0.85e4, 0.94e4, 0.94e4, 0.00e4, 0.94e4, 0.94e4, 0.94e4, 0.85e4, 0.85e4, 0.85e4, 0.85e4],
            /* 7  Escrow sUSDS   */ [0.85e4, 0.84e4, 0.85e4, 0.82e4, 0.94e4, 0.94e4, 0.94e4, 0.00e4, 0.94e4, 0.94e4, 0.79e4, 0.84e4, 0.85e4, 0.85e4],
            /* 8  Escrow mTBILL  */ [0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.94e4, 0.94e4, 0.94e4, 0.94e4, 0.00e4, 0.94e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
            /* 9  Escrow wM      */ [0.73e4, 0.73e4, 0.73e4, 0.73e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.73e4, 0.73e4, 0.73e4, 0.73e4],
            /* 10 Escrow tBTC    */ [0.73e4, 0.73e4, 0.73e4, 0.73e4, 0.82e4, 0.82e4, 0.82e4, 0.79e4, 0.82e4, 0.82e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4],
            /* 11 Escrow WBTC    */ [0.77e4, 0.77e4, 0.77e4, 0.77e4, 0.85e4, 0.85e4, 0.85e4, 0.79e4, 0.85e4, 0.85e4, 0.87e4, 0.00e4, 0.94e4, 0.94e4],
            /* 12 Escrow cbBTC   */ [0.73e4, 0.73e4, 0.73e4, 0.73e4, 0.82e4, 0.82e4, 0.82e4, 0.82e4, 0.82e4, 0.82e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4],
            /* 13 Escrow LBTC    */ [0.73e4, 0.73e4, 0.73e4, 0.73e4, 0.82e4, 0.82e4, 0.82e4, 0.82e4, 0.82e4, 0.82e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4]
        ];
    }

    function verifyCluster() internal override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            perspectiveVerify(peripheryAddresses.governedPerspective, cluster.vaults[i]);
        }
        executeBatchPrank(EULER_DEPLOYER);

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i]);

            PerspectiveVerifier.verifyPerspective(
                peripheryAddresses.eulerUngovernedNzxPerspective,
                cluster.vaults[i],
                PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | PerspectiveVerifier.E__GOVERNOR,
                PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_SEPARATION | PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_BORROW |
                PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_LIQUIDATION | PerspectiveVerifier.E__LTV_COLLATERAL_RAMPING |
                PerspectiveVerifier.E__ORACLE_INVALID_ADAPTER
            );
        }
    }
}
