// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant USDf                = 0xFa2B947eEc368f42195f24F36d2aF29f7c24CeC2;
    address internal constant sUSDf               = 0xc8CF6D7991f15525488b2A83Df53468D682Ba4B0;
    address internal constant PT_sUSDf_25SEPT2025 = 0xAB365C0879024481E4ad3b47bd6FeA9c10014FbC;
    address internal constant PT_USDf_29JAN2026   = 0xeC3b5e45dD278d5AB9CDB31754B54DB314e9D52a;
    address internal constant PT_sUSDf_29JAN2026   = 0x48E502FBB6Ff2CC687d049150E2C8AdDC765A43a;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/Falcon.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, USDf, sUSDf, PT_sUSDf_25SEPT2025, PT_sUSDf_29JAN2026, PT_USDf_29JAN2026];
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
        // External Vaults Registry, the string should be preceded by "ExternalVault|" prefix. this is in order to
        // resolve the asset (vault) in the oracle router.
        // in case the adapter is not present in the Adapter Registry, the adapter address can be passed instead in form
        // of a string.
        cluster.oracleProviders[USDC                ] = "0xD35657aE033A86FFa8fc6Bc767C5eb57C7c3D4B8";
        cluster.oracleProviders[USDT                ] = "0x575Ffc02361368A2708c00bC7e299d1cD1c89f8A";
        cluster.oracleProviders[USDf                ] = "0xEd8e9151602E40233D358d6C323d9F9717a1bec4";
        cluster.oracleProviders[sUSDf               ] = "ExternalVault|0xEd8e9151602E40233D358d6C323d9F9717a1bec4";
        cluster.oracleProviders[PT_sUSDf_25SEPT2025 ] = "0x21414e20FBEf2c2212f2C658Aa42657EeA1b16ba";
        cluster.oracleProviders[PT_sUSDf_29JAN2026  ] = "0x2623c14813e14482cA902F352BFa075259a9A602";
        cluster.oracleProviders[PT_USDf_29JAN2026   ] = "0x82214dece7cda7ee19a4d627e3f134a5f2401fc1";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=2.7% APY  Max=40.00% APY
            //cluster.kinkIRMParams[WETH] = [uint256(0), uint256(218407859), uint256(22859618857), uint256(3865470566)];

            cluster.irms[USDC  ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDT  ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDf  ] = IRM_ADAPTIVE_USD;
            cluster.irms[sUSDf ] = IRM_ADAPTIVE_USD_YB;
        }

        cluster.rampDuration = 30 days;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //               0          1         2         3         4         5         6
            //               USDC       USDT      USDf      sUSDf     PT_sUSDf  PT_sUSDf  PT_USDf
            /* 0  USDC    */ [LTV_ZERO, LTV_HIGH, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 1  USDT    */ [LTV_HIGH, LTV_ZERO, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 2  USDf    */ [LTV__LOW, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 3  sUSDf   */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 4  PT_sUSDf*/ [LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 5  PT_sUSDf*/ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 6  PT_USDf */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1         2         3         4         5         6
        //                     USDC      USDT      USDf      sUSDf     PT_sUSDf  PT_sUSDf  PT_USDf
        /* 0  Prime USDC   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
        /* 1  Prime USDT   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO]
        ];
    }
}
