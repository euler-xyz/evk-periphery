// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../../utils/PerspectiveCheck.s.sol";
import {ClusterDump} from "../../../utils/ClusterDump.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/mainnet/clusters/PrimeCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            WETH,
            wstETH,
            cbETH,
            weETH,
            ezETH,
            RETH,
            mETH,
            rsETH,
            ETHx,
            USDC,
            USDT,
            wUSDM,
            wM,
            mTBILL,
            USDS,
            sUSDS,
            tBTC,
            WBTC,
            cbBTC,
            LBTC,
            eBTC,
            solvBTC
        ];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = multisigAddresses.DAO;
        cluster.vaultsGovernor = multisigAddresses.DAO;

        // define unit of account here
        cluster.unitOfAccount = USD;

        // define fee receiver here and interest fee here. if needed to be defined per asset, populate the feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = address(0);
        cluster.interestFee = 0.1e4;

        cluster.interestFeeOverride[WETH] = 0;
        cluster.interestFeeOverride[USDC] = 0;
        cluster.interestFeeOverride[USDT] = 0;

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
        cluster.oracleProviders[cbETH  ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[weETH  ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[ezETH  ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[RETH   ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[mETH   ] = "CrossAdapter=PythOracle+ChainlinkOracle";
        cluster.oracleProviders[rsETH  ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[ETHx   ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[USDC   ] = "ChainlinkOracle";
        cluster.oracleProviders[USDT   ] = "ChainlinkOracle";
        cluster.oracleProviders[wUSDM  ] = "ExternalVault|FixedRateOracle";
        cluster.oracleProviders[wM     ] = "FixedRateOracle";
        cluster.oracleProviders[mTBILL ] = "0x256f8fA018e8e6F5B54b1fF708efd5ec73E20AC6";
        cluster.oracleProviders[USDS   ] = "ChronicleOracle";
        cluster.oracleProviders[sUSDS  ] = "ExternalVault|ChronicleOracle";
        cluster.oracleProviders[tBTC   ] = "ChainlinkOracle";
        cluster.oracleProviders[WBTC   ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[cbBTC  ] = "ChainlinkOracle";
        cluster.oracleProviders[LBTC   ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[eBTC   ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[solvBTC] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[WETH   ] = 12_500;
        cluster.supplyCaps[wstETH ] = 12_500;
        cluster.supplyCaps[cbETH  ] = 12_500;
        cluster.supplyCaps[weETH  ] = 12_500;
        cluster.supplyCaps[ezETH  ] = 6_250;
        cluster.supplyCaps[RETH   ] = 6_250;
        cluster.supplyCaps[mETH   ] = 6_250;
        cluster.supplyCaps[rsETH  ] = 6_250;
        cluster.supplyCaps[ETHx   ] = 2_500;
        cluster.supplyCaps[USDC   ] = 50_000_000;
        cluster.supplyCaps[USDT   ] = 50_000_000;
        cluster.supplyCaps[wUSDM  ] = 5_000_000;
        cluster.supplyCaps[wM     ] = 5_000_000;
        cluster.supplyCaps[mTBILL ] = 5_000_000;
        cluster.supplyCaps[USDS   ] = 10_000_000;
        cluster.supplyCaps[sUSDS  ] = 8_000_000;
        cluster.supplyCaps[tBTC   ] = 100;
        cluster.supplyCaps[WBTC   ] = 500;
        cluster.supplyCaps[cbBTC  ] = 500;
        cluster.supplyCaps[LBTC   ] = 500;
        cluster.supplyCaps[eBTC   ] = 100;
        cluster.supplyCaps[solvBTC] = 100;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[WETH   ] = 10_600;
        cluster.borrowCaps[wstETH ] = 5_000;
        cluster.borrowCaps[cbETH  ] = 5_000;
        cluster.borrowCaps[weETH  ] = 3_120;
        cluster.borrowCaps[ezETH  ] = 1_560;
        cluster.borrowCaps[RETH   ] = 2_500;
        cluster.borrowCaps[mETH   ] = 2_500;
        cluster.borrowCaps[rsETH  ] = 1_560;
        cluster.borrowCaps[ETHx   ] = 1_000;
        cluster.borrowCaps[USDC   ] = 45_000_000;
        cluster.borrowCaps[USDT   ] = 45_000_000;
        cluster.borrowCaps[wUSDM  ] = 4_100_000;
        cluster.borrowCaps[wM     ] = 4_500_000;
        cluster.borrowCaps[mTBILL ] = 2_000_000;
        cluster.borrowCaps[USDS   ] = 9_000_000;
        cluster.borrowCaps[sUSDS  ] = 3_200_000;
        cluster.borrowCaps[tBTC   ] = 85;
        cluster.borrowCaps[WBTC   ] = 425;
        cluster.borrowCaps[cbBTC  ] = 425;
        cluster.borrowCaps[LBTC   ] = 125;
        cluster.borrowCaps[eBTC   ] = 25;
        cluster.borrowCaps[solvBTC] = 25;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(85%)=2.79% APY  Max=122.55% APY
            uint256[4] memory irmETH       = [uint256(0), uint256(238858791),  uint256(37995478916), uint256(3650722201)];

            // Base=0% APY,  Kink(85%)=2.79% APY  Max=122.55% APY
            uint256[4] memory irmBTC       = [uint256(0), uint256(238858791),  uint256(37995478916), uint256(3650722201)];

            // Base=0% APY,  Kink(40%)=4.60% APY  Max=145.96% APY
            uint256[4] memory irmETH_LST   = [uint256(0), uint256(829546015),  uint256(10514117840), uint256(1717986918)];

            // Base=0% APY,  Kink(25%)=4.60% APY  Max=848.77% APY
            uint256[4] memory irmETH_LRT   = [uint256(0), uint256(1327273625), uint256(21691866441), uint256(1073741824)];

            // Base=0% APY,  Kink(25%)=4.60% APY  Max=848.77% APY
            uint256[4] memory irmBTC_LRT   = [uint256(0), uint256(1327273625), uint256(21691866441), uint256(1073741824)];

            // Base=0% APY,  Kink(90%)=9.42% APY  Max=101.38% APY
            uint256[4] memory irmUSD_1     = [uint256(0), uint256(738003605),  uint256(45006465867), uint256(3865470566)];

            // Base=0% APY,  Kink(90%)=9.42% APY  Max=101.38% APY
            uint256[4] memory irmUSD_2     = [uint256(0), uint256(738003605),  uint256(45006465867), uint256(3865470566)];

            // Base=0% APY,  Kink(82%)=6.72% APY  Max=122.55% APY
            uint256[4] memory irmRWA_2     = [uint256(0), uint256(585195609),  uint256(30124952282), uint256(3521873182)];
            
            // Base=0% APY,  Kink(40%)=2.79% APY  Max=145.96% APY
            uint256[4] memory irmRWA_YLD_1 = [uint256(0), uint256(507574932),  uint256(10728765229), uint256(1717986918)];

            cluster.kinkIRMParams[WETH   ] = irmETH;
            cluster.kinkIRMParams[wstETH ] = irmETH_LST;
            cluster.kinkIRMParams[cbETH  ] = irmETH_LST;
            cluster.kinkIRMParams[weETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[ezETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[RETH   ] = irmETH_LST;
            cluster.kinkIRMParams[mETH   ] = irmETH_LST;
            cluster.kinkIRMParams[rsETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[ETHx   ] = irmETH_LST;
            cluster.kinkIRMParams[USDC   ] = irmUSD_1;
            cluster.kinkIRMParams[USDT   ] = irmUSD_1;
            cluster.kinkIRMParams[wUSDM  ] = irmRWA_2;
            cluster.kinkIRMParams[wM     ] = irmUSD_2;
            cluster.kinkIRMParams[mTBILL ] = irmRWA_YLD_1;
            cluster.kinkIRMParams[USDS   ] = irmUSD_2;
            cluster.kinkIRMParams[sUSDS  ] = irmRWA_YLD_1;
            cluster.kinkIRMParams[tBTC   ] = irmBTC;
            cluster.kinkIRMParams[WBTC   ] = irmBTC;
            cluster.kinkIRMParams[cbBTC  ] = irmBTC;
            cluster.kinkIRMParams[LBTC   ] = irmBTC_LRT;
            cluster.kinkIRMParams[eBTC   ] = irmBTC_LRT;
            cluster.kinkIRMParams[solvBTC] = irmBTC_LRT;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0               1       2       3       4       5       6       7       8       9       10      11      12      13      14      15      16      17      18      19      20      21
        //                WETH            wstETH  cbETH   weETH   ezETH   RETH    mETH    rsETH   ETHx    USDC    USDT    wUSDM   wM      mTBILL  USDS    sUSDS   tBTC    WBTC    cbBTC   LBTC    eBTC    solvBTC
        /* 0  WETH    */ [uint16(0.00e4), 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.85e4, 0.85e4, 0.85e4, 0.85e4, 0.00e4, 0.85e4, 0.00e4, 0.73e4, 0.73e4, 0.78e4, 0.78e4, 0.78e4, 0.78e4],
        /* 1  wstETH  */ [uint16(0.93e4), 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.83e4, 0.83e4, 0.83e4, 0.83e4, 0.00e4, 0.83e4, 0.00e4, 0.72e4, 0.72e4, 0.77e4, 0.77e4, 0.77e4, 0.77e4],
        /* 2  cbETH   */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.92e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.00e4, 0.80e4, 0.00e4, 0.70e4, 0.70e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* 3  weETH   */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.00e4, 0.80e4, 0.00e4, 0.70e4, 0.70e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* 4  ezETH   */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.77e4, 0.77e4, 0.77e4, 0.77e4, 0.00e4, 0.77e4, 0.00e4, 0.67e4, 0.67e4, 0.72e4, 0.72e4, 0.72e4, 0.72e4],
        /* 5  RETH    */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.77e4, 0.77e4, 0.77e4, 0.77e4, 0.00e4, 0.77e4, 0.00e4, 0.67e4, 0.67e4, 0.72e4, 0.72e4, 0.72e4, 0.72e4],
        /* 6  mETH    */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.77e4, 0.77e4, 0.77e4, 0.77e4, 0.00e4, 0.77e4, 0.00e4, 0.67e4, 0.67e4, 0.72e4, 0.72e4, 0.72e4, 0.72e4],
        /* 7  rsETH   */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.77e4, 0.77e4, 0.77e4, 0.77e4, 0.00e4, 0.77e4, 0.00e4, 0.67e4, 0.67e4, 0.72e4, 0.72e4, 0.72e4, 0.72e4],
        /* 8  ETHx    */ [uint16(0.87e4), 0.87e4, 0.87e4, 0.87e4, 0.87e4, 0.87e4, 0.87e4, 0.87e4, 0.00e4, 0.74e4, 0.74e4, 0.74e4, 0.74e4, 0.00e4, 0.74e4, 0.00e4, 0.64e4, 0.64e4, 0.69e4, 0.69e4, 0.69e4, 0.69e4],
        /* 9  USDC    */ [uint16(0.85e4), 0.83e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.00e4, 0.95e4, 0.95e4, 0.95e4, 0.00e4, 0.95e4, 0.00e4, 0.75e4, 0.75e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4],
        /* 10 USDT    */ [uint16(0.85e4), 0.83e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.95e4, 0.00e4, 0.95e4, 0.95e4, 0.00e4, 0.95e4, 0.00e4, 0.75e4, 0.75e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4],
        /* 11 wUSDM   */ [uint16(0.75e4), 0.73e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.00e4, 0.92e4, 0.00e4, 0.60e4, 0.60e4, 0.65e4, 0.65e4, 0.65e4, 0.65e4],
        /* 12 wM      */ [uint16(0.75e4), 0.73e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.90e4, 0.00e4, 0.60e4, 0.60e4, 0.65e4, 0.65e4, 0.65e4, 0.65e4],
        /* 13 mTBILL  */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 14 USDS    */ [uint16(0.75e4), 0.73e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.94e4, 0.94e4, 0.94e4, 0.94e4, 0.00e4, 0.00e4, 0.00e4, 0.75e4, 0.75e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4],
        /* 15 sUSDS   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.94e4, 0.94e4, 0.94e4, 0.94e4, 0.00e4, 0.94e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 16 tBTC    */ [uint16(0.75e4), 0.73e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.00e4, 0.75e4, 0.00e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4],
        /* 17 WBTC    */ [uint16(0.70e4), 0.68e4, 0.65e4, 0.65e4, 0.65e4, 0.65e4, 0.65e4, 0.65e4, 0.65e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.00e4, 0.75e4, 0.00e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4],
        /* 18 cbBTC   */ [uint16(0.75e4), 0.73e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.00e4, 0.80e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4],
        /* 19 LBTC    */ [uint16(0.75e4), 0.73e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.00e4, 0.80e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4],
        /* 20 eBTC    */ [uint16(0.72e4), 0.70e4, 0.67e4, 0.67e4, 0.67e4, 0.67e4, 0.67e4, 0.67e4, 0.67e4, 0.77e4, 0.77e4, 0.77e4, 0.77e4, 0.00e4, 0.77e4, 0.00e4, 0.87e4, 0.87e4, 0.87e4, 0.87e4, 0.00e4, 0.87e4],
        /* 21 solvBTC */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
        cluster.externalLTVs = [
        //                       0               1       2       3       4       5       6       7       8       9       10      11      12      13      14      15      16      17      18      19      20      21
        //                       WETH            wstETH  cbETH   weETH   ezETH   RETH    mETH    rsETH   ETHx    USDC    USDT    wUSDM   wM      mTBILL  USDS    sUSDS   tBTC    WBTC    cbBTC   LBTC    eBTC    solvBTC
        /* 0  Escrow WETH    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.87e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  Escrow wstETH  */ [uint16(0.95e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  Escrow cbETH   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 3  Escrow WEETH   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 4  Escrow USDC    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 5  Escrow USDT    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 6  Escrow USDS    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 7  Escrow sUSDS   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.94e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 8  Escrow mTBILL  */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 9  Escrow wM      */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 10 Escrow tBTC    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 11 Escrow WBTC    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 12 Escrow cbBTC   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 13 Escrow LBTC    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];
    }

    function postOperations() internal override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            perspectiveVerify(peripheryAddresses.governedPerspective, cluster.vaults[i]);
        }
        executeBatchPrank(Ownable(peripheryAddresses.governedPerspective).owner());

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);

            PerspectiveVerifier.verifyPerspective(
                peripheryAddresses.eulerUngovernedNzxPerspective,
                cluster.vaults[i],
                PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | PerspectiveVerifier.E__GOVERNOR,
                PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_SEPARATION | PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_BORROW |
                PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_LIQUIDATION | PerspectiveVerifier.E__LTV_COLLATERAL_RAMPING |
                PerspectiveVerifier.E__ORACLE_INVALID_ADAPTER,
                false
            );
        }

        ClusterDump dumper = new ClusterDump();
        dumper.dumpCluster(cluster.vaults, cluster.externalVaults);
    }
}
