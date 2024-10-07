// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {MaintainCluster} from "../MaintainCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../../utils/PerspectiveCheck.s.sol";

contract Cluster is MaintainCluster {
    address internal constant DAO_MULTISIG = 0xcAD001c30E96765aC90307669d578219D4fb1DCe;

    function initializeCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/mainnet/clusters/PrimeCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [WETH, wstETH, cbETH, WEETH,  USDC, USDT, USDS, tBTC, WBTC, cbBTC];

        // define the governors here
        cluster.oracleRouterGovernor = DAO_MULTISIG;
        cluster.vaultsGovernor = DAO_MULTISIG;

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
        // although Redstone Classic oracles reuse the ChainlinkOracle contract and return "ChainlinkOracle" name, 
        // they should be referred to as "RedstoneClassicOracle"
        cluster.oracleProviders[WETH   ] = "ChainlinkOracle";
        cluster.oracleProviders[wstETH ] = "CrossAdapter=LidoFundamentalOracle+ChainlinkOracle";
        cluster.oracleProviders[cbETH  ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[WEETH  ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[USDC   ] = "ChainlinkOracle";
        cluster.oracleProviders[USDT   ] = "ChainlinkOracle";
        cluster.oracleProviders[USDS   ] = "ChronicleOracle";
        cluster.oracleProviders[tBTC   ] = "ChainlinkOracle";
        cluster.oracleProviders[WBTC   ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[cbBTC  ] = "ChainlinkOracle";

        // define supply caps here
        cluster.supplyCaps[WETH   ] = 378_000;
        cluster.supplyCaps[wstETH ] = 160_000;
        cluster.supplyCaps[cbETH  ] = 8_740;
        cluster.supplyCaps[WEETH  ] = 36_000;
        cluster.supplyCaps[USDC   ] = 500_000_000;
        cluster.supplyCaps[USDT   ] = 1_000_000_000;
        cluster.supplyCaps[USDS   ] = 20_000_000;
        cluster.supplyCaps[tBTC   ] = 157;
        cluster.supplyCaps[WBTC   ] = 1_570;
        cluster.supplyCaps[cbBTC  ] = 157;

        // define borrow caps here
        cluster.borrowCaps[WETH   ] = 310_000;
        cluster.borrowCaps[wstETH ] = 64_000;
        cluster.borrowCaps[cbETH  ] = 3_490;
        cluster.borrowCaps[WEETH  ] = 9_010;
        cluster.borrowCaps[USDC   ] = 440_000_000;
        cluster.borrowCaps[USDT   ] = 880_000_000;
        cluster.borrowCaps[USDS   ] = 16_400_000;
        cluster.borrowCaps[tBTC   ] = 129;
        cluster.borrowCaps[WBTC   ] = 1_290;
        cluster.borrowCaps[cbBTC  ] = 129;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(82%)=2.79% APY  Max=122.55% APY
            uint256[4] memory irmETH       = [uint256(0), uint256(247597527),  uint256(31662899097), uint256(3521873182)];

            // Base=0% APY  Kink(82%)=2.79% APY  Max=122.55% APY
            uint256[4] memory irmBTC       = [uint256(0), uint256(247597527),  uint256(31662899097), uint256(3521873182)];

            // Base=0% APY  Kink(88%)=5.13% APY  Max=101.38% APY
            uint256[4] memory irmRWA_T1    = [uint256(0), uint256(419441267),  uint256(39964512631), uint256(3779571220)];

            // Base=0% APY  Kink(40%)=4.60% APY  Max=145.96% APY
            uint256[4] memory irmETH_LST   = [uint256(0), uint256(829546015),  uint256(10514117840), uint256(1717986918)];

            // Base=0% APY  Kink(25%)=4.60% APY  Max=848.77% APY
            uint256[4] memory irmETH_LRT   = [uint256(0), uint256(1327273625), uint256(21691866441), uint256(1073741824)];

            // Base=0% APY  Kink(82%)=6.72% APY  Max=122.55% APY
            uint256[4] memory irmRWA_T2    = [uint256(0), uint256(585195609),  uint256(30124952282), uint256(3521873182)];

            cluster.kinkIRMParams[WETH   ] = irmETH;
            cluster.kinkIRMParams[wstETH ] = irmETH_LST;
            cluster.kinkIRMParams[cbETH  ] = irmETH_LST;
            cluster.kinkIRMParams[WEETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[USDC   ] = irmRWA_T1;
            cluster.kinkIRMParams[USDT   ] = irmRWA_T1;
            cluster.kinkIRMParams[USDS   ] = irmRWA_T2;
            cluster.kinkIRMParams[tBTC   ] = irmBTC;
            cluster.kinkIRMParams[WBTC   ] = irmBTC;
            cluster.kinkIRMParams[cbBTC  ] = irmBTC;
        }
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0       1       2       3       4       5       6       7       8       9   
        //                WETH    wstETH  cbETH   WEETH   USDC    USDT    USDS    tBTC    WBTC    cbBTC
        /* 0  WETH    */ [0.00e4, 0.91e4, 0.91e4, 0.91e4, 0.87e4, 0.87e4, 0.87e4, 0.81e4, 0.81e4, 0.81e4],
        /* 1  wstETH  */ [0.91e4, 0.00e4, 0.91e4, 0.91e4, 0.84e4, 0.84e4, 0.84e4, 0.77e4, 0.77e4, 0.77e4],
        /* 2  cbETH   */ [0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.73e4, 0.73e4, 0.73e4],
        /* 3  WEETH   */ [0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.81e4, 0.81e4, 0.81e4, 0.73e4, 0.73e4, 0.73e4],
        /* 4  USDC    */ [0.87e4, 0.87e4, 0.87e4, 0.87e4, 0.00e4, 0.93e4, 0.93e4, 0.87e4, 0.87e4, 0.87e4],
        /* 5  USDT    */ [0.87e4, 0.87e4, 0.87e4, 0.87e4, 0.93e4, 0.00e4, 0.93e4, 0.87e4, 0.87e4, 0.87e4],
        /* 6  USDS    */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.00e4, 0.81e4, 0.81e4, 0.81e4],
        /* 7  tBTC    */ [0.69e4, 0.69e4, 0.69e4, 0.69e4, 0.78e4, 0.78e4, 0.78e4, 0.00e4, 0.88e4, 0.88e4],
        /* 8  WBTC    */ [0.73e4, 0.73e4, 0.73e4, 0.73e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.00e4, 0.90e4],
        /* 9  cbBTC   */ [0.69e4, 0.69e4, 0.69e4, 0.69e4, 0.78e4, 0.78e4, 0.78e4, 0.88e4, 0.88e4, 0.00e4]
        ];
    }

    function verifyCluster() internal override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(cluster.vaults[i]);

            PerspectiveVerifier.verifyPerspective(
                peripheryAddresses.eulerUngovernedNzxPerspective,
                cluster.vaults[i],
                PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | PerspectiveVerifier.E__GOVERNOR | PerspectiveVerifier.E__LTV_COLLATERAL_RECOGNITION
            );
        }
    }
}
