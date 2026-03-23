// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/arbitrum/clusters/YieldCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            USDC,
            USDT0,
            USDS,
            RLP
        ];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = multisigAddresses.labs;

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
        // External Vaults Registry, the string should be preceded by "ExternalVault|" prefix. this is in order to resolve 
        // the asset (vault) in the oracle router.
        // in case the adapter is not present in the Adapter Registry, the adapter address can be passed instead in form of a string.
        cluster.oracleProviders[USDC  ] = "0x86220c3dc4ada691e0b09ff8f371bffe6efd8c75";
        cluster.oracleProviders[USDT0 ] = "0x4d7e1da95a407b28b17715cece2f3e1b101ecdfd";
        cluster.oracleProviders[USDS  ] = "0xf5c2dfd1740d18ad7cf23fba76cc11d877802937";
        cluster.oracleProviders[RLP   ] = "0xa542dbb6e827ca64a409558976ae04f86928bd68";
        
        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[USDC  ] = 0;
        cluster.supplyCaps[USDT0 ] = 100_000_000;
        cluster.supplyCaps[USDS  ] = 50_000_000;
        cluster.supplyCaps[RLP   ] = 7_500_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[USDC  ] = 0;
        cluster.borrowCaps[USDT0 ] = 90_000_000;
        cluster.borrowCaps[USDS  ] = 45_000_000;
        cluster.borrowCaps[RLP   ] = type(uint256).max;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(90%)=8.00% APY  Max=25.00% APY
            uint256[4] memory irmUSD     = [uint256(0), uint256(630918865),  uint256(10785505476), uint256(3865470566)];

            // Base=0% APY,  Kink(90%)=7.00% APY  Max=25.00% APY
            uint256[4] memory irmUSD_USDC = [uint256(0), uint256(554658784),  uint256(11471846206), uint256(3865470566)];

            cluster.kinkIRMParams[USDC  ] = irmUSD_USDC;
            cluster.kinkIRMParams[USDT0 ] = irmUSD;
            cluster.kinkIRMParams[USDS  ] = irmUSD;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 30 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        cluster.borrowLTVsOverride[3][0] = 0;
        cluster.borrowLTVsOverride[3][1] = 0;
        cluster.borrowLTVsOverride[3][2] = 0;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                            0               1       2       3 
        //                            USDC            USDT0   USDS    RLP
        /* 0  USDC                */ [uint16(0.00e4), 0.96e4, 0.95e4, 0.00e4],
        /* 1  USDT0               */ [uint16(0.96e4), 0.00e4, 0.95e4, 0.00e4],
        /* 2  USDS                */ [uint16(0.95e4), 0.95e4, 0.00e4, 0.00e4],
        /* 3  RLP                 */ [uint16(0.88e4), 0.88e4, 0.87e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
    }

    function postOperations() internal view override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], cluster.vaults, false);
        }
    }
}
