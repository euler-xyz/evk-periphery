// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

/// @dev NOTE: Deploy
/// @dev NOTE: Deploy IRM
contract Cluster is ManageCluster {
    address internal constant WLPsrUSDe = 0x5F0E654410a281E7Ed04c370B9D25d2A0286b935;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/WLPsrUSDe.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, USDE, WLPsrUSDe];
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
        
        cluster.oracleProviders[USDC] = "0xD35657aE033A86FFa8fc6Bc767C5eb57C7c3D4B8";
        cluster.oracleProviders[USDT] = "0x575Ffc02361368A2708c00bC7e299d1cD1c89f8A";
        cluster.oracleProviders[USDE] = "0x5C06Aae48AfD91Fc2C619a44619ce33d3F62C3c8";
        cluster.oracleProviders[WLPsrUSDe] = "0x8d3ACc7A2E12EDCf2667729e145B5a7269073115";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            cluster.irms[USDC ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDT ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDE ] = IRM_ADAPTIVE_USD;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                          0         1
            //                          USDC      USDT      USDE      WLPsrUSDe
            /* 0  USDC   */            [LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 1  USDT   */            [LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 2  USDE   */            [LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 3  WLPsrUSDe*/          [LTV__LOW, LTV__LOW, LTV__LOW, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1         2         3       
        //                     USDC      USDT      USDE      WLPsrUSDe
        /* 0  Prime USDC   */ [LTV_HIGH, LTV_HIGH, LTV_HIGH, LTV_ZERO],
        /* 1  Prime USDT   */ [LTV_HIGH, LTV_HIGH, LTV_HIGH, LTV_ZERO],
        /* 2  Prime USDE   */ [LTV_HIGH, LTV_HIGH, LTV_HIGH, LTV_ZERO]
        ];
    }
}
