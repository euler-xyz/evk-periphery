// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/plasma/clusters/M18Trevee.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            splUSD,
            plUSD,
            USDT0
        ];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = 0x7d07BFdd01422D7b655B333157eB551B9712dCd8;

        // define unit of account here
        cluster.unitOfAccount = USD;

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
        // External Vaults Registry, the string should be preceeded by "ExternalVault|" prefix. this is in order to resolve 
        // the asset (vault) in the oracle router.
        // in case the adapter is not present in the Adapter Registry, the adapter address can be passed instead in form of a string.
        cluster.oracleProviders[splUSD] = "0xb360587D4E998F5f740524CF2Bf703e51c06bfE3";
        cluster.oracleProviders[plUSD]  = "0x026DB6032232222c1cecAc29583f39Ff53cb62DB";
        cluster.oracleProviders[USDT0] = "0xE8947CFd3f04E686741F7Dd9023ec0C78588fd33";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[splUSD] = type(uint256).max;
        cluster.supplyCaps[plUSD ] = type(uint256).max;
        cluster.supplyCaps[USDT0] = type(uint256).max;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[splUSD] = type(uint256).max;
        cluster.borrowCaps[plUSD ] = type(uint256).max;
        cluster.borrowCaps[USDT0] = type(uint256).max;

        // define IRM classes here and assign them to the assets
        cluster.irms[plUSD ] = IRM_ADAPTIVE_USD;
        cluster.irms[USDT0] = IRM_ADAPTIVE_USD;

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        cluster.borrowLTVsOverride[0][1] = 0;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0         1         2       
        //                splUSD    plUSD     USDT0   
        /* 0  splUSD  */ [LTV_ZERO, LTV_HIGH, LTV__LOW],
        /* 1  plUSD   */ [LTV_ZERO, LTV_ZERO, LTV__LOW],
        /* 2  USDT0   */ [LTV_ZERO, LTV__LOW, LTV_ZERO]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
        cluster.externalLTVs = [
        //                     0         1         2
        //                     splUSD    plUSD     USDT0
        /* 0  Escrow USDT  */ [LTV_ZERO, LTV_ZERO, LTV_SELF]
        ];
    }

    function postOperations() internal view override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }
    }
}
