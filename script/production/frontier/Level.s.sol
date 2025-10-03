// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant lvlUSD     = 0x7C1156E515aA1A2E851674120074968C905aAF37;
    address internal constant slvlUSD    = 0x4737D9b4592B40d51e110b94c9C043c6654067Ae;
    address internal constant PT_lvlUSD  = 0x207F7205fd6c4b602Fa792C8b2B60e6006D4a0b8;
    address internal constant PT_slvlUSD = 0x2CA5f2C4300450D53214B00546795c1c07B89acB;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/Level.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, lvlUSD, slvlUSD, PT_lvlUSD, PT_slvlUSD];
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
        cluster.oracleProviders[USDC      ] = "0xD35657aE033A86FFa8fc6Bc767C5eb57C7c3D4B8";
        cluster.oracleProviders[USDT      ] = "0x575Ffc02361368A2708c00bC7e299d1cD1c89f8A";
        cluster.oracleProviders[lvlUSD    ] = "0x35402e99763fc9ed16f4d559ea7d87a18ac2127b";
        cluster.oracleProviders[slvlUSD   ] = "ExternalVault|0x35402e99763fc9ed16f4d559ea7d87a18ac2127b";
        cluster.oracleProviders[PT_lvlUSD ] = "0xc6be2c0025e372322879dc5c57c34c671918ae6e";
        cluster.oracleProviders[PT_slvlUSD] = "0x372d1116058a71fe45163f51bf1da4b10a671fb7";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=2.7% APY  Max=40.00% APY
            //cluster.kinkIRMParams[WETH] = [uint256(0), uint256(218407859), uint256(22859618857), uint256(3865470566)];

            cluster.irms[USDC   ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDT   ] = IRM_ADAPTIVE_USD;
            cluster.irms[lvlUSD ] = IRM_ADAPTIVE_USD;
            cluster.irms[slvlUSD] = IRM_ADAPTIVE_USD_YB;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                  0         1         2         3         4         5
            //                  USDC      USDT      lvlUSD    slvlUSD   PT_lvlUSD PT_slvlUSD
            /* 0  USDC      */ [LTV_ZERO, LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 1  USDT      */ [LTV_HIGH, LTV_ZERO, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 2  lvlUSD    */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 3  slvlUSD   */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 4  PT_lvlUSD */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 5  PT_slvlUSD*/ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1         2         3         4         5
        //                     USDC      USDT      lvlUSD    slvlUSD   PT_lvlUSD PT_slvlUSD
        /* 0  Prime USDC   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
        /* 1  Prime USDT   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO]
        ];
    }
}
