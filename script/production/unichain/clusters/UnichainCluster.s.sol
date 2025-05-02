// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/unichain/clusters/UnichainCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            WETH,
            wstETH,
            weETH,
            ezETH,
            rsETH,
            USDC,
            USDT0,
            WBTC,
            UNI
        ];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = getDeployer(); //governorAddresses.accessControlEmergencyGovernor;

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
        cluster.oracleProviders[WETH  ] = "";
        cluster.oracleProviders[wstETH] = "";
        cluster.oracleProviders[weETH ] = "";
        cluster.oracleProviders[ezETH ] = "";
        cluster.oracleProviders[rsETH ] = "";
        cluster.oracleProviders[USDC  ] = "";
        cluster.oracleProviders[USDT0 ] = "";
        cluster.oracleProviders[WBTC  ] = "";
        cluster.oracleProviders[UNI   ] = "";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[WETH  ] = type(uint256).max;
        cluster.supplyCaps[wstETH] = type(uint256).max;
        cluster.supplyCaps[weETH ] = type(uint256).max;
        cluster.supplyCaps[ezETH ] = type(uint256).max;
        cluster.supplyCaps[rsETH ] = type(uint256).max;
        cluster.supplyCaps[USDC  ] = type(uint256).max;
        cluster.supplyCaps[USDT0 ] = type(uint256).max;
        cluster.supplyCaps[WBTC  ] = type(uint256).max;
        cluster.supplyCaps[UNI   ] = type(uint256).max;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[WETH  ] = type(uint256).max;
        cluster.borrowCaps[wstETH] = type(uint256).max;
        cluster.borrowCaps[weETH ] = type(uint256).max;
        cluster.borrowCaps[ezETH ] = type(uint256).max;
        cluster.borrowCaps[rsETH ] = type(uint256).max;
        cluster.borrowCaps[USDC  ] = type(uint256).max;
        cluster.borrowCaps[USDT0 ] = type(uint256).max;
        cluster.borrowCaps[WBTC  ] = type(uint256).max;
        cluster.borrowCaps[UNI   ] = type(uint256).max;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(90%)=2.40% APY  Max=80.00% APY
            uint256[4] memory irm = [uint256(0), uint256(194425692),  uint256(41617711740), uint256(3865470566)];

            //cluster.kinkIRMParams[WETH  ] = irm;
            //cluster.kinkIRMParams[wstETH] = irm;
            //cluster.kinkIRMParams[weETH ] = irm;
            //cluster.kinkIRMParams[ezETH ] = irm;
            //cluster.kinkIRMParams[rsETH ] = irm;
            //cluster.kinkIRMParams[USDC  ] = irm;
            //cluster.kinkIRMParams[USDT0 ] = irm;
            //cluster.kinkIRMParams[WBTC  ] = irm;
            //cluster.kinkIRMParams[UNI   ] = irm;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0               1       2       3       4       5       6       7       8
        //                WETH            wstETH  weETH   ezETH   rsETH   USDC    USDT0   WBTC    UNI
        /* 0  WETH    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  wstETH  */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  weETH   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 3  ezETH   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 4  rsETH   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 5  USDC    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 6  USDT0   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 7  WBTC    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 8  UNI     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
    }

    function postOperations() internal view override {
        //for (uint256 i = 0; i < cluster.vaults.length; ++i) {
        //    OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        //}
    }
}
