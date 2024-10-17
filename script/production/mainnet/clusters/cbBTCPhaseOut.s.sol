// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "../ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../../utils/PerspectiveCheck.s.sol";
import {GovernedPerspective} from "../../../../src/Perspectives/deployed/GovernedPerspective.sol";

contract Cluster is ManageCluster {
    function configureCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/mainnet/clusters/cbBTC.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [cbBTC];

        // define the governors here
        cluster.forceZeroGovernors = true;
        cluster.oracleRoutersGovernor = address(0);
        cluster.vaultsGovernor = address(0);

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
        cluster.oracleProviders[WETH   ] = "ChainlinkOracle";
        cluster.oracleProviders[wstETH ] = "CrossAdapter=LidoOracle+ChainlinkOracle";
        cluster.oracleProviders[USDC   ] = "ChainlinkOracle";
        cluster.oracleProviders[USDT   ] = "ChainlinkOracle";
        cluster.oracleProviders[cbBTC  ] = "CrossAdapter=FixedRateOracle+ChainlinkOracle";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[cbBTC  ] = 0;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[cbBTC  ] = 0;

        // define IRM classes here and assign them to the assets
        {
            uint256[4] memory irmBTC = [uint256(0), uint256(643054912),  uint256(18204129717), uint256(1932735283)];
            cluster.kinkIRMParams[cbBTC] = irmBTC;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0   
        //                cbBTC
        /* 0  cbBTC   */ [0.00e4]
        ];

        // define auxiliary ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of auxiliaryVaults in the addresses file
        cluster.auxiliaryLTVs = [
            //                       0   
            //                       cbBTC
            /* 0  Escrow WETH    */ [0.00e4],
            /* 1  Escrow wstETH  */ [0.00e4],
            /* 2  Escrow USDC    */ [0.00e4],
            /* 3  Escrow USDT    */ [0.00e4],
            /* 4  Prime  WETH    */ [0.00e4],
            /* 5  Prime  wstETH  */ [0.00e4],
            /* 6  Prime  USDC    */ [0.00e4],
            /* 7  Prime  USDT    */ [0.00e4]
        ];
    }

    function additionalOperations() internal override broadcast {
        GovernedPerspective(peripheryAddresses.governedPerspective).perspectiveUnverify(cluster.vaults[0]);
    }

    function verifyCluster() internal override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i]);

            PerspectiveVerifier.verifyPerspective(
                peripheryAddresses.eulerUngovernedNzxPerspective,
                cluster.vaults[i],
                PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_SEPARATION | PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_BORROW |
                PerspectiveVerifier.E__LTV_COLLATERAL_CONFIG_LIQUIDATION | PerspectiveVerifier.E__LTV_COLLATERAL_RAMPING,
                0
            );
        }
    }
}
