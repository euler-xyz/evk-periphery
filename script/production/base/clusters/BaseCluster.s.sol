// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../../utils/PerspectiveCheck.s.sol";

contract Cluster is ManageCluster {
    function configureCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/base/clusters/BaseCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [WETH, wstETH, cbETH, WEETH, USDC, EURC, cbBTC, LBTC];

        // define the governors here
        cluster.oracleRoutersGovernor = GOVERNOR_ACCESS_CONTROL;
        cluster.vaultsGovernor = GOVERNOR_ACCESS_CONTROL;

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
        cluster.oracleProviders[WETH  ] = "ChainlinkOracle";
        cluster.oracleProviders[wstETH] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[cbETH ] = "ChainlinkOracle";
        cluster.oracleProviders[WEETH ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[USDC  ] = "ChainlinkOracle";
        cluster.oracleProviders[EURC  ] = "ChainlinkOracle";
        cluster.oracleProviders[cbBTC ] = "CrossAdapter=ChronicleOracle+ChronicleOracle";
        cluster.oracleProviders[LBTC  ] = "CrossAdapter=RedstoneClassicOracle+ChainlinkOracle";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[WETH  ] = type(uint256).max;
        cluster.supplyCaps[wstETH] = type(uint256).max;
        cluster.supplyCaps[cbETH ] = type(uint256).max;
        cluster.supplyCaps[WEETH ] = type(uint256).max;
        cluster.supplyCaps[USDC  ] = type(uint256).max;
        cluster.supplyCaps[EURC  ] = type(uint256).max;
        cluster.supplyCaps[cbBTC ] = type(uint256).max;
        cluster.supplyCaps[LBTC  ] = type(uint256).max;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[WETH  ] = type(uint256).max;
        cluster.borrowCaps[wstETH] = type(uint256).max;
        cluster.borrowCaps[cbETH ] = type(uint256).max;
        cluster.borrowCaps[WEETH ] = type(uint256).max;
        cluster.borrowCaps[USDC  ] = type(uint256).max;
        cluster.borrowCaps[EURC  ] = type(uint256).max;
        cluster.borrowCaps[cbBTC ] = type(uint256).max;
        cluster.borrowCaps[LBTC  ] = type(uint256).max;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(50%)=20% APY  Max=100% APY
            uint256[4] memory irmDummy = [uint256(0), uint256(2690376766), uint256(7537854659), uint256(2147483648)];

            cluster.kinkIRMParams[WETH  ] = irmDummy;
            cluster.kinkIRMParams[wstETH] = irmDummy;
            cluster.kinkIRMParams[cbETH ] = irmDummy;
            cluster.kinkIRMParams[WEETH ] = irmDummy;
            cluster.kinkIRMParams[USDC  ] = irmDummy;
            cluster.kinkIRMParams[EURC  ] = irmDummy;
            cluster.kinkIRMParams[cbBTC ] = irmDummy;
            cluster.kinkIRMParams[LBTC  ] = irmDummy;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 7 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0       1       2       3       4       5       6       7
        //                WETH    wstETH  cbETH   WEETH   USDC    EURC    cbBTC   LBTC
        /* 0  WETH    */ [0.00e4, 0.90e4, 0.88e4, 0.00e4, 0.85e4, 0.82e4, 0.83e4, 0.83e4],
        /* 1  wstETH  */ [0.92e4, 0.00e4, 0.90e4, 0.88e4, 0.83e4, 0.80e4, 0.81e4, 0.81e4],
        /* 2  cbETH   */ [0.93e4, 0.92e4, 0.00e4, 0.89e4, 0.84e4, 0.81e4, 0.82e4, 0.82e4],
        /* 3  WEETH   */ [0.90e4, 0.89e4, 0.87e4, 0.00e4, 0.81e4, 0.78e4, 0.79e4, 0.79e4],
        /* 4  USDC    */ [0.85e4, 0.82e4, 0.81e4, 0.79e4, 0.00e4, 0.83e4, 0.84e4, 0.84e4],
        /* 5  EURC    */ [0.82e4, 0.79e4, 0.78e4, 0.76e4, 0.82e4, 0.00e4, 0.80e4, 0.80e4],
        /* 6  cbBTC   */ [0.85e4, 0.82e4, 0.81e4, 0.79e4, 0.83e4, 0.80e4, 0.00e4, 0.87e4],
        /* 7  LBTC    */ [0.85e4, 0.82e4, 0.81e4, 0.79e4, 0.83e4, 0.80e4, 0.89e4, 0.00e4]
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
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i]);

            PerspectiveVerifier.verifyPerspective(
                peripheryAddresses.eulerUngovernedNzxPerspective,
                cluster.vaults[i],
                PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | PerspectiveVerifier.E__GOVERNOR,
                PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_SEPARATION
                    | PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_BORROW
                    | PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_LIQUIDATION
                    | PerspectiveVerifier.E__LTV_COLLATERAL_RAMPING
            );
        }
    }
}
