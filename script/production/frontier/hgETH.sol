// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

/// @dev NOTE: Deploy PT-hgETH_26JUN2026 oracle
/// @dev NOTE: Deploy ETH IRM
contract Cluster is ManageCluster {
    address internal constant hgETH = 0xc824A08dB624942c5E5F330d56530cD1598859fD;
    address internal constant rsETH = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
    address internal constant PT_hgETH_26JUN2026 = 0x5b1578E2604B91bd7b24F86F0E5EF6C024bB3a14;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/hgETH.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [WETH, hgETH, PT_hgETH_26JUN2026];
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
        cluster.oracleProviders[hgETH] = "ExternalVault|0x013F30a593718D962c0CeeDe0a66f5f9EF5451b5";
        cluster.oracleProviders[PT_hgETH_26JUN2026] = "0x0a521133c4f6505dd730be3296cb48e4d8a776f3";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            cluster.irms[WETH ] = IRM_ADAPTIVE_ETH;
            cluster.irms[hgETH] = IRM_ADAPTIVE_ETH;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                          0         1
            //                          WETH      hgETH      PT_hgETH_26JUN2026
            /* 0  WETH   */            [LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 1  hgETH  */            [LTV__LOW, LTV_ZERO, LTV_ZERO],
            /* 2  PT_hgETH_26JUN2026*/ [LTV__LOW, LTV_HIGH, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1         2
        //                     WETH      hgETH     PT_hgETH_26JUN2026
        /* 0  Prime WETH   */ [LTV_HIGH, LTV_ZERO, LTV_ZERO]
        ];
    }
}
