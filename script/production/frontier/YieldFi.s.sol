// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant yUSD     = 0x19Ebd191f7A24ECE672ba13A302212b5eF7F35cb;
    address internal constant PT_yUSD  = 0xD1d0fF7BB555f57A9604CE06bca704ab97A0049A;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/YieldFi.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, yUSD, PT_yUSD];
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
        cluster.oracleProviders[USDC      ] = "0xD35657aE033A86FFa8fc6Bc767C5eb57C7c3D4B8";
        cluster.oracleProviders[USDT      ] = "0x575Ffc02361368A2708c00bC7e299d1cD1c89f8A";
        cluster.oracleProviders[yUSD      ] = "ExternalVault|0xD35657aE033A86FFa8fc6Bc767C5eb57C7c3D4B8";
        cluster.oracleProviders[PT_yUSD   ] = "0x5Bc6C01611dC945eA2F05d9e5d670846bD3a554C";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=2.7% APY  Max=40.00% APY
            //cluster.kinkIRMParams[WETH] = [uint256(0), uint256(218407859), uint256(22859618857), uint256(3865470566)];

            cluster.irms[USDC   ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDT   ] = IRM_ADAPTIVE_USD;
            cluster.irms[yUSD   ] = IRM_ADAPTIVE_USD_YB;
        }

        cluster.rampDuration = 30 days;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                  0         1         2         3
            //                  USDC      USDT      yUSD      PT_yUSD
            /* 0  USDC      */ [LTV_ZERO, LTV_HIGH, LTV_ZERO, LTV_ZERO],
            /* 1  USDT      */ [LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 2  yUSD      */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO],
            /* 3  PT_yUSD   */ [LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1         2         3
        //                     USDC      USDT      yUSD      PT_yUSD
        /* 0  Prime USDC   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO],
        /* 1  Prime USDT   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO]
        ];
    }
}
