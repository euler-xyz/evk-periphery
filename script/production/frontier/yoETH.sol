// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant override WETH  = 0x4200000000000000000000000000000000000006;
    address internal constant yoETH = 0x3A43AEC53490CB9Fa922847385D82fe25d0E9De7;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/yoETH.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [WETH, yoETH];
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
        // External Vaults Registry, the string should be preceeded by "ExternalVault|" prefix. this is in order to
        // resolve the asset (vault) in the oracle router.
        // in case the adapter is not present in the Adapter Registry, the adapter address can be passed instead in form
        // of a string.
        cluster.oracleProviders[yoETH  ] = "0x87044100bB65aeee4661160d470B3f79E79E506E";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=2.7% APY  Max=40.00% APY
            //cluster.kinkIRMParams[WETH] = [uint256(0), uint256(218407859), uint256(22859618857), uint256(3865470566)];

            cluster.irms[WETH  ] = IRM_ADAPTIVE_USD;
            cluster.irms[YU  ] = IRM_ADAPTIVE_USD;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                          0         1         2
            //                          USDC      YU        PT_YU_04SEP2025
            /* 0  USDC              */ [LTV_ZERO, LTV__LOW, LTV_ZERO],
            /* 1  YU                */ [LTV__LOW, LTV_ZERO, LTV_ZERO],
            /* 2  PT_YU_04SEP2025   */ [LTV__LOW, LTV_HIGH, LTV_ZERO]
        ];
    }
}
