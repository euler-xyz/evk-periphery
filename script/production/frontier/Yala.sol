// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant YU  = 0xE868084cf08F3c3db11f4B73a95473762d9463f7;
    address internal constant PT_YU_04SEP2025 = 0x076BdA095a434a7B00733115A0D679DE6478d9f8;
    address internal constant PT_YU_04DEC2025 = 0xD7158ee345dab25B4fC95266C2bd8d062f243A13;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/Yala.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, YU, PT_YU_04SEP2025, PT_YU_04DEC2025];
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
        cluster.oracleProviders[USDC            ] = "0xD35657aE033A86FFa8fc6Bc767C5eb57C7c3D4B8";
        cluster.oracleProviders[USDT            ] = "0x575Ffc02361368A2708c00bC7e299d1cD1c89f8A";
        cluster.oracleProviders[YU              ] = "0xFc9A5a244935CE0d62F1C1aFE8EFf0299cF604B6";
        cluster.oracleProviders[PT_YU_04SEP2025 ] = "0x0bE8Db7a0e2867A64a7f15de28cb178C28aa0387";
        cluster.oracleProviders[PT_YU_04DEC2025 ] = "0xB0Bc38a7a68E4F88bb07c9a71B431067470e9576";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=2.7% APY  Max=40.00% APY
            //cluster.kinkIRMParams[WETH] = [uint256(0), uint256(218407859), uint256(22859618857), uint256(3865470566)];

            cluster.irms[USDC  ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDT  ] = IRM_ADAPTIVE_USD;
            cluster.irms[YU  ] = IRM_ADAPTIVE_USD;
        }

        cluster.supplyCaps[USDC] = 0;
        cluster.supplyCaps[USDT] = 0;
        cluster.supplyCaps[YU] = 0;
        cluster.borrowCaps[USDC] = 0;
        cluster.borrowCaps[USDT] = 0;
        cluster.borrowCaps[YU] = 0;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                          0         1         2         3         4
            //                          USDC      USDT      YU        PT_YU_04SEP2025 PT_YU_04DEC2025
            /* 0  USDC              */ [LTV_ZERO, LTV_HIGH, LTV__LOW, LTV_ZERO, LTV_ZERO],
            /* 1  USDT              */ [LTV_HIGH, LTV_ZERO, LTV__LOW, LTV_ZERO, LTV_ZERO],
            /* 2  YU                */ [LTV__LOW, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 3  PT_YU_04SEP2025   */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO, LTV_ZERO],
            /* 4  PT_YU_04DEC2025   */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1         2         3         4
        //                     USDC      USDT      YU        PT_YU_04SEP2025 PT_YU_04DEC2025
        /* 0  Prime USDC   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO],
        /* 1  Prime USDT   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO]
        ];
    }
}
