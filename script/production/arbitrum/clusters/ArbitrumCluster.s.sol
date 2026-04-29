// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/arbitrum/clusters/ArbitrumCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            USDC,
            USDT0,
            WETH,
            wstETH,
            tETH,
            WBTC
        ];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = 0x060DB084bF41872861f175d83f3cb1B5566dfEA3; //governorAddresses.accessControlEmergencyGovernor;

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
        cluster.oracleProviders[USDC  ] = "0x3CD81aee1c41757B88961572BfD192cBF2127f37";
        cluster.oracleProviders[USDT0 ] = "0xbBC0166f5F14e9C4970c87bd5336e19Bc530FD74";
        cluster.oracleProviders[WETH  ] = "0x6C1212B14E190a5eB91B1c8cc2f6f4623476862C";
        cluster.oracleProviders[wstETH] = "0x1B9405C4742DF2fB0a2fC838fA08c4FE03300702";
        cluster.oracleProviders[tETH  ] = "0x5CAbb4FC26Db9d6b028dE7a9ae05164671d51D7a";
        cluster.oracleProviders[WBTC  ] = "0xcE111096Cd2260436EA475fA6C70A284692D1887";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[USDC  ] = 100_000_000;
        cluster.supplyCaps[USDT0 ] = 100_000_000;
        cluster.supplyCaps[WETH  ] = 18_800;
        cluster.supplyCaps[wstETH] = 11_500;
        cluster.supplyCaps[tETH  ] = 150;
        cluster.supplyCaps[WBTC  ] = 600;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[USDC  ] = 90_000_000;
        cluster.borrowCaps[USDT0 ] = 90_000_000;
        cluster.borrowCaps[WETH  ] = 16_500;
        cluster.borrowCaps[wstETH] = 5_500;
        cluster.borrowCaps[tETH  ] = 75;
        cluster.borrowCaps[WBTC  ] = 540;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(90%)=2.70% APY  Max=40.00% APY
            uint256[4] memory irmETH     = [uint256(0), uint256(218407859),  uint256(22859618857), uint256(3865470566)];

            // Base=0% APY,  Kink(90%)=1.00% APY  Max=40.00% APY
            uint256[4] memory irmBTC     = [uint256(0), uint256(81571803),  uint256(24091143362), uint256(3865470566)];

            // Base=0% APY,  Kink(50%)=1.00% APY  Max=40.00% APY
            uint256[4] memory irmETH_LST = [uint256(0), uint256(146829246),  uint256(4818228676), uint256(2147483648)];

            // Base=0% APY,  Kink(90%)=4.00% APY  Max=40.00% APY
            uint256[4] memory irmUSD_1   = [uint256(0), uint256(321527456),  uint256(21931542489), uint256(3865470566)];

            // Base=0% APY,  Kink(80%)=2.00% APY  Max=40.00% APY
            uint256[4] memory irmUSD_2   = [uint256(0), uint256(182632435),  uint256(11682115056), uint256(3435973836)];

            // Base=0% APY,  Kink(80%)=5.00% APY  Max=80.00% APY
            uint256[4] memory irmDEFI    = [uint256(0), uint256(449973958),  uint256(19883875652), uint256(3435973836)];

            cluster.kinkIRMParams[USDC  ] = irmUSD_1;
            cluster.kinkIRMParams[USDT0 ] = irmUSD_1;
            cluster.kinkIRMParams[WETH  ] = irmETH;
            cluster.kinkIRMParams[wstETH] = irmETH_LST;
            cluster.kinkIRMParams[tETH  ] = irmETH_LST;
            cluster.kinkIRMParams[WBTC  ] = irmBTC;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 30 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0               1       2       3        4        5
        //                USDC            USDT0   WETH    wstETH   tETH     WBTC
        /* 0  USDC    */ [uint16(0.00e4), 0.96e4, 0.87e4, 0.840e4, 0.000e4, 0.86e4],
        /* 1  USDT0   */ [uint16(0.96e4), 0.00e4, 0.87e4, 0.840e4, 0.000e4, 0.86e4],
        /* 2  WETH    */ [uint16(0.87e4), 0.87e4, 0.00e4, 0.950e4, 0.930e4, 0.86e4],
        /* 3  wstETH  */ [uint16(0.85e4), 0.85e4, 0.95e4, 0.000e4, 0.925e4, 0.84e4],
        /* 4  tETH    */ [uint16(0.80e4), 0.80e4, 0.93e4, 0.925e4, 0.000e4, 0.00e4],
        /* 5  WBTC    */ [uint16(0.87e4), 0.87e4, 0.87e4, 0.840e4, 0.000e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
    }

    function postOperations() internal view override {
        //for (uint256 i = 0; i < cluster.vaults.length; ++i) {
        //    OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], cluster.vaults, false);
        //}
    }
}
