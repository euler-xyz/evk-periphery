// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant rUSD  = 0x09D4214C03D01F49544C0448DBE3A27f768F2b34;
    address internal constant srUSD = 0x738d1115B90efa71AE468F1287fc864775e23a31;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/Reservoir.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, rUSD, srUSD];
    }

    function configureCluster() internal override {
        super.configureCluster();

        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = governorAddresses.accessControlEmergencyGovernor;

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
        cluster.oracleProviders[USDC ] = "0xD35657aE033A86FFa8fc6Bc767C5eb57C7c3D4B8";
        cluster.oracleProviders[USDT ] = "0x575Ffc02361368A2708c00bC7e299d1cD1c89f8A";
        cluster.oracleProviders[rUSD ] = "0x01dbd40296c232c2c58c99ff69084b256bee33ee";
        cluster.oracleProviders[srUSD] = "0xd54bc197150487a40d4ebd4fb215ca4fa996173e";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=2.7% APY  Max=40.00% APY
            //cluster.kinkIRMParams[WETH] = [uint256(0), uint256(218407859), uint256(22859618857), uint256(3865470566)];

            cluster.irms[USDC  ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDT  ] = IRM_ADAPTIVE_USD;
            cluster.irms[rUSD  ] = IRM_ADAPTIVE_USD;
            cluster.irms[srUSD ] = IRM_ADAPTIVE_USD_YB;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //               0          1         2         3
            //               USDC       USDT      rUSD      srUSD
            /* 0  USDC    */ [LTV_ZERO, LTV_HIGH, LTV__LOW, LTV_ZERO],
            /* 1  USDT    */ [LTV_HIGH, LTV_ZERO, LTV__LOW, LTV_ZERO],
            /* 2  rUSD    */ [LTV__LOW, LTV__LOW, LTV_ZERO, LTV_ZERO],
            /* 3  srUSD   */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1         2         3    
        //                     USDC      USDT      rUSD      srUSD
        /* 0  Prime USDC   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO],
        /* 1  Prime USDT   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO]
        ];
    }
}
