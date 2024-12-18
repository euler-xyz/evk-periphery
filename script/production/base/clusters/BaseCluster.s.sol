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
        cluster.assets = [
            WETH,
            wstETH,
            cbETH,
            weETH,
            ezETH,
            RETH,
            USDC,
            EURC,
            cbBTC,
            LBTC,
            AERO
        ];

        // define the governors here
        cluster.oracleRoutersGovernor = GOVERNOR_ACCESS_CONTROL;
        cluster.vaultsGovernor = GOVERNOR_ACCESS_CONTROL;

        // define unit of account here
        cluster.unitOfAccount = USD;

        // define fee receiver here and interest fee here. if needed to be defined per asset, populate the feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = address(0);
        cluster.interestFee = 0.1e4;

        cluster.interestFeeOverride[WETH] = 0;
        cluster.interestFeeOverride[USDC] = 0;
        cluster.interestFeeOverride[EURC] = 0;

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
        cluster.oracleProviders[cbETH ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[weETH ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[ezETH ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[RETH  ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[USDC  ] = "ChainlinkOracle";
        cluster.oracleProviders[EURC  ] = "ChainlinkOracle";
        cluster.oracleProviders[cbBTC ] = "CrossAdapter=ChronicleOracle+ChronicleOracle";
        cluster.oracleProviders[LBTC  ] = "CrossAdapter=RedstoneClassicOracle+ChainlinkOracle";
        cluster.oracleProviders[AERO  ] = "ChainlinkOracle";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[WETH  ] = 5_000;
        cluster.supplyCaps[wstETH] = 5_000;
        cluster.supplyCaps[cbETH ] = 5_000;
        cluster.supplyCaps[weETH ] = 5_000;
        cluster.supplyCaps[ezETH ] = 5_000;
        cluster.supplyCaps[RETH  ] = 5_000;
        cluster.supplyCaps[USDC  ] = 20_000_000;
        cluster.supplyCaps[EURC  ] = 20_000_000;
        cluster.supplyCaps[cbBTC ] = 250;
        cluster.supplyCaps[LBTC  ] = 250;
        cluster.supplyCaps[AERO  ] = 2_000_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[WETH  ] = 4_250;
        cluster.borrowCaps[wstETH] = 2_000;
        cluster.borrowCaps[cbETH ] = 2_000;
        cluster.borrowCaps[weETH ] = 1_250;
        cluster.borrowCaps[ezETH ] = 1_250;
        cluster.borrowCaps[RETH  ] = 2_000;
        cluster.borrowCaps[USDC  ] = 18_000_000;
        cluster.borrowCaps[EURC  ] = 18_000_000;
        cluster.borrowCaps[cbBTC ] = 213;
        cluster.borrowCaps[LBTC  ] = 63;
        cluster.borrowCaps[AERO  ] = 1_600_000;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(85%)=2.79% APY  Max=122.55% APY
            uint256[4] memory irmETH       = [uint256(0), uint256(238858791),  uint256(37995478916), uint256(3650722201)];

            // Base=0% APY,  Kink(85%)=2.79% APY  Max=122.55% APY
            uint256[4] memory irmBTC       = [uint256(0), uint256(238858791),  uint256(37995478916), uint256(3650722201)];

            // Base=0% APY,  Kink(40%)=4.60% APY  Max=145.96% APY
            uint256[4] memory irmETH_LST   = [uint256(0), uint256(829546015),  uint256(10514117840), uint256(1717986918)];

            // Base=0% APY,  Kink(25%)=4.60% APY  Max=848.77% APY
            uint256[4] memory irmETH_LRT   = [uint256(0), uint256(1327273625), uint256(21691866441), uint256(1073741824)];

            // Base=0% APY,  Kink(90%)=9.42% APY  Max=101.38% APY
            uint256[4] memory irmUSD_1     = [uint256(0), uint256(738003605),  uint256(45006465867), uint256(3865470566)];

            // Base=0% APY,  Kink(25%)=4.60% APY  Max=848.77% APY
            uint256[4] memory irmBTC_LRT   = [uint256(0), uint256(1327273625), uint256(21691866441), uint256(1073741824)];

            // Base=0% APY,  Kink(80%)=8.87% APY  Max=848.77% APY
            uint256[4] memory irmDEFI      = [uint256(0), uint256(783779538),  uint256(79868472958), uint256(3435973836)];

            cluster.kinkIRMParams[WETH  ] = irmETH;
            cluster.kinkIRMParams[wstETH] = irmETH_LST;
            cluster.kinkIRMParams[cbETH ] = irmETH_LST;
            cluster.kinkIRMParams[weETH ] = irmETH_LRT;
            cluster.kinkIRMParams[ezETH ] = irmETH_LRT;
            cluster.kinkIRMParams[RETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[USDC  ] = irmUSD_1;
            cluster.kinkIRMParams[EURC  ] = irmUSD_1;
            cluster.kinkIRMParams[cbBTC ] = irmBTC;
            cluster.kinkIRMParams[LBTC  ] = irmBTC_LRT;
            cluster.kinkIRMParams[AERO  ] = irmDEFI;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0               1       2       3       4       5       6       7       8       9       10
        //                WETH            wstETH  cbETH   weETH   ezETH   RETH    USDC    EURC    cbBTC   LBTC    AERO
        /* 0  WETH    */ [uint16(0.00e4), 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.85e4, 0.85e4, 0.78e4, 0.78e4, 0.78e4],
        /* 1  wstETH  */ [uint16(0.93e4), 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.83e4, 0.83e4, 0.77e4, 0.77e4, 0.77e4],
        /* 2  cbETH   */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.92e4, 0.93e4, 0.93e4, 0.80e4, 0.80e4, 0.75e4, 0.75e4, 0.75e4],
        /* 3  weETH   */ [uint16(0.93e4), 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.80e4, 0.80e4, 0.75e4, 0.75e4, 0.75e4],
        /* 4  ezETH   */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.77e4, 0.77e4, 0.72e4, 0.72e4, 0.72e4],
        /* 5  RETH    */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.77e4, 0.77e4, 0.72e4, 0.72e4, 0.72e4],
        /* 6  USDC    */ [uint16(0.85e4), 0.83e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.00e4, 0.90e4, 0.80e4, 0.80e4, 0.80e4],
        /* 7  EURC    */ [uint16(0.85e4), 0.83e4, 0.80e4, 0.80e4, 0.80e4, 0.80e4, 0.90e4, 0.00e4, 0.80e4, 0.80e4, 0.80e4],
        /* 8  cbBTC   */ [uint16(0.75e4), 0.73e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.80e4, 0.80e4, 0.00e4, 0.90e4, 0.70e4],
        /* 9  LBTC    */ [uint16(0.75e4), 0.73e4, 0.70e4, 0.70e4, 0.70e4, 0.70e4, 0.80e4, 0.80e4, 0.90e4, 0.00e4, 0.70e4],
        /* 10 AERO    */ [uint16(0.65e4), 0.65e4, 0.65e4, 0.65e4, 0.65e4, 0.65e4, 0.65e4, 0.65e4, 0.65e4, 0.65e4, 0.00e4]
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
