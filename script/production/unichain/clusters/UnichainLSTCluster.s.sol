// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/unichain/clusters/UnichainLSTCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            WETH,
            wstETH,
            rsETH,
            ezETH
        ];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = governorAddresses.accessControlEmergencyGovernor;

        // define unit of account here
        cluster.unitOfAccount = WETH;

        // define fee receiver here and interest fee here. if needed to be defined per asset, populate the feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = address(0);
        cluster.interestFee = 0.1e4;

        // define max liquidation discount here. if needed to be defined per asset, populate the maxLiquidationDiscountOverride mapping
        cluster.maxLiquidationDiscount = 0.15e4;

        // define liquidation cool off time here. if needed to be defined per asset, populate the liquidationCoolOffTimeOverride mapping
        cluster.liquidationCoolOffTime = 1;

        // define hook target and hooked ops here. if needed to be defined per asset, populate the hookTargetOverride and hookedOpsOverride mappings
        cluster.hookTarget = address(0);
        cluster.hookedOps = 0;

        // define config flags here. if needed to be defined per asset, populate the configFlagsOverride mapping
        cluster.configFlags = 0;

        // define oracle providers here. 
        // adapter names can be found in the relevant adapter contract (as returned by the `name` function).
        // for cross adapters, use the following format: "CrossAdapter=<adapterName1>+<adapterName2>".
        // although Redstone Classic oracles reuse the ChainlinkOracle contract and returns "ChainlinkOracle" name, 
        // they should be referred to as "RedstoneClassicOracle".
        // in case the asset is an ERC4626 vault itself (i.e. sUSDS) and is recognized as a valid external vault as per 
        // External Vaults Registry, the string should be preceded by "ExternalVault|" prefix. this is in order to resolve 
        // the asset (vault) in the oracle router.
        // in case the adapter is not present in the Adapter Registry, the adapter address can be passed instead in form of a string.
        cluster.oracleProviders[wstETH] = "0xd0dab9edb2b1909802b03090efbf14743e7ff967";
        cluster.oracleProviders[rsETH ] = "0x0505c3f2b1c74ad84f4556a0b5a73386e6286d4e";
        cluster.oracleProviders[ezETH ] = "0x255bee201d2526bbf2753df6a6057f23431a3e1c";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[WETH  ] = 37_500;
        cluster.supplyCaps[wstETH] = 15_000;
        cluster.supplyCaps[rsETH ] = 7_500;
        cluster.supplyCaps[ezETH ] = 7_500;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[WETH  ] = 33_000;
        cluster.borrowCaps[wstETH] = 13_500;
        cluster.borrowCaps[rsETH ] = 6_750;
        cluster.borrowCaps[ezETH ] = 6_750;

        // define IRM classes here and assign them to the assets
        {
            cluster.irms[WETH  ] = 0x6E42d3bF21B81Fa560eA5A7eF580a0Ba1a179B1c;
            cluster.irms[wstETH] = 0x5C05c160391c03E4d0B8dE256d918B7d5901c2FE;
            cluster.irms[rsETH ] = 0x5C05c160391c03E4d0B8dE256d918B7d5901c2FE;
            cluster.irms[ezETH ] = 0x5C05c160391c03E4d0B8dE256d918B7d5901c2FE;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0               1       2       3   
        //                WETH            wstETH  rsETH   ezETH
        /* 0  WETH    */ [uint16(0.00e4), 0.95e4, 0.92e4, 0.92e4],
        /* 1  wstETH  */ [uint16(0.95e4), 0.00e4, 0.92e4, 0.92e4],
        /* 2  rsETH   */ [uint16(0.00e4), 0.92e4, 0.00e4, 0.91e4],
        /* 3  ezETH   */ [uint16(0.00e4), 0.92e4, 0.91e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
    }

    function postOperations() internal view override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }
    }
}
