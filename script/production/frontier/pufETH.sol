// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

/// @dev NOTE: Deploy ETH IRM
contract Cluster is ManageCluster {
    address internal constant pufETH = 0xD9A442856C234a39a81a089C06451EBAa4306a72;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/pufETH.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [WETH, pufETH];
    }

    function configureCluster() internal override {
        super.configureCluster();

        // define unit of account here
        cluster.unitOfAccount = WETH;

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
        cluster.oracleProviders[pufETH] = "0x49e4d0aEa709F69EcB25b1F7D9Bd44c4d9c5c455";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            cluster.irms[WETH   ] = IRM_ADAPTIVE_ETH;
            cluster.irms[pufETH ] = IRM_ADAPTIVE_ETH;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //               0         1
            //               WETH      pufETH
            /* 0  WETH   */ [LTV_ZERO, LTV__LOW],
            /* 1  pufETH */ [LTV__LOW, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1
        //                     WETH      pufETH
        /* 0  Prime WETH   */ [LTV_HIGH, LTV_ZERO]
        ];
    }
}
