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
        cluster.clusterAddressesPath = "/script/production/berachain/clusters/TulipaCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix. if more than one vauls has to be deployed for the same asset, it can be added in the
        // array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [HONEY, USDC, WBERA, WBTC, LBTC];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = 0xF53eAeB7e6f15CBb6dB990eaf2A26702e1D986d8;
        cluster.vaultsGovernor = 0xF53eAeB7e6f15CBb6dB990eaf2A26702e1D986d8;

        // define unit of account here
        cluster.unitOfAccount = USD;

        // define fee receiver here and interest fee here. if needed to be defined per asset, populate the
        // feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = 0xF53eAeB7e6f15CBb6dB990eaf2A26702e1D986d8;
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
        cluster.oracleProviders[HONEY    ] = "0x997d72fb46690f304C7DB92df9AA823323fb23B2";
        cluster.oracleProviders[USDC     ] = "0x5ad9C6117ceB1981CfCB89BEb6Bd29c9157aB5b3";
        cluster.oracleProviders[WBERA    ] = "0xe6D9C66C0416C1c88Ca5F777D81a7F424D4Fa87b";
        cluster.oracleProviders[WBTC     ] = "0xF2b8616744502851343c52DA76e9adFb97f08b91";
        cluster.oracleProviders[LBTC     ] = "0x575ffc02361368a2708c00bc7e299d1cd1c89f8a";
        
        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[HONEY    ] = 100_000_000;
        cluster.supplyCaps[USDC     ] = 100_000_000;
        cluster.supplyCaps[WBERA    ] = 10_000_000;
        cluster.supplyCaps[WBTC     ] = 10_000;
        cluster.supplyCaps[LBTC     ] = 10_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[HONEY    ] = 90_000_000;
        cluster.borrowCaps[USDC     ] = 90_000_000;
        cluster.borrowCaps[WBERA    ] = 9_000_000;
        cluster.borrowCaps[WBTC     ] = 9_000;
        cluster.borrowCaps[LBTC     ] = 9_000;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(90%)=9.00% APY  Max=120.00% APY
            uint256[4] memory irmStable  = [uint256(0), uint256(706476075), uint256(51814961737), uint256(3865470566)];

            // Base=0% APY,  Kink(60%)=18.00% APY  Max=150.00% APY
            uint256[4] memory irmBera    = [uint256(0), uint256(2035306047), uint256(13848274025), uint256(2576980377)];

            // Base=0% APY,  Kink(85%)=5.0% APY  Max=150.0% APY
            uint256[4] memory irmWBTC    = [uint256(0), uint256(423504902), uint256(42670093781), uint256(3650722201)];

            // Base=0% APY,  Kink(85%)=6.0% APY  Max=150.0% APY
            uint256[4] memory irmLBTC    = [uint256(0), uint256(505781619), uint256(42203859048), uint256(3650722201)];

            cluster.kinkIRMParams[HONEY    ] = irmStable;
            cluster.kinkIRMParams[USDC     ] = irmStable;
            cluster.kinkIRMParams[WBERA    ] = irmBera;
            cluster.kinkIRMParams[WBTC     ] = irmWBTC;
            cluster.kinkIRMParams[LBTC     ] = irmLBTC;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                  0               1       2       3       4      
            //                  HONEY           USDC    WBERA   WBTC    LBTC   
            /* 0  HONEY     */ [uint16(0.00e4), 0.95e4, 0.75e4, 0.80e4, 0.80e4],
            /* 1  USDC      */ [uint16(0.95e4), 0.00e4, 0.75e4, 0.80e4, 0.80e4],
            /* 2  WBERA     */ [uint16(0.95e4), 0.95e4, 0.00e4, 0.80e4, 0.80e4],
            /* 3  WBTC      */ [uint16(0.95e4), 0.95e4, 0.75e4, 0.00e4, 0.95e4],
            /* 4  LBTC      */ [uint16(0.95e4), 0.95e4, 0.75e4, 0.95e4, 0.00e4]
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
