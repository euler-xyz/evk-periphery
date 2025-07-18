// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/base/clusters/BaseCluster.json";

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
            wsuperOETHb,
            USDC,
            USDT0,
            EURC,
            cbBTC,
            LBTC,
            AERO,
            USDS,
            SUSDS
        ];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = governorAddresses.accessControlEmergencyGovernor;

        // define unit of account here
        cluster.unitOfAccount = USD;

        // define fee receiver here and interest fee here. if needed to be defined per asset, populate the feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = address(0);
        cluster.interestFee = 0.1e4;

        cluster.interestFeeOverride[WETH] = 0;
        cluster.interestFeeOverride[USDC] = 0;
        cluster.interestFeeOverride[EURC] = 0;

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
        cluster.oracleProviders[WETH  ] = "ChainlinkOracle";
        cluster.oracleProviders[wstETH] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[cbETH ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[weETH ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[ezETH ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[RETH  ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[wsuperOETHb] = "ExternalVault|0x5A3AD0dA327b48e295961487B4ee1B0F6646e25D";
        cluster.oracleProviders[USDC  ] = "ChainlinkOracle";
        cluster.oracleProviders[USDT0  ] = "0x94dae37fdf8302c5800661a93de43b77d8709925";
        cluster.oracleProviders[EURC  ] = "ChainlinkOracle";
        cluster.oracleProviders[cbBTC ] = "0xedcD625e06c487A68b5d9f2a5b020E9BE00b95A7";
        cluster.oracleProviders[LBTC  ] = "CrossAdapter=RedstoneClassicOracle+ChainlinkOracle";
        cluster.oracleProviders[AERO  ] = "ChainlinkOracle";
        cluster.oracleProviders[USDS  ] = "0x847BD1550634c35Ea5d6528B0414e0BE69584010";
        cluster.oracleProviders[SUSDS ] = "0xdbcC3537800134A316f8D01eDa38d07c8d34174c";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[WETH  ] = 15_000;
        cluster.supplyCaps[wstETH] = 5_000;
        cluster.supplyCaps[cbETH ] = 5_000;
        cluster.supplyCaps[weETH ] = 5_000;
        cluster.supplyCaps[ezETH ] = 5_000;
        cluster.supplyCaps[RETH  ] = 5_000;
        cluster.supplyCaps[wsuperOETHb] = 2_500;
        cluster.supplyCaps[USDC  ] = 60_000_000;
        cluster.supplyCaps[USDT0  ] = 6_000_000;
        cluster.supplyCaps[EURC  ] = 20_000_000;
        cluster.supplyCaps[cbBTC ] = 250;
        cluster.supplyCaps[LBTC  ] = 250;
        cluster.supplyCaps[AERO  ] = 2_000_000;
        cluster.supplyCaps[USDS  ] = 40_000_000;
        cluster.supplyCaps[SUSDS ] = 20_000_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[WETH  ] = 12_700;
        cluster.borrowCaps[wstETH] = 2_000;
        cluster.borrowCaps[cbETH ] = 2_000;
        cluster.borrowCaps[weETH ] = 1_250;
        cluster.borrowCaps[ezETH ] = 1_250;
        cluster.borrowCaps[RETH  ] = 2_000;
        cluster.borrowCaps[wsuperOETHb] = 625;
        cluster.borrowCaps[USDC  ] = 54_000_000;
        cluster.borrowCaps[USDT0  ] = 5_400_000;
        cluster.borrowCaps[EURC  ] = 18_000_000;
        cluster.borrowCaps[cbBTC ] = 213;
        cluster.borrowCaps[LBTC  ] = 63;
        cluster.borrowCaps[AERO  ] = 1_600_000;
        cluster.borrowCaps[USDS  ] = 36_000_000;
        cluster.borrowCaps[SUSDS ] = 18_000_000;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(90%)=2.40% APY  Max=80.00% APY
            uint256[4] memory irmETH         = [uint256(0), uint256(194425692),  uint256(41617711740), uint256(3865470566)];

            // Base=0% APY,  Kink(85%)=0.60% APY  Max=100.00% APY
            uint256[4] memory irmBTC         = [uint256(0), uint256(51925146),  uint256(33799862224), uint256(3650722201)];

            // Base=0% APY,  Kink(85%)=0.50% APY  Max=80.00% APY
            uint256[4] memory irmETH_LST_1   = [uint256(0), uint256(43292497),  uint256(28666371159), uint256(3650722201)];

            // Base=0% APY,  Kink(40%)=4.60% APY  Max=145.96% APY
            uint256[4] memory irmETH_LST_2   = [uint256(0), uint256(829546015),  uint256(10514117840), uint256(1717986918)];

            // Base=0% APY,  Kink(25%)=4.60% APY  Max=848.77% APY
            uint256[4] memory irmETH_LRT   = [uint256(0), uint256(1327273625), uint256(21691866441), uint256(1073741824)];

            // Base=0% APY,  Kink(90%)=6.50% APY  Max=40.00% APY
            uint256[4] memory irmUSD       = [uint256(0), uint256(516261061),  uint256(20178940043), uint256(3865470566)];

            // Base=0% APY,  Kink(25%)=2.50% APY  Max=100.00% APY
            uint256[4] memory irmBTC_LRT   = [uint256(0), uint256(728739169), uint256(6575907893), uint256(1073741824)];

            // Base=0% APY,  Kink(80%)=8.87% APY  Max=848.77% APY
            uint256[4] memory irmDEFI      = [uint256(0), uint256(783779538),  uint256(79868472958), uint256(3435973836)];

            // Base=0% APY,  Kink(40%)=2.79% APY  Max=145.96% APY
            uint256[4] memory irmRWA_YLD_1 = [uint256(0), uint256(507574932),  uint256(10728765229), uint256(1717986918)];

            cluster.kinkIRMParams[WETH  ] = irmETH;
            cluster.kinkIRMParams[wstETH] = irmETH_LST_1;
            cluster.kinkIRMParams[cbETH ] = irmETH_LST_2;
            cluster.kinkIRMParams[weETH ] = irmETH_LRT;
            cluster.kinkIRMParams[ezETH ] = irmETH_LRT;
            cluster.kinkIRMParams[RETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[wsuperOETHb] = irmETH_LRT;
            cluster.kinkIRMParams[USDC  ] = irmUSD;
            cluster.kinkIRMParams[USDT0  ] = irmUSD;
            cluster.kinkIRMParams[EURC  ] = irmUSD;
            cluster.kinkIRMParams[cbBTC ] = irmBTC;
            cluster.kinkIRMParams[LBTC  ] = irmBTC_LRT;
            cluster.kinkIRMParams[AERO  ] = irmDEFI;
            cluster.kinkIRMParams[USDS  ] = irmUSD;
            cluster.kinkIRMParams[SUSDS ] = irmRWA_YLD_1;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0               1       2       3       4       5       6       7       8       9       10      11      12      13      14
        //                WETH            wstETH  cbETH   weETH   ezETH   RETH    wsOETHb USDC    USDT0   EURC    cbBTC   LBTC    AERO    USDS    SUSDS
        /* 0  WETH    */ [uint16(0.00e4), 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.80e4, 0.87e4, 0.85e4, 0.85e4, 0.78e4, 0.78e4, 0.78e4, 0.87e4, 0.00e4],
        /* 1  wstETH  */ [uint16(0.93e4), 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.80e4, 0.83e4, 0.81e4, 0.83e4, 0.77e4, 0.77e4, 0.77e4, 0.83e4, 0.00e4],
        /* 2  cbETH   */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.92e4, 0.93e4, 0.93e4, 0.80e4, 0.80e4, 0.78e4, 0.80e4, 0.75e4, 0.75e4, 0.75e4, 0.80e4, 0.00e4],
        /* 3  weETH   */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.80e4, 0.80e4, 0.78e4, 0.80e4, 0.75e4, 0.75e4, 0.75e4, 0.80e4, 0.00e4],
        /* 4  ezETH   */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.80e4, 0.77e4, 0.75e4, 0.77e4, 0.72e4, 0.72e4, 0.72e4, 0.77e4, 0.00e4],
        /* 5  RETH    */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.80e4, 0.77e4, 0.75e4, 0.77e4, 0.72e4, 0.72e4, 0.72e4, 0.77e4, 0.00e4],
        /* 6  wsOETHb */ [uint16(0.93e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 7  USDC    */ [uint16(0.85e4), 0.83e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.00e4, 0.00e4, 0.93e4, 0.90e4, 0.80e4, 0.80e4, 0.80e4, 0.95e4, 0.00e4],
        /* 8  USDT0   */ [uint16(0.83e4), 0.81e4, 0.78e4, 0.78e4, 0.78e4, 0.78e4, 0.00e4, 0.94e4, 0.00e4, 0.88e4, 0.78e4, 0.78e4, 0.78e4, 0.93e4, 0.00e4],
        /* 9  EURC    */ [uint16(0.85e4), 0.83e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.00e4, 0.90e4, 0.88e4, 0.00e4, 0.80e4, 0.80e4, 0.80e4, 0.90e4, 0.00e4],
        /* 10 cbBTC   */ [uint16(0.75e4), 0.73e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.00e4, 0.80e4, 0.78e4, 0.80e4, 0.00e4, 0.90e4, 0.70e4, 0.80e4, 0.00e4],
        /* 11 LBTC    */ [uint16(0.75e4), 0.73e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.00e4, 0.80e4, 0.78e4, 0.80e4, 0.90e4, 0.00e4, 0.70e4, 0.80e4, 0.00e4],
        /* 12 AERO    */ [uint16(0.65e4), 0.65e4, 0.65e4, 0.65e4, 0.65e4, 0.65e4, 0.00e4, 0.65e4, 0.63e4, 0.65e4, 0.65e4, 0.65e4, 0.00e4, 0.65e4, 0.00e4],
        /* 13 USDS    */ [uint16(0.75e4), 0.73e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.00e4, 0.94e4, 0.92e4, 0.92e4, 0.80e4, 0.80e4, 0.80e4, 0.00e4, 0.00e4],
        /* 14 SUSDS   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.94e4, 0.92e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.94e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
    }

    function postOperations() internal view override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }
    }
}
