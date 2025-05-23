// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant mEDGE    = 0xbB51E2a15A9158EBE2b0Ceb8678511e063AB7a55;
    address internal constant PT_mEDGE = 0x7f01d0FCe9BC646389483384C41B4d71c7139f11;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/mEDGE.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, mEDGE, PT_mEDGE];
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
        cluster.oracleProviders[mEDGE   ] = "0xc8228b83f1d97a431a48bd9bc3e971c8b418d889";
        cluster.oracleProviders[PT_mEDGE] = "0xe8192efbf40faa247f1c4fb792d986057fc69a15";

        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=2.7% APY  Max=40.00% APY
            //cluster.kinkIRMParams[WETH] = [uint256(0), uint256(218407859), uint256(22859618857), uint256(3865470566)];

            cluster.irms[USDC ] = IRM_ADAPTIVE_USD;
            cluster.irms[mEDGE] = IRM_ADAPTIVE_USD_YB;
        }

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //               0          1         2
            //               USDC       mEDGE     PT_mEDGE
            /* 0  USDC    */ [LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 1  mEDGE   */ [LTV__LOW, LTV_ZERO, LTV_ZERO],
            /* 2  PT_mEDGE*/ [LTV__LOW, LTV_HIGH, LTV_ZERO]
        ];
    }
}
