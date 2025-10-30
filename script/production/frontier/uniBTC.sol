// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

/// @dev NOTE: Deploy PT-uniBTC_18DEC2025 oracle
contract Cluster is ManageCluster {
    address internal constant uniBTC = 0x004E9C3EF86bc1ca1f0bB5C7662861Ee93350568;
    address internal constant PT_uniBTC_18DEC2025 = 0xa42C63686F45C124f2034152B4BB0CC63CE3Ff52;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/uniBTC.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [WBTC, uniBTC, PT_uniBTC_18DEC2025];
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
        cluster.oracleProviders[uniBTC] = "0xD802AD35342C39765B74205483c8f8558Fd3c311";
        cluster.oracleProviders[PT_uniBTC_18DEC2025] = "0xF51f47ed3f7412EB10Cd2C0B6a7D190524D43bDc";

        // unibtc to btc 0xeB2de8d8D64582A27CfA68E5A87a0cfDf7c1Ea1F
        // pt to unibtc 0xD86BbBaC0C5aAb992fA2cA4Fb49156B3AA19E4cD
        // btc to usd 0x0484Df76f561443d93548D86740b5C4A826e5A33
        // pt to wbtc 0xF51f47ed3f7412EB10Cd2C0B6a7D190524D43bDc
        // uni to wbtc 0xD802AD35342C39765B74205483c8f8558Fd3c311

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            cluster.irms[WBTC ] = IRM_ADAPTIVE_BTC;
            cluster.irms[uniBTC] = IRM_ADAPTIVE_BTC;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                          0         1
            //                          WBTC      uniBTC      PT_uniBTC_18DEC2025
            /* 0  WBTC   */            [LTV_ZERO, LTV__LOW, LTV_ZERO],
            /* 1  uniBTC  */            [LTV__LOW, LTV_ZERO, LTV_ZERO],
            /* 2  PT_uniBTC_18DEC2025*/ [LTV__LOW, LTV_HIGH, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        cluster.externalLTVs = [
        //                     0         1         2
        //                     WBTC      uniBTC     PT_uniBTC_18DEC2025
        /* 0  Prime WBTC   */ [LTV_HIGH, LTV_ZERO, LTV_ZERO]
        ];
    }
}
