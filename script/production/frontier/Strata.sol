// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant USDe     = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address internal constant pUSDe    = 0xA62B204099277762d1669d283732dCc1B3AA96CE;
    address internal constant PT_pUSDe = 0xF3f491e5608f8B8a6Fd9E9d66a4a4036d7FD282C;
    address internal constant srUSDe   = 0x3d7d6fdf07EE548B939A80edbc9B2256d0cdc003;
    address internal constant PT_srUSDe = 0x1Fb3C5c35D95F48e48FFC8e36bCCe5CB5f29F57c;
    address internal constant jrUSDe    = 0xC58D044404d8B14e953C115E67823784dEA53d8F;
    address internal constant PT_jrUSDe = 0x53F3373F0D811902405f91eB0d5cc3957887220D;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/Strata.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, USDe, pUSDe, PT_pUSDe, srUSDe, PT_srUSDe, jrUSDe, PT_jrUSDe];
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
        cluster.oracleProviders[USDe    ] = "0x95dF7A30aF54cc05d1CFB1E9d7655f12269b8439";
        cluster.oracleProviders[pUSDe   ] = "ExternalVault|";
        cluster.oracleProviders[PT_pUSDe] = "0xD7AD788Fee2a7f7CADA6e82860D8DAed9eF21895";
        cluster.oracleProviders[srUSDe  ] = "ExternalVault|";
        cluster.oracleProviders[PT_srUSDe] = "0xBa197171A57Db7Da18bf7B0C86A586BE5196D539";
        cluster.oracleProviders[jrUSDe  ] = "ExternalVault|";
        cluster.oracleProviders[PT_jrUSDe] = "0x3cf1D4ffafe4d01C71315412F221F9ED7402662C";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=2.7% APY  Max=40.00% APY
            //cluster.kinkIRMParams[WETH] = [uint256(0), uint256(218407859), uint256(22859618857), uint256(3865470566)];

            cluster.irms[USDC  ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDT  ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDe  ] = IRM_ADAPTIVE_USD;
            cluster.irms[pUSDe ] = IRM_ADAPTIVE_USD_YB;
            cluster.irms[srUSDe ] = IRM_ADAPTIVE_USD_YB;
        }

        cluster.rampDuration = 30 days;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //               0          1         2         3         4         5         6         7         8
            //               USDC       USDT      USDe      pUSDe     PT_pUSDe  srUSDe    PT_srUSDe jrUSDe    PT_jrUSDe
            /* 0  USDC    */ [LTV_ZERO, LTV_HIGH, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 1  USDT    */ [LTV_HIGH, LTV_ZERO, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 2  USDe    */ [LTV__LOW, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 3  pUSDe   */ [LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 4  PT_pUSDe*/ [LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 5  srUSDe  */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 6  PT_srUSDe*/[LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 7  jrUSDe  */ [LTV__LOW, LTV__LOW, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 8  PT_jrUSDe*/[LTV__LOW, LTV__LOW, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1         2         3         4         5         6         7         8
        //                     USDC      USDT      USDe      pUSDe     PT_pUSDe  srUSDe    PT_srUSDe jrUSDe    PT_jrUSDe
        /* 0  Prime USDC   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
        /* 1  Prime USDT   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO]
        ];
    }
}
