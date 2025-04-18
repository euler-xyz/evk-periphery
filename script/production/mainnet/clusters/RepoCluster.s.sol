// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";
import {ClusterDump} from "../../../utils/ClusterDump.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/mainnet/clusters/RepoCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            USDC,
            USDT,
            USDtb,
            rlUSD,
            wM,
            sBUIDL,
            USYC,
            USDY,
            wUSDM,
            wUSDL,
            mTBILL
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
        cluster.oracleProviders[USDC  ] = "0xb92b9341be191895e8c68b170ac4528839ffe0b2";
        cluster.oracleProviders[USDT  ] = "0x575ffc02361368a2708c00bc7e299d1cd1c89f8a";
        cluster.oracleProviders[USDtb ] = "0x16fcc1d29833b4c46fa7c7232b0c613034c0242e";
        cluster.oracleProviders[rlUSD ] = "0x4C631cBBd02B9b510ccB8d47A0D237F485bB4B17";
        cluster.oracleProviders[wM    ] = "0x62357F6Df9B45A638401482f085d9d998fD2Aa6e";
        cluster.oracleProviders[sBUIDL] = "0xe8a784f4bdcd4707baf4068e72887888ad58c033";
        cluster.oracleProviders[USYC  ] = "0x617889fed99d725831305d13b86ecc110d772822";
        cluster.oracleProviders[USDY  ] = "0xB0361d730BC0F2C6f3ee66538e4eB91b846c5ee8";
        cluster.oracleProviders[wUSDM ] = "0x73bf80c6e9812f8ebc3dc4cbe45247e631d8c44c";
        cluster.oracleProviders[wUSDL ] = "0xcd8204b02b74ade1461f5aa7794a2d6e91a38c33";
        cluster.oracleProviders[mTBILL] = "0x073e9bd08e2053ac1748b7a698bae874232eae71";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[USDC  ] = 50_000_000; 
        cluster.supplyCaps[USDT  ] = 50_000_000;
        cluster.supplyCaps[USDtb ] = 50_000_000;
        cluster.supplyCaps[rlUSD ] = 50_000_000;
        cluster.supplyCaps[wM    ] = 10_000_000;
        cluster.supplyCaps[sBUIDL] = 0;//50_000_000;
        cluster.supplyCaps[USYC  ] = 50_000_000;
        cluster.supplyCaps[USDY  ] = 50_000_000;
        cluster.supplyCaps[wUSDM ] = 20_000_000;
        cluster.supplyCaps[wUSDL ] = 20_000_000;
        cluster.supplyCaps[mTBILL] = 10_000_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[USDC  ] = 46_000_000;
        cluster.borrowCaps[USDT  ] = 46_000_000;
        cluster.borrowCaps[USDtb ] = 46_000_000;
        cluster.borrowCaps[rlUSD ] = 5_000_000;
        cluster.borrowCaps[wM    ] = 9_200_000;
        cluster.borrowCaps[sBUIDL] = 0;//type(uint256).max;
        cluster.borrowCaps[USYC  ] = type(uint256).max;
        cluster.borrowCaps[USDY  ] = type(uint256).max;
        cluster.borrowCaps[wUSDM ] = type(uint256).max;
        cluster.borrowCaps[wUSDL ] = type(uint256).max;
        cluster.borrowCaps[mTBILL] = type(uint256).max;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(92%)=4.3% APY  Max=15.00% APY
            uint256[4] memory irm = [uint256(0), uint256(337638132), uint256(9006897666), uint256(3951369912)];

            cluster.kinkIRMParams[USDC  ] = irm;
            cluster.kinkIRMParams[USDT  ] = irm;
            cluster.kinkIRMParams[USDtb ] = irm;
            cluster.kinkIRMParams[rlUSD ] = irm;
            cluster.kinkIRMParams[wM    ] = irm;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.01e4;
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //               0                1        2        3        4        5        6        7        8        9        10    
        //               USDC             USDT     USDtb    RLUSD    wM       sBUIDL   USYC     USDY     wUSDM    wUSDL    mTBILL  
        /* 0  USDC   */ [uint16(0.000e4), 0.975e4, 0.975e4, 0.975e4, 0.975e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 1  USDT   */ [uint16(0.975e4), 0.000e4, 0.975e4, 0.975e4, 0.975e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 2  USDtb  */ [uint16(0.975e4), 0.975e4, 0.000e4, 0.975e4, 0.975e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 3  RLUSD  */ [uint16(0.975e4), 0.975e4, 0.975e4, 0.000e4, 0.975e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 4  wM     */ [uint16(0.975e4), 0.975e4, 0.975e4, 0.975e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 5  sBUIDL */ [uint16(0.960e4), 0.960e4, 0.960e4, 0.960e4, 0.960e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 6  USYC   */ [uint16(0.960e4), 0.960e4, 0.960e4, 0.960e4, 0.960e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 7  USDY   */ [uint16(0.960e4), 0.960e4, 0.960e4, 0.960e4, 0.960e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 8  wUSDM  */ [uint16(0.960e4), 0.960e4, 0.960e4, 0.960e4, 0.960e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 9  wUSDL  */ [uint16(0.960e4), 0.960e4, 0.960e4, 0.960e4, 0.960e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4],
        /* 10 mTBILL */ [uint16(0.960e4), 0.960e4, 0.960e4, 0.960e4, 0.960e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4]
        ];
    }

    function postOperations() internal view override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }
    }
}
