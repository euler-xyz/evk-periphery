// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant cUSD                = 0xcCcc62962d17b8914c62D74FfB843d73B2a3cccC;
    address internal constant stcUSD               = 0x88887bE419578051FF9F4eb6C858A951921D8888;
    address internal constant PT_stcUSD_29JAN2026 = 0xC3c7E5E277d31CD24a3Ac4cC9af3B6770F30eA33;
    address internal constant PT_cUSD_29JAN2026   = 0x545A490f9ab534AdF409A2E682bc4098f49952e3;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/Cap.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, cUSD, stcUSD, PT_stcUSD_29JAN2026, PT_cUSD_29JAN2026];
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
        cluster.oracleProviders[USDC                ] = "0xD35657aE033A86FFa8fc6Bc767C5eb57C7c3D4B8";
        cluster.oracleProviders[USDT                ] = "0x575Ffc02361368A2708c00bC7e299d1cD1c89f8A";
        cluster.oracleProviders[cUSD                ] = "0x31b68Dd6974dA331Fea28BDEd6f4adF355900CC3";
        cluster.oracleProviders[stcUSD               ] = "ExternalVault|0x31b68Dd6974dA331Fea28BDEd6f4adF355900CC3";
        cluster.oracleProviders[PT_stcUSD_29JAN2026 ] = "0x3b7448cc00dfb2b8A407F245f8a546C2F32670c3";
        cluster.oracleProviders[PT_cUSD_29JAN2026   ] = "0xde2c21dB4110263549960bD423F837241D86B2Cd";

        // cusd to usd fundamental 0x31b68Dd6974dA331Fea28BDEd6f4adF355900CC3
        // pt stcUSD to cUSD 0x982aCda809914277053f3be2fdC074B468af40a2
        // pt stcUSD to usd cross 0x3b7448cc00dfb2b8A407F245f8a546C2F32670c3
        // pt cUSD to cUSD 0xFBb43A0a68f52a60Cb9dF4A542c1020b2d0C3934
        // pt cUSD to usd cross 0xde2c21dB4110263549960bD423F837241D86B2Cd



        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=2.7% APY  Max=40.00% APY
            //cluster.kinkIRMParams[WETH] = [uint256(0), uint256(218407859), uint256(22859618857), uint256(3865470566)];

            cluster.irms[USDC  ] = IRM_ADAPTIVE_USD;
            cluster.irms[USDT  ] = IRM_ADAPTIVE_USD;
            cluster.irms[cUSD  ] = IRM_ADAPTIVE_USD;
            cluster.irms[stcUSD] = IRM_ADAPTIVE_USD_YB;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //               0          1         2         3         4         5
            //               USDC       USDT      cUSD      stcUSD     PT_stcUSD  PT_cUSD
            /* 0  USDC    */ [LTV_ZERO, LTV_HIGH, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 1  USDT    */ [LTV_HIGH, LTV_ZERO, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 2  cUSD    */ [LTV__LOW, LTV__LOW, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 3  stcUSD   */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 4  PT_stcUSD*/ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO],
            /* 5  PT_cUSD */ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1         2         3         4         5
        //                     USDC      USDT      cUSD      stcUSD     PT_stcUSD  PT_cUSD
        /* 0  Prime USDC   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
        /* 1  Prime USDT   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO]
        ];
    }
}
