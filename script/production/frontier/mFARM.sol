// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

/// @dev NOTE: Deploy
/// @dev NOTE: Deploy
contract Cluster is ManageCluster {
    address internal constant mFARM = 0xA19f6e0dF08a7917F2F8A33Db66D0AF31fF5ECA6;
    address internal constant PT_mFARM_11DEC2025 = 0x3E7736d0b1Ed0F6A0A555355b72c2C2d416564E1;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/mFARM.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, mFARM, PT_mFARM_11DEC2025];
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
        cluster.oracleProviders[USDC    ] = "0xD35657aE033A86FFa8fc6Bc767C5eb57C7c3D4B8";
        cluster.oracleProviders[USDT    ] = "0x575Ffc02361368A2708c00bC7e299d1cD1c89f8A";
        cluster.oracleProviders[mFARM] = "0xaB45699Abd95f9fB846225bB14F418D0119484e6";
        cluster.oracleProviders[PT_mFARM_11DEC2025] = "0x67497a35A59C1526FF29D7444c9B96f363c5Ab83";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            cluster.irms[USDC] = IRM_ADAPTIVE_USD;
            cluster.irms[USDT ] = IRM_ADAPTIVE_USD;
            cluster.irms[mFARM] = IRM_ADAPTIVE_USD_YB;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //               0          1         2         3       
            //               USDC       USDT      mFARM     PT_mFARM
            /* 0  USDC    */ [LTV_ZERO, LTV_HIGH, LTV_ZERO, LTV_ZERO],
            /* 1  USDT    */ [LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 2  mFARM   */ [LTV__LOW, LTV__LOW, LTV_ZERO, LTV_ZERO],
            /* 3  PT_FARM*/  [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO]
        ];

         cluster.externalLTVs = [
        //                     0         1         2         3        
        //                     USDC      USDT      mFARM     PT_mFARM
        /* 0  Prime USDC   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO],
        /* 1  Prime USDT   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO]
        ];
    }
}
