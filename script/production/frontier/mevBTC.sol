// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

/// @dev NOTE: Deploy
/// @dev NOTE: Deploy
contract Cluster is ManageCluster {
    address internal constant mevBTC = 0xb64C014307622eB15046C66fF71D04258F5963DC;
    address internal constant PT_mevBTC = 0x41d49208a7E61EEd06b3504262C54E7C5fF04bFc;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/mevBTC.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [WBTC, mevBTC, PT_mevBTC];
    }

    function configureCluster() internal override {
        super.configureCluster();

        // define unit of account here
        cluster.unitOfAccount = WBTC;

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

        cluster.oracleProviders[mevBTC] = "0x7cb33Db0f992dD388a9A3351004D89F4F5996fAA";
        cluster.oracleProviders[PT_mevBTC] = "0x33Fcb37A54fBB3717B0D87CF3B9Fc6b57d7eF847";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            cluster.irms[WBTC ] = IRM_ADAPTIVE_BTC;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                0          1         2
            //                WBTC       mevBTC    PT_mevBTC
            /* 0  WBTC     */ [LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 1  mevBTC   */ [LTV__LOW, LTV_ZERO, LTV_ZERO],
            /* 2  PT_mevBTC*/ [LTV__LOW, LTV_HIGH, LTV_ZERO]
        ];

         cluster.externalLTVs = [
        //                     0         1         2
        //                     WBTC      mevBTC    PT_mevBTC
        /* 0  Prime WBTC   */ [LTV_HIGH, LTV_ZERO, LTV_ZERO]
        ];

    }
}
