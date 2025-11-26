// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "../../ManageCluster.s.sol";
import {OracleVerifier} from "../../../../../utils/SanityCheckOracle.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/monad/clusters/2p/AUSD/FBTC-AUSD.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            FBTC,
            AUSD
        ];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = governorAddresses.accessControlEmergencyGovernor;

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
        cluster.oracleProviders[FBTC] = "";
        cluster.oracleProviders[AUSD] = "0xcd82e60229DC4ea93AfEaa83D296Bd5F9E506D97";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[FBTC] = 150;
        cluster.supplyCaps[AUSD] = 12_000_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[FBTC] = 120;
        cluster.borrowCaps[AUSD] = 10_800_000;

        // define IRM classes here and assign them to the assets
        {
            // Base=1.00% APY,  Kink(80.00%)=3.00% APY  Max=25.00% APY
            uint256[4] memory irmWBTC = [uint256(315313405426480960), uint256(180841814),  uint256(7141447258), uint256(3435973836)];
            // Base=0.00% APY,  Kink(90.00%)=5.5% APY  Max=18.00% APY
            uint256[4] memory irmUSDC = [uint256(0), uint256(438921808),  uint256(8261539992), uint256(3865470566)];

            cluster.kinkIRMParams[FBTC] = irmWBTC;
            cluster.kinkIRMParams[AUSD] = irmUSDC;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 0 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.01e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0               1    
        //                FBTC            AUSD
        /* 0  FBTC    */ [uint16(0.00e4), 0.80e4],
        /* 1  AUSD    */ [uint16(0.80e4), 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
        cluster.externalLTVs = [
        //                     0               1    
        //                     FBTC            AUSD
        /* 0  Escrow FBTC  */ [uint16(0.97e4), 0.80e4],
        /* 1  Escrow AUSD  */ [uint16(0.80e4), 0.97e4]
        ];
    }

    function postOperations() internal view override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }
    }
}
