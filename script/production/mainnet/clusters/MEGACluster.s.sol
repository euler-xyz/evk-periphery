// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {MaintainCluster} from "../MaintainCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../../utils/PerspectiveCheck.s.sol";
import "evk/EVault/shared/Constants.sol";

contract Cluster is MaintainCluster {
    function configureCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/mainnet/clusters/MEGACluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [WETH, wstETH, cbETH, WEETH, ezETH, RETH, METH, RSETH, sfrxETH, ETHx, rswETH, USDC, USDT, PYUSD, USDY, wM, mTBILL, USDe, wUSDM, EURC, sUSDe, USDS, sUSDS, stUSD, stEUR, FDUSD, USD0, GHO, crvUSD, FRAX, tBTC, WBTC, cbBTC, LBTC, eBTC, SOLVBTC];

        // define the governors here
        cluster.oracleRoutersGovernor = getDeployer();
        cluster.vaultsGovernor = getDeployer();

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
        cluster.hookedOps = OP_MAX_VALUE - 1;

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
        cluster.oracleProviders[ezETH  ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[RETH   ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[METH   ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[RSETH  ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[sfrxETH] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[ETHx   ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[rswETH ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[USDC   ] = "ChainlinkOracle";
        cluster.oracleProviders[USDT   ] = "ChainlinkOracle";
        cluster.oracleProviders[PYUSD  ] = "ChainlinkOracle";
        cluster.oracleProviders[USDY   ] = "PythOracle";
        cluster.oracleProviders[wM     ] = "FixedRateOracle";
        cluster.oracleProviders[mTBILL ] = "ChainlinkInfrequentOracle";
        cluster.oracleProviders[USDe   ] = "ChainlinkOracle";
        cluster.oracleProviders[wUSDM  ] = "ChainlinkOracle";
        cluster.oracleProviders[EURC   ] = "PythOracle";
        cluster.oracleProviders[sUSDe  ] = "ChainlinkOracle";
        cluster.oracleProviders[USDS   ] = "ChronicleOracle";
        cluster.oracleProviders[sUSDS  ] = "ChronicleOracle";
        cluster.oracleProviders[stUSD  ] = "ChainlinkOracle";
        cluster.oracleProviders[stEUR  ] = "ChainlinkOracle";
        cluster.oracleProviders[FDUSD  ] = "PythOracle";
        cluster.oracleProviders[USD0   ] = "ChainlinkOracle";
        cluster.oracleProviders[GHO    ] = "ChainlinkOracle";
        cluster.oracleProviders[crvUSD ] = "ChainlinkOracle";
        cluster.oracleProviders[FRAX   ] = "ChainlinkOracle";
        cluster.oracleProviders[tBTC   ] = "ChainlinkOracle";
        cluster.oracleProviders[WBTC   ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[cbBTC  ] = "ChainlinkOracle";
        cluster.oracleProviders[LBTC   ] = "CrossAdapter=RedstoneClassicOracle+ChainlinkOracle";
        cluster.oracleProviders[eBTC   ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[SOLVBTC] = "RedstoneClassicOracle";

        // define supply caps here
        cluster.supplyCaps[WETH   ] = 378_000;
        cluster.supplyCaps[wstETH ] = 160_000;
        cluster.supplyCaps[cbETH  ] = 8_740;
        cluster.supplyCaps[WEETH  ] = 36_000;
        cluster.supplyCaps[ezETH  ] = 9_270;
        cluster.supplyCaps[RETH   ] = 17_300;
        cluster.supplyCaps[METH   ] = 18_500;
        cluster.supplyCaps[RSETH  ] = 9_450;
        cluster.supplyCaps[sfrxETH] = 3_890;
        cluster.supplyCaps[ETHx   ] = 3_740;
        cluster.supplyCaps[rswETH ] = 3_880;
        cluster.supplyCaps[USDC   ] = 500_000_000;
        cluster.supplyCaps[USDT   ] = 1_000_000_000;
        cluster.supplyCaps[PYUSD  ] = 25_000_000;
        cluster.supplyCaps[USDY   ] = 9_520_000;
        cluster.supplyCaps[wM     ] = 1_000_000;
        cluster.supplyCaps[mTBILL ] = 250_000;
        cluster.supplyCaps[USDe   ] = 50_000_000;
        cluster.supplyCaps[wUSDM  ] = 2_500_000;
        cluster.supplyCaps[EURC   ] = 2_200_000;
        cluster.supplyCaps[sUSDe  ] = 2_270_000;
        cluster.supplyCaps[USDS   ] = 20_000_000;
        cluster.supplyCaps[sUSDS  ] = 1_000_000;
        cluster.supplyCaps[stUSD  ] = 250_000;
        cluster.supplyCaps[stEUR  ] = 211_000;
        cluster.supplyCaps[FDUSD  ] = 100_000_000;
        cluster.supplyCaps[USD0   ] = 25_000_000;
        cluster.supplyCaps[GHO    ] = 2_500_000;
        cluster.supplyCaps[crvUSD ] = 2_500_000;
        cluster.supplyCaps[FRAX   ] = 2_500_000;
        cluster.supplyCaps[tBTC   ] = 157;
        cluster.supplyCaps[WBTC   ] = 1_570;
        cluster.supplyCaps[cbBTC  ] = 157;
        cluster.supplyCaps[LBTC   ] = 157;
        cluster.supplyCaps[eBTC   ] = 157;
        cluster.supplyCaps[SOLVBTC] = 789;

        // define borrow caps here if needed

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

            // Base=0% APY  Kink(25%)=4.60% APY  Max=848.77% APY
            uint256[4] memory irmBTC_LRT   = [uint256(0), uint256(1327273625), uint256(21691866441), uint256(1073741824)];

            // Base=0% APY  Kink(82%)=6.72% APY  Max=122.55% APY
            uint256[4] memory irmRWA_T2    = [uint256(0), uint256(585195609),  uint256(30124952282), uint256(3521873182)];

            // Base=0% APY  Kink(78%)=8.87% APY  Max=145.96% APY
            uint256[4] memory irmRWA_T3    = [uint256(0), uint256(803876450),  uint256(27333024886), uint256(3350074490)];

            // Base=0% APY  Kink(40%)=2.79% APY  Max=145.96% APY
            uint256[4] memory irmRWA_YLD_T1= [uint256(0), uint256(507574932),  uint256(10728765229), uint256(1717986918)];

            // Base=0% APY  Kink(25%)=4.08% APY  Max=145.96% APY
            uint256[4] memory irmRWA_YLD_T2= [uint256(0), uint256(1180191988), uint256(8460321485),  uint256(1073741824)];

            cluster.kinkIRMParams[WETH   ] = irmETH;
            cluster.kinkIRMParams[wstETH ] = irmETH_LST;
            cluster.kinkIRMParams[cbETH  ] = irmETH_LST;
            cluster.kinkIRMParams[WEETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[ezETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[RETH   ] = irmETH_LST;
            cluster.kinkIRMParams[METH   ] = irmETH_LST;
            cluster.kinkIRMParams[RSETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[sfrxETH] = irmETH_LST;
            cluster.kinkIRMParams[ETHx   ] = irmETH_LST;
            cluster.kinkIRMParams[rswETH ] = irmETH_LRT;
            cluster.kinkIRMParams[USDC   ] = irmRWA_T1;
            cluster.kinkIRMParams[USDT   ] = irmRWA_T1;
            cluster.kinkIRMParams[PYUSD  ] = irmRWA_T2;
            cluster.kinkIRMParams[USDY   ] = irmRWA_YLD_T1;
            cluster.kinkIRMParams[wM     ] = irmRWA_T2;
            cluster.kinkIRMParams[mTBILL ] = irmRWA_YLD_T1;
            cluster.kinkIRMParams[USDe   ] = irmRWA_T2;
            cluster.kinkIRMParams[wUSDM  ] = irmRWA_T2;
            cluster.kinkIRMParams[EURC   ] = irmRWA_T2;
            cluster.kinkIRMParams[sUSDe  ] = irmRWA_YLD_T1;
            cluster.kinkIRMParams[USDS   ] = irmRWA_T2;
            cluster.kinkIRMParams[sUSDS  ] = irmRWA_YLD_T1;
            cluster.kinkIRMParams[stUSD  ] = irmRWA_YLD_T2;
            cluster.kinkIRMParams[stEUR  ] = irmRWA_YLD_T2;
            cluster.kinkIRMParams[FDUSD  ] = irmRWA_T2;
            cluster.kinkIRMParams[USD0   ] = irmRWA_T2;
            cluster.kinkIRMParams[GHO    ] = irmRWA_T3;
            cluster.kinkIRMParams[crvUSD ] = irmRWA_T3;
            cluster.kinkIRMParams[FRAX   ] = irmRWA_T3;
            cluster.kinkIRMParams[tBTC   ] = irmBTC;
            cluster.kinkIRMParams[WBTC   ] = irmBTC;
            cluster.kinkIRMParams[cbBTC  ] = irmBTC;
            cluster.kinkIRMParams[LBTC   ] = irmBTC_LRT;
            cluster.kinkIRMParams[eBTC   ] = irmBTC_LRT;
            cluster.kinkIRMParams[SOLVBTC] = irmBTC_LRT;
        }
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0       1       2       3       4       5       6       7       8       9       10      11      12      13      14      15      16      17      18      19      20      21      22      23      24      25      26      27      28      29      30      31      32      33      34      35
        //                WETH    wstETH  cbETH   WEETH   ezETH   RETH    METH    RSETH   sfrxETH ETHx    rswETH  USDC    USDT    PYUSD   USDY    wM      mTBILL  USDe    wUSDM   EURC    sUSDe   USDS    sUSDS   stUSD   stEUR   FDUSD   USD0    GHO     crvUSD  FRAX    tBTC    WBTC    cbBTC   LBTC    eBTC    SOLVBTC
        /* 0  WETH    */ [0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.83e4, 0.83e4, 0.83e4, 0.83e4, 0.83e4, 0.83e4],
        /* 1  wstETH  */ [0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.79e4, 0.79e4, 0.79e4, 0.79e4, 0.79e4, 0.79e4],
        /* 2  cbETH   */ [0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* 3  WEETH   */ [0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* 4  ezETH   */ [0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* 5  RETH    */ [0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* 6  METH    */ [0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* 7  RSETH   */ [0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4],
        /* 8  sfrxETH */ [0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4],
        /* 9  ETHx    */ [0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4],
        /* 10 rswETH  */ [0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4],
        /* 11 USDC    */ [0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.00e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4],
        /* 12 USDT    */ [0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.95e4, 0.00e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4],
        /* 13 PYUSD   */ [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* 14 USDY    */ [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* 15 wM      */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* 16 mTBILL  */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* 17 USDe    */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* 18 wUSDM   */ [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* 19 EURC    */ [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* 20 sUSDe   */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* 21 USDS    */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* 22 sUSDS   */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* 23 stUSD   */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* 24 stEUR   */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* 25 FDUSD   */ [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* 26 USD0    */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* 27 GHO     */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* 28 crvUSD  */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* 29 FRAX    */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* 30 tBTC    */ [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.00e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4],
        /* 31 WBTC    */ [0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.00e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4],
        /* 32 cbBTC   */ [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.00e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4],
        /* 33 LBTC    */ [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.00e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.90e4],
        /* 34 eBTC    */ [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.00e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4],
        /* 35 SOLVBTC */ [0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.00e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4]
        ];

        // define auxiliary ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of auxiliaryVaults in the addresses file
        cluster.auxiliaryLTVs = [
            //                      0       1       2       3       4       5       6       7       8       9       10      11      12      13      14      15      16      17      18      19      20      21      22      23      24      25      26      27      28      29      30      31      32      33      34      35
            //                      WETH    wstETH  cbETH   WEETH   ezETH   RETH    METH    RSETH   sfrxETH ETHx    rswETH  USDC    USDT    PYUSD   USDY    wM      mTBILL  USDe    wUSDM   EURC    sUSDe   USDS    sUSDS   stUSD   stEUR   FDUSD   USD0    GHO     crvUSD  FRAX    tBTC    WBTC    cbBTC   LBTC    eBTC    SOLVBTC
            /* 0  Prime WETH    */ [0]
            /* 1  Prime wstETH  */ 
            /* 2  Prime cbETH   */ 
            /* 3  Prime WEETH   */ 
            /* 4  Prime USDC    */ 
            /* 5  Prime USDT    */ 
            /* 6  Prime USDS    */ 
            /* 7  Prime tBTC    */ 
            /* 8  Prime WBTC    */ 
            /* 9  Prime cbBTC   */ 
        ];
    }

    function verifyCluster() internal override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            perspectiveVerify(peripheryAddresses.governedPerspective, cluster.vaults[i]);
        }
        executeBatchPrank(EULER_DEPLOYER, true);

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(cluster.vaults[i]);

            PerspectiveVerifier.verifyPerspective(
                peripheryAddresses.eulerUngovernedNzxPerspective,
                cluster.vaults[i],
                PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | PerspectiveVerifier.E__GOVERNOR,
                PerspectiveVerifier.E__LTV_COLLATERAL_RAMPING
            );
        }
    }
}
