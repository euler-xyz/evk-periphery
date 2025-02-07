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
        cluster.clusterAddressesPath = "/script/production/sonic/clusters/MevCapitalCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix. if more than one vauls has to be deployed for the same asset, it can be added in the
        // array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [WETH, USDC, scETH, scUSD, wstkscETH, wstkscUSD, wS, stS, wOS];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = 0xB672Ea44A1EC692A9Baf851dC90a1Ee3DB25F1C4;
        cluster.vaultsGovernor = 0xB672Ea44A1EC692A9Baf851dC90a1Ee3DB25F1C4;

        // define unit of account here
        cluster.unitOfAccount = USD;

        // define fee receiver here and interest fee here. if needed to be defined per asset, populate the
        // feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = address(0);
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
        cluster.oracleProviders[WETH     ] = "0xF9347838C10F72332c1b64080743350069233395";
        cluster.oracleProviders[USDC     ] = "0xdC2492409Ef8A0574cf567232b8B55919505e0Ea";
        cluster.oracleProviders[scETH    ] = "0x56A39f7907Ca26D87f8183193528d74503Ef9B11";
        cluster.oracleProviders[scUSD    ] = "0x5ec86ad76f29a278E8F1373927Af4854be54A963";
        cluster.oracleProviders[wstkscETH] = "0x0afddC99E980A46f1DC481E1B59e0634Dc5b27F4";
        cluster.oracleProviders[wstkscUSD] = "0xc32F6c8423d4c90d4E29Fb62832c3DDFDEdFc12E";
        cluster.oracleProviders[wS       ] = "0xc59486164BDFEe0843DB80d2987Ec0E1028f7D84";
        cluster.oracleProviders[stS      ] = "0x2c1bc59F07af5D3dFA556bbaE60179B54DE27b4d";
        cluster.oracleProviders[wOS      ] = "ExternalVault|0xf62820B7E0146cC436d99f962450c5cDDca3Db35";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[WETH     ] = 1_500;
        cluster.supplyCaps[USDC     ] = 5_000_000;
        cluster.supplyCaps[scETH    ] = 600;
        cluster.supplyCaps[scUSD    ] = 2_000_000;
        cluster.supplyCaps[wstkscETH] = 600;
        cluster.supplyCaps[wstkscUSD] = 2_000_000;
        cluster.supplyCaps[wS       ] = 10_000_000;
        cluster.supplyCaps[stS      ] = 4_000_000;
        cluster.supplyCaps[wOS      ] = 0;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[WETH     ] = 1_300;
        cluster.borrowCaps[USDC     ] = 4_250_000;
        cluster.borrowCaps[scETH    ] = 240;
        cluster.borrowCaps[scUSD    ] = 800_000;
        cluster.borrowCaps[wstkscETH] = 240;
        cluster.borrowCaps[wstkscUSD] = 800_000;
        cluster.borrowCaps[wS       ] = 0;
        cluster.borrowCaps[stS      ] = 1_600_000;
        cluster.borrowCaps[wOS      ] = 0;

        // define IRMs
        for (uint256 i = 0; i < cluster.assets.length; i++) {
            cluster.irms[i] = 0x3009dB521e9B781637DA5C53323322dAa0B0bDE1;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.01e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                  0                1         2        3       4        5         6       7         8
            //                  WETH             USDC     scETH    scUSD   wstkscETH wstkscUSD wS      stS      wOS
            /* 0  WETH      */ [uint16(0.000e4), 0.780e4, 0.915e4, 0.780e4, 0.915e4, 0.780e4, 0.780e4, 0.780e4, 0.780e4],
            /* 1  USDC      */ [uint16(0.780e4), 0.000e4, 0.780e4, 0.915e4, 0.780e4, 0.915e4, 0.780e4, 0.780e4, 0.780e4],
            /* 2  scETH     */ [uint16(0.915e4), 0.780e4, 0.000e4, 0.780e4, 0.915e4, 0.780e4, 0.780e4, 0.780e4, 0.780e4],
            /* 3  scUSDC    */ [uint16(0.780e4), 0.915e4, 0.780e4, 0.000e4, 0.780e4, 0.915e4, 0.780e4, 0.780e4, 0.780e4],
            /* 4  wstkscETH */ [uint16(0.915e4), 0.780e4, 0.915e4, 0.780e4, 0.000e4, 0.780e4, 0.780e4, 0.780e4, 0.780e4],
            /* 5  wstkscUSD */ [uint16(0.780e4), 0.915e4, 0.780e4, 0.915e4, 0.780e4, 0.000e4, 0.780e4, 0.780e4, 0.780e4],
            /* 6  wS        */ [uint16(0.780e4), 0.780e4, 0.780e4, 0.780e4, 0.780e4, 0.780e4, 0.000e4, 0.915e4, 0.915e4],
            /* 7  stS       */ [uint16(0.000e4), 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.915e4, 0.000e4, 0.915e4],
            /* 8  wOS       */ [uint16(0.000e4), 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.915e4, 0.000e4, 0.000e4]
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
