// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant thBILL  = 0xfDD22Ce6D1F66bc0Ec89b20BF16CcB6670F55A5a;
    address internal constant PT_tbBILL_27NOV2025 = 0x5a791652f3b140d357df072d355a98ab754877D1;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/thBILL.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, thBILL, PT_tbBILL_27NOV2025];
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
        cluster.oracleProviders[USDC            ] = "0x7b123D1850aAb204e7Cd426FC2259141338F771b";
        cluster.oracleProviders[USDT            ] = "0x880CF45D19Ad344953C5B6694B39f9B7BD2563c9";
        cluster.oracleProviders[thBILL              ] = "0x31b68Dd6974dA331Fea28BDEd6f4adF355900CC3";
        cluster.oracleProviders[PT_tbBILL_27NOV2025 ] = "0xF51f47ed3f7412EB10Cd2C0B6a7D190524D43bDc";

        // usdc to usd fixed 0x7b123D1850aAb204e7Cd426FC2259141338F771b
        // usdt to usd fixed 0x880CF45D19Ad344953C5B6694B39f9B7BD2563c9
        // thbill to usd fixed 0x9d8dF9dA1cFB1308311E295D41E88049088C3626
        // thbill to usd fundamental cross 0x31b68Dd6974dA331Fea28BDEd6f4adF355900CC3
        // pt thbill to usd 0xF51f47ed3f7412EB10Cd2C0B6a7D190524D43bDc 



        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=2.7% APY  Max=40.00% APY
            //cluster.kinkIRMParams[WETH] = [uint256(0), uint256(218407859), uint256(22859618857), uint256(3865470566)];

            cluster.irms[USDC  ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDT  ] = IRM_ADAPTIVE_USD;
            cluster.irms[thBILL  ] = IRM_ADAPTIVE_USD;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                          0         1         2         3         
            //                          USDC      USDT      thBILL    PT_tbBILL_27NOV2025
            /* 0  USDC              */ [LTV_ZERO, LTV_HIGH, LTV__LOW, LTV_ZERO],
            /* 1  USDT              */ [LTV_HIGH, LTV_ZERO, LTV__LOW, LTV_ZERO],
            /* 2  thBILL            */ [LTV__LOW, LTV__LOW, LTV_ZERO, LTV_ZERO],
            /* 3  PT_tbBILL_27NOV   */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO]
        ];

    }
}
