// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

/// @dev NOTE: Deploy on Base
/// @dev NOTE: Deploy USD IRM on Base
contract Cluster is ManageCluster {
    address internal constant yoUSD = 0x0000000f2eB9f69274678c76222B35eEc7588a65;
    address internal constant PT_yoUSD_26MAR2026 = 0x0177055f7429D3bd6B19f2dd591127DB871A510e;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/yoUSD.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, yoUSD, PT_yoUSD_26MAR2026];
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
        cluster.oracleProviders[USDC ] = "0x7931F7B211000CA3700d538D6BB058Ca402b5805";
        cluster.oracleProviders[yoUSD] = "ExternalVault|";
        cluster.oracleProviders[PT_yoUSD_26MAR2026] = "0xf4AbaE2F067820465E24e9d5772073f5dE633a9b";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            cluster.irms[USDC] = IRM_ADAPTIVE_USD;
            cluster.irms[yoUSD] = IRM_ADAPTIVE_USD_YB;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                 0         1         2
            //                 USDC      yoUSD     PT_yoUSD_26MAR2026
            /* 0  USDC     */ [LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 1  yoUSD    */ [LTV__LOW, LTV_ZERO, LTV_ZERO],
            /* 2  PT_yoUSD */ [LTV__LOW, LTV_HIGH, LTV_ZERO]
        ];
    }
}
