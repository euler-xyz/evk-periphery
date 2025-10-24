// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant mAPOLLO    = 0x7CF9DEC92ca9FD46f8d86e7798B72624Bc116C05;
    address internal constant PT_mAPOLLO = 0x8CfEd6A728017A8641a213Bd9E2Ea6183dE275E8;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/mAPOLLO.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, mAPOLLO, PT_mAPOLLO];
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
        cluster.oracleProviders[USDC    ] = "0xD35657aE033A86FFa8fc6Bc767C5eb57C7c3D4B8";
        cluster.oracleProviders[USDT    ] = "0x575Ffc02361368A2708c00bC7e299d1cD1c89f8A";
        cluster.oracleProviders[mAPOLLO   ] = "0x1ff4967c34CA2C83f6275A5E4De8f4B7a2b35Fb9";
        cluster.oracleProviders[PT_mAPOLLO] = "0x067eF4a2d9297879B81851fFf8DE34917F5e108C";

        // mAPOLLO to usd oracle by Midas 0x1ff4967c34CA2C83f6275A5E4De8f4B7a2b35Fb9
        // PT mAPOLLO to usd 0x067eF4a2d9297879B81851fFf8DE34917F5e108C

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=2.7% APY  Max=40.00% APY
            //cluster.kinkIRMParams[WETH] = [uint256(0), uint256(218407859), uint256(22859618857), uint256(3865470566)];

            cluster.irms[USDC ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDT ] = IRM_ADAPTIVE_USD;
            cluster.irms[mAPOLLO] = IRM_ADAPTIVE_USD_YB;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //               0          1         2         3         
            //               USDC       USDT      mAPOLLO   PT_mAPOLLO
            /* 0  USDC    */ [LTV_ZERO, LTV_HIGH, LTV_ZERO, LTV_ZERO],
            /* 1  USDT    */ [LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 2  mAPOLLO   */ [LTV__LOW, LTV__LOW, LTV_ZERO, LTV_ZERO],
            /* 3  PT_mAPOLLO*/ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1         2         3        
        //                     USDC      USDT      mAPOLLO   PT_mAPOLLO
        /* 0  Prime USDC   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO],
        /* 1  Prime USDT   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO]
        ];
    }
}
