// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant EUL = 0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/EULSwap.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [EUL, USDC];
    }

    function configureCluster() internal override {        
        super.configureCluster();

        setNoStubOracle(false);

        // define unit of account here
        cluster.unitOfAccount = EUL;

        // define interest fee here. if needed to be defined per asset, populate the interestFeeOverride mapping
        cluster.interestFeeOverride[EUL] = 0;

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
        cluster.oracleProviders[EUL] = "";
        cluster.oracleProviders[USDC] = "0x336D821459db40bA9bfb8a1a89457D689AfbA6E8";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=6.0% APY  Max=25.00% APY
            cluster.kinkIRMParams[EUL] = [uint256(0), uint256(477682641), uint256(12164631494), uint256(3865470566)];
        }

        cluster.supplyCaps[USDC] = 2_000_000;
        cluster.spreadLTVOverride[1][0] = 0.10e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //               0               1
            //               EUL             USDC
            /* 0  EUL    */ [LTV_ZERO,       LTV_ZERO],
            /* 1  USDC   */ [uint16(0.60e4), LTV_ZERO]
        ];

        cluster.externalLTVs = [
        //             0                1
        //             EUL              USDC
        /* 0  EUL   */ [uint16(0.95e4), LTV_ZERO]
        ];
    }
}
