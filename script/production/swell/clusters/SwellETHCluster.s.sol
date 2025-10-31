// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../../utils/PerspectiveCheck.s.sol";
import {ClusterDump} from "../../../utils/ClusterDump.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/swell/clusters/SwellETHCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            WETH,
            wstETH,
            weETH,
            ezETH,
            rsETH,
            swETH,
            rswETH,
            pzETH
        ];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = governorAddresses.accessControlEmergencyGovernor;
        cluster.vaultsGovernor = governorAddresses.accessControlEmergencyGovernor;

        // define unit of account here
        cluster.unitOfAccount = WETH;

        // define fee receiver here and interest fee here. if needed to be defined per asset, populate the feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = address(0);
        cluster.interestFee = 0.1e4;

        //cluster.interestFeeOverride[WETH]  = 0;

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
        cluster.oracleProviders[WETH  ] = "RedstoneClassicOracle";
        cluster.oracleProviders[wstETH] = "RedstoneClassicOracle";
        cluster.oracleProviders[weETH ] = "RedstoneClassicOracle";
        cluster.oracleProviders[ezETH ] = "RedstoneClassicOracle";
        cluster.oracleProviders[rsETH ] = "RedstoneClassicOracle";
        cluster.oracleProviders[swETH ] = "RedstoneClassicOracle";
        cluster.oracleProviders[rswETH] = "RedstoneClassicOracle";
        cluster.oracleProviders[pzETH ] = "RedstoneClassicOracle";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[WETH  ] = 7_000;
        cluster.supplyCaps[wstETH] = 5_000;
        cluster.supplyCaps[weETH ] = 5_000;
        cluster.supplyCaps[ezETH ] = 5_000;
        cluster.supplyCaps[rsETH ] = 2_500;
        cluster.supplyCaps[swETH ] = 2_500;
        cluster.supplyCaps[rswETH] = 2_500;
        cluster.supplyCaps[pzETH ] = 2_500;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[WETH  ] = 6_300;
        cluster.borrowCaps[wstETH] = 2_000;
        cluster.borrowCaps[weETH ] = 1_250;
        cluster.borrowCaps[ezETH ] = 1_250;
        cluster.borrowCaps[rsETH ] = 625;
        cluster.borrowCaps[swETH ] = 625;
        cluster.borrowCaps[rswETH] = 625;
        cluster.borrowCaps[pzETH ] = 625;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(90%)=2.4% APY  Max=50.0% APY
            uint256[4] memory irmETH     = [uint256(0), uint256(194425692),  uint256(28165827922), uint256(3865470566)];

            // Base=0% APY,  Kink(40%)=4.60% APY  Max=145.96% APY
            uint256[4] memory irmETH_LST = [uint256(0), uint256(829546015),  uint256(10514117840), uint256(1717986918)];

            // Base=0% APY,  Kink(25%)=4.60% APY  Max=848.77% APY
            uint256[4] memory irmETH_LRT = [uint256(0), uint256(1327273625), uint256(21691866441), uint256(1073741824)];

            cluster.kinkIRMParams[WETH  ] = irmETH;
            cluster.kinkIRMParams[wstETH] = irmETH_LST;
            cluster.kinkIRMParams[weETH ] = irmETH_LRT;
            cluster.kinkIRMParams[ezETH ] = irmETH_LRT;
            cluster.kinkIRMParams[rsETH ] = irmETH_LRT;
            cluster.kinkIRMParams[swETH ] = irmETH_LRT;
            cluster.kinkIRMParams[rswETH] = irmETH_LRT;
            cluster.kinkIRMParams[pzETH ] = irmETH_LRT;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0               1       2       3       4       5       6       7     
        //                WETH            wstETH  weETH   ezETH   rsETH   swETH   rswETH  pzETH 
        /* 0  WETH    */ [uint16(0.00e4), 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4],
        /* 1  wstETH  */ [uint16(0.93e4), 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4],
        /* 2  weETH   */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4],
        /* 3  ezETH   */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4],
        /* 4  rsETH   */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4],
        /* 5  swETH   */ [uint16(0.85e4), 0.85e4, 0.85e4, 0.85e4, 0.85e4, 0.00e4, 0.85e4, 0.85e4],
        /* 6  rswETH  */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4],
        /* 7  pzETH   */ [uint16(0.85e4), 0.85e4, 0.85e4, 0.85e4, 0.85e4, 0.85e4, 0.85e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
    }

    function postOperations() internal override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            perspectiveVerify(peripheryAddresses.governedPerspective, cluster.vaults[i]);
        }
        executeBatchPrank(Ownable(peripheryAddresses.governedPerspective).owner());

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);

            PerspectiveVerifier.verifyPerspective(
                peripheryAddresses.eulerUngovernedNzxPerspective,
                cluster.vaults[i],
                PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | PerspectiveVerifier.E__GOVERNOR,
                PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_SEPARATION
                    | PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_BORROW
                    | PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_LIQUIDATION
                    | PerspectiveVerifier.E__LTV_COLLATERAL_RAMPING
                    | PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_LENGTH,
                false
            );
        }

        ClusterDump dumper = new ClusterDump();
        dumper.dumpCluster(cluster.vaults, cluster.externalVaults);
    }
}
