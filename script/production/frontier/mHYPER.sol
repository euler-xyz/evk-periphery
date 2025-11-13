// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant mHYPER    = 0x9b5528528656DBC094765E2abB79F293c21191B9;
    address internal constant PT_mHYPER = 0xE4d30cCF87Cb3E5E637b64A2EE21bD5d3901839A;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/mHYPER.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, mHYPER, PT_mHYPER];
    }

    function configureCluster() internal override {
        super.configureCluster();

        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = 0x75178137D3B4B9A0F771E0e149b00fB8167BA325;

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
        cluster.oracleProviders[mHYPER   ] = "0xA798b4aDcAd1C8D3c02662147AFB5d85Be938427";
        cluster.oracleProviders[PT_mHYPER] = "0x9F7f026111A6A34BDAf1D71D8626091Ed7d4328E";

        // mHYPER to usd oracle by Midas 0xA798b4aDcAd1C8D3c02662147AFB5d85Be938427
        // PT mHYPER to usd 0x9F7f026111A6A34BDAf1D71D8626091Ed7d4328E

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY,  Kink(90%)=10.00% APY  Max=30.00% APY
            uint256[4] memory irm = [uint256(0), uint256(781341783),  uint256(12325426837), uint256(3865470566)];

            cluster.kinkIRMParams[USDC] = irm;
            cluster.kinkIRMParams[USDT] = irm;
            cluster.kinkIRMParams[mHYPER] = irm;

            //cluster.irms[USDC ] = IRM_ADAPTIVE_USD;
            //cluster.irms[USDT ] = IRM_ADAPTIVE_USD;
            //cluster.irms[mHYPER] = IRM_ADAPTIVE_USD_YB;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //               0          1         2         3         
            //               USDC       USDT      mHYPER   PT_mHYPER
            /* 0  USDC    */ [LTV_ZERO, LTV_HIGH, LTV_ZERO, LTV_ZERO],
            /* 1  USDT    */ [LTV_HIGH, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 2  mHYPER   */ [LTV__LOW, LTV__LOW, LTV_ZERO, LTV_ZERO],
            /* 3  PT_mHYPER*/ [LTV__LOW, LTV__LOW, LTV_HIGH, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1         2         3        
        //                     USDC      USDT      mHYPER   PT_mHYPER
        /* 0  Prime USDC   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO],
        /* 1  Prime USDT   */ [LTV_HIGH, LTV_HIGH, LTV_ZERO, LTV_ZERO]
        ];

        cluster.supplyCaps[USDC] = 10_000;
        cluster.supplyCaps[USDT] = 10_000;
    }
}
