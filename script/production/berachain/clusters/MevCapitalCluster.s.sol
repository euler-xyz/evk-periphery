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
        cluster.clusterAddressesPath = "/script/production/berachain/clusters/MevCapitalCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix. if more than one vauls has to be deployed for the same asset, it can be added in the
        // array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [WBERA, WETH, WBTC, HONEY, USDC, STONE, BYUSD];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = 0xB672Ea44A1EC692A9Baf851dC90a1Ee3DB25F1C4;
        cluster.vaultsGovernor = 0xB672Ea44A1EC692A9Baf851dC90a1Ee3DB25F1C4;

        // define unit of account here
        cluster.unitOfAccount = USD;

        // define fee receiver here and interest fee here. if needed to be defined per asset, populate the
        // feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = 0xB672Ea44A1EC692A9Baf851dC90a1Ee3DB25F1C4;
        cluster.interestFee = 0.1e4;

        // define max liquidation discount here. if needed to be defined per asset, populate the
        // maxLiquidationDiscountOverride mapping
        cluster.maxLiquidationDiscount = 0.15e4;

        // define liquidation cool off time here. if needed to be defined per asset, populate the
        // liquidationCoolOffTimeOverride mapping
        cluster.liquidationCoolOffTime = 1;

        // define hook target and hooked ops here. if needed to be defined per asset, populate the hookTargetOverride
        // and hookedOpsOverride mappings
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
        // External Vaults Registry, the string should be preceeded by "ExternalVault|" prefix. this is in order to
        // resolve the asset (vault) in the oracle router.
        // in case the adapter is not present in the Adapter Registry, the adapter address can be passed instead in form
        // of a string.
        cluster.oracleProviders[WBERA    ] = "0xe6D9C66C0416C1c88Ca5F777D81a7F424D4Fa87b";
        cluster.oracleProviders[WETH     ] = "0xf7129a6280DCFfF6149792186b54C818ea4D80D6";
        cluster.oracleProviders[WBTC     ] = "0xF2b8616744502851343c52DA76e9adFb97f08b91";
        cluster.oracleProviders[HONEY    ] = "0x997d72fb46690f304C7DB92df9AA823323fb23B2";
        cluster.oracleProviders[USDC     ] = "0x5ad9C6117ceB1981CfCB89BEb6Bd29c9157aB5b3";
        cluster.oracleProviders[STONE    ] = "0x255Bee201D2526BBf2753DF6A6057f23431A3E1C";
        cluster.oracleProviders[BYUSD    ] = "0xe5908cbd7b3bc2648b32ce3dc8dfad4d83afd1b4";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[WBERA    ] = 5_000_000;
        cluster.supplyCaps[WETH     ] = 10_000;
        cluster.supplyCaps[WBTC     ] = 300;
        cluster.supplyCaps[HONEY    ] = 100_000_000;
        cluster.supplyCaps[USDC     ] = 100_000_000;
        cluster.supplyCaps[STONE    ] = 10_000;
        cluster.supplyCaps[BYUSD    ] = 100_000_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[WBERA    ] = 4_500_000;
        cluster.borrowCaps[WETH     ] = 9_200;
        cluster.borrowCaps[WBTC     ] = 276;
        cluster.borrowCaps[HONEY    ] = 92_000_000;
        cluster.borrowCaps[USDC     ] = 92_000_000;
        cluster.borrowCaps[STONE    ] = 9_200;
        cluster.borrowCaps[BYUSD    ] = 92_000_000;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(75%)=25.00% APY  Max=100.00% APY
            uint256[4] memory irmBERA  = [uint256(0), uint256(2195170036), uint256(13870952740), uint256(3221225472)];

            // Base=0% APY,  Kink(90%)=3.00% APY  Max=150.00% APY
            uint256[4] memory irmMajor = [uint256(0), uint256(242320082), uint256(65424051595), uint256(3865470566)];

            // Base=0% APY,  Kink(90%)=10.0% APY  Max=49.5% APY
            uint256[4] memory irmMinor = [uint256(0), uint256(781343251), uint256(22637222055), uint256(3865470566)];

            cluster.kinkIRMParams[WBERA    ] = irmBERA;
            cluster.kinkIRMParams[WETH     ] = irmMajor;
            cluster.kinkIRMParams[WBTC     ] = irmMajor;
            cluster.kinkIRMParams[HONEY    ] = irmMinor;
            cluster.kinkIRMParams[USDC     ] = irmMinor;
            cluster.kinkIRMParams[STONE    ] = irmMajor;
            cluster.kinkIRMParams[BYUSD    ] = irmMinor;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                  0                1        2        3        4        5        6     
            //                  WBERA            WETH     WBTC     HONEY    USDC     STONE    BYUSD    
            /* 0  WBERA     */ [uint16(0.000e4), 0.800e4, 0.800e4, 0.915e4, 0.915e4, 0.800e4, 0.915e4],
            /* 1  WETH      */ [uint16(0.700e4), 0.000e4, 0.850e4, 0.800e4, 0.800e4, 0.915e4, 0.800e4],
            /* 2  WBTC      */ [uint16(0.700e4), 0.850e4, 0.000e4, 0.800e4, 0.800e4, 0.850e4, 0.800e4],
            /* 3  HONEY     */ [uint16(0.700e4), 0.780e4, 0.780e4, 0.000e4, 0.965e4, 0.780e4, 0.000e4],
            /* 4  USDC      */ [uint16(0.700e4), 0.780e4, 0.780e4, 0.965e4, 0.000e4, 0.780e4, 0.000e4],
            /* 5  STONE     */ [uint16(0.700e4), 0.915e4, 0.800e4, 0.800e4, 0.800e4, 0.000e4, 0.800e4],
            /* 6  BYUSD     */ [uint16(0.700e4), 0.780e4, 0.780e4, 0.965e4, 0.965e4, 0.780e4, 0.000e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults.
        // double check the order of collaterals against the order of externalVaults in the addresses file
    }

    function postOperations() internal override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }

        ClusterDump dumper = new ClusterDump();
        dumper.dumpCluster(cluster.vaults, cluster.externalVaults);
    }
}
