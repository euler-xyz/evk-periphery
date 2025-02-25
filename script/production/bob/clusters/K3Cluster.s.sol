// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../../utils/PerspectiveCheck.s.sol";
import {ClusterDump} from "../../../utils/ClusterDump.s.sol";

contract Cluster is ManageCluster {
    address internal constant K3_WALLET = 0x3518b4c4539337369b10e0d93427e6Ba1AC44d95;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/bob/clusters/K3Cluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            LBTC,
            HybridBTC_pendle,
            WBTC
        ];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = K3_WALLET;
        cluster.vaultsGovernor = K3_WALLET;

        // define unit of account here
        cluster.unitOfAccount = USD;

        // define fee receiver here and interest fee here. if needed to be defined per asset, populate the feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = K3_WALLET;
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
        cluster.oracleProviders[LBTC            ] = "0xed29690a4d7f1b63807957fb71149a8dcfd820a4";
        cluster.oracleProviders[HybridBTC_pendle] = "0x997d72fb46690f304c7db92df9aa823323fb23b2";
        cluster.oracleProviders[WBTC            ] = "0xf2b8616744502851343c52da76e9adfb97f08b91";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[LBTC            ] = 1_000;
        cluster.supplyCaps[HybridBTC_pendle] = 500;
        cluster.supplyCaps[WBTC            ] = 1_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[LBTC            ] = 900;
        cluster.borrowCaps[HybridBTC_pendle] = type(uint256).max;
        cluster.borrowCaps[WBTC            ] = 900;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(85%)=2.50% APY  Max=12.5% APY
            uint256[4] memory irm_1 = [uint256(0), uint256(214335049), uint256(4578875485), uint256(3650722201)];

            // Base=0% APY  Kink(85%)=2.75% APY  Max=15% APY
            uint256[4] memory irm_2 = [uint256(0), uint256(235480320), uint256(5540137482), uint256(3650722201)];

            cluster.kinkIRMParams[LBTC] = irm_1;
            cluster.kinkIRMParams[WBTC] = irm_2;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.01e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                          0                1        2
        //                          LBTC     HybridBTC_pendle WBTC
        /* 0  LBTC              */ [uint16(0.000e4), 0.000e4, 0.965e4],
        /* 1  HybridBTC_pendle  */ [uint16(0.935e4), 0.000e4, 0.875e4],
        /* 2  WBTC              */ [uint16(0.965e4), 0.000e4, 0.000e4]
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
