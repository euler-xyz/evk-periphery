// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant USDaf                = 0x9Cf12ccd6020b6888e4D4C4e4c7AcA33c1eB91f8;
    address internal constant sUSDaf               = 0x89E93172AEF8261Db8437b90c3dCb61545a05317;
    address internal constant PT_sUSDaf_13NOV2025 = 0xA3CA92a69c6809607837bc3BD6B13e4c1E1e8aE9;
    address internal constant PT_USDaf_13NOV2025   = 0x9B02ca5685E9C332b158c01459562a161c8e8ADf;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/USDaf.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, USDaf, sUSDaf, PT_sUSDaf_13NOV2025, PT_USDaf_13NOV2025];
    }

    function configureCluster() internal override {
        super.configureCluster();

        // define unit of account here
        cluster.unitOfAccount = USD;

        // define oracle providers here.
        // adapter names can be found in the relevant adapter contract (as returned by the `name` function).
        // for cross adapters, use the following format: "CrossAdapter=<adapterName1>+<adapterName2>".
        // although Redstone Classic oracles reuse the ChainlinkOracle contract and returns "ChainlinkOracle" name,
        // they should be referred to as "RedstoneClassicOracle".
        // in case the asset is an ERC4626 vault itself (i.e. sUSDS) and is recognized as a valid external vault as per
        // External Vaults Registry, the string should be preceeded by "ExternalVault|" prefix. this is in order to
        // resolve the asset (vault) in the oracle router.
        // in case the adapter is not present in the Adapter Registry, the adapter address can be passed instead in form
        // of a string.
        cluster.oracleProviders[USDC                ] = "0xD35657aE033A86FFa8fc6Bc767C5eb57C7c3D4B8";
        cluster.oracleProviders[USDT                ] = "0x575Ffc02361368A2708c00bC7e299d1cD1c89f8A";
        cluster.oracleProviders[USDaf                ] = "0x9B403C1D62D273131BdDF1920Fe357Bc19Eb07F5";
        cluster.oracleProviders[sUSDaf               ] = "ExternalVault|0x9B403C1D62D273131BdDF1920Fe357Bc19Eb07F5";
        cluster.oracleProviders[PT_sUSDaf_13NOV2025 ] = "0x048652F1A3C6FA4D2049c9C5Bdf99d7C379364D0";
        cluster.oracleProviders[PT_USDaf_13NOV2025  ] = "0x669c360863d619D0d4dc4D27df82c0bBc87D7166";

        // usdaf to usd fixed 0x9B403C1D62D273131BdDF1920Fe357Bc19Eb07F5
        // pt sUSDaf to usd 0x048652F1A3C6FA4D2049c9C5Bdf99d7C379364D0
        // pt USDaf to usd 0x669c360863d619D0d4dc4D27df82c0bBc87D7166

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=2.7% APY  Max=40.00% APY
            //cluster.kinkIRMParams[WETH] = [uint256(0), uint256(218407859), uint256(22859618857), uint256(3865470566)];

            cluster.irms[USDC  ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDT  ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDaf  ] = IRM_ADAPTIVE_USD;
            cluster.irms[sUSDaf ] = IRM_ADAPTIVE_USD_YB;
        }
        // LTV Override
        uint16 LTV__LOW = 0.87e4;
        uint16 LTV_HIGH = 0.91e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //               0          1         2         3         4         5         
            //              USDC       USDT      USDaf      sUSDaf    PT_sUSDaf  PT_USDaf 
            /* 0  USDC    */ [LTV_ZERO, LTV_HIGH, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 1  USDT    */ [LTV_HIGH, LTV_ZERO, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 2  USDaf    */ [LTV__LOW, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 3  sUSDf   */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 4  PT_sUSDaf*/ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO],
            /* 6  PT_USDaf */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1         2         3         4         5        
        //                     USDC      USDT      USDaf      sUSDf     PT_sUSDaf  PT_USDaf
        /* 0  Prime USDC   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
        /* 1  Prime USDT   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO]
        ];
    }
}
