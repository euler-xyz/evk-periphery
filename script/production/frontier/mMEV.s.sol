// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant mMEV    = 0x030b69280892c888670EDCDCD8B69Fd8026A0BF3;
    address internal constant PT_mMEV_old = 0x1132065009850C72E27B7950C0f9285d1D103589;
    address internal constant PT_mMEV = 0x61da65F0534C6A4F4c9757f2979A923c08d6D2aa;
    address internal constant PT_mMEV_new = 0x2c543181871718C05bB191B8CE8F2A6538D72762;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/mMEV.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, mMEV, PT_mMEV_old, PT_mMEV, PT_mMEV_new];
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
        cluster.oracleProviders[USDC   ] = "0xD35657aE033A86FFa8fc6Bc767C5eb57C7c3D4B8";
        cluster.oracleProviders[USDT   ] = "0x575Ffc02361368A2708c00bC7e299d1cD1c89f8A";
        cluster.oracleProviders[mMEV   ] = "0xf5c2dfd1740d18ad7cf23fba76cc11d877802937";
        cluster.oracleProviders[PT_mMEV_old] = "0x8c6ba8c189fc9f88fc72533ea60b9c4134a650f0";
        cluster.oracleProviders[PT_mMEV] = "0x83910e00f7662146e01f61d555a0577187e9bc11";
        cluster.oracleProviders[PT_mMEV_new] = "0x987670379e4bDdf4A8ccBA335c4640c80f31A818";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=2.7% APY  Max=40.00% APY
            //cluster.kinkIRMParams[WETH] = [uint256(0), uint256(218407859), uint256(22859618857), uint256(3865470566)];

            cluster.irms[USDC] = IRM_ADAPTIVE_USD;
            cluster.irms[USDT] = IRM_ADAPTIVE_USD;
            cluster.irms[mMEV] = IRM_ADAPTIVE_USD_YB;
        }

        cluster.rampDuration = 30 days;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //               0          1         2         3         4         5
            //               USDC       USDT      mMEV      PT_mMEV   PT_mMEV   PT_mMEV
            /* 0  USDC    */ [LTV_ZERO, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 1  USDT    */ [LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 2  mMEV    */ [LTV__LOW, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 3  PT_mMEV */ [LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 4  PT_mMEV */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 5  PT_mMEV */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1         2         3         4         5
        //                     USDC      USDT      mMEV      PT_mMEV   PT_mMEV   PT_mMEV
        /* 0  Prime USDC   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
        /* 1  Prime USDT   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO]
        ];
    }
}
