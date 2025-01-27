// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";
import {ClusterDump} from "../../../utils/ClusterDump.s.sol";
import "evk/EVault/shared/Constants.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/mainnet/clusters/UsualCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            USD0PlusPlus,
            USD0
        ];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = getDeployer();
        cluster.vaultsGovernor = getDeployer();

        // define whether the vaults are upgradable or not
        cluster.vaultUpgradable = [
            false,
            false
        ];

        // define unit of account here
        cluster.unitOfAccount = USD;

        //cluster.interestFeeOverride[USD0] = 0.04e4; // TODO

        // define liquidation cool off time here. if needed to be defined per asset, populate the liquidationCoolOffTimeOverride mapping
        cluster.liquidationCoolOffTimeOverride[USD0] = 1;

        // define hook target and hooked ops here. if needed to be defined per asset, populate the hookTargetOverride and hookedOpsOverride mappings
        cluster.hookTargetOverride[USD0] = address(0); // TODO
        cluster.hookedOpsOverride[USD0] = OP_DEPOSIT | OP_MINT | OP_SKIM | OP_LIQUIDATE | OP_VAULT_STATUS_CHECK;

        // define config flags here. if needed to be defined per asset, populate the configFlagsOverride mapping
        cluster.configFlagsOverride[USD0] = CFG_DONT_SOCIALIZE_DEBT;

        // define oracle providers here. 
        cluster.oracleProviders[USD0PlusPlus] = "0x16a8760feB814AfC9e3748d09A46f602C8Ade027";
        cluster.oracleProviders[USD0        ] = "0x83e0698654dF4bC9F888c635ebE1382F0E4F7a61";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[USD0PlusPlus] = type(uint256).max;
        cluster.supplyCaps[USD0        ] = type(uint256).max;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[USD0PlusPlus] = type(uint256).max;
        cluster.borrowCaps[USD0        ] = type(uint256).max;

        // define IRM classes here and assign them to the assets
        {
            // Base=5% APY,  Kink(100%)=5% APY  Max=5% APY
            uint256[4] memory irm_fixed_rate = [uint256(1546098755264741952), uint256(0), uint256(0), type(uint32).max];

            cluster.kinkIRMParams[USD0] = irm_fixed_rate;
        }
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                        0                1     
        //                        USD0PlusPlus     USD0  
        /* 0  USUSD0PlusPlus */ [uint16(0.00e4), 1e4 - 1],
        /* 1  USD0           */ [uint16(0.00e4), 0.00e4]
        ];

        cluster.borrowLTVsOverride = [
        //                        0                1     
        //                        USD0PlusPlus     USD0  
        /* 0  USUSD0PlusPlus */ [uint16(0.00e4), 0.83e4],
        /* 1  USD0           */ [uint16(0.00e4), 0.00e4]
        ];
    }

    function postOperations() internal override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }

        ClusterDump dumper = new ClusterDump();
        dumper.dumpCluster(cluster.vaults, cluster.externalVaults);
    }
}
