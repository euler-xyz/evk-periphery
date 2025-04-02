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
        cluster.assets = [WETH, USDC, scETH, scUSD, wstkscETH, wstkscUSD, wS, stS, wOS, PT_wstkscETH, PT_wstkscUSD, PT_wOS, PT_stS];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = 0xB672Ea44A1EC692A9Baf851dC90a1Ee3DB25F1C4;
        cluster.vaultsGovernor = 0xB672Ea44A1EC692A9Baf851dC90a1Ee3DB25F1C4;

        // define unit of account here
        cluster.unitOfAccount = USD;

        // define fee receiver here and interest fee here. if needed to be defined per asset, populate the
        // feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = 0x50dE2Fb5cd259c1b99DBD3Bb4E7Aac76BE7288fC;
        cluster.interestFee = 0.15e4;

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
        cluster.oracleProviders[wOS      ] = "0xD544CcB6f2231bd1cCAC0258cbA89E8A13D4a421";
        cluster.oracleProviders[PT_wstkscETH      ] = "0xBce127EfD2a546afC94C9776f7Ce138240182Cb9";
        cluster.oracleProviders[PT_wstkscUSD      ] = "0x997d72fb46690f304C7DB92df9AA823323fb23B2";
        cluster.oracleProviders[PT_wOS      ] = "0xB572C563F6F900682F42E07e5ACa55564EC6C9F5";
        cluster.oracleProviders[PT_stS      ] = "0x16cE03d4d67fdA6727498eDbDE2e4FD0bF5e32D3";


        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[WETH     ] = 6_000;
        cluster.supplyCaps[USDC     ] = 50_000_000;
        cluster.supplyCaps[scETH    ] = 25_000;
        cluster.supplyCaps[scUSD    ] = 100_000_000;
        cluster.supplyCaps[wstkscETH] = 10_000;
        cluster.supplyCaps[wstkscUSD] = 5_000_000;
        cluster.supplyCaps[wS       ] = 100_000_000;
        cluster.supplyCaps[stS      ] = 100_000_000;
        cluster.supplyCaps[wOS      ] = 10_000_000;
        cluster.supplyCaps[PT_wstkscETH      ] = 2_500;
        cluster.supplyCaps[PT_wstkscUSD      ] = 10_000_000;
        cluster.supplyCaps[PT_wOS      ] = 1_000_000;
        cluster.supplyCaps[PT_stS      ] = 5_000_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[WETH     ] = 5_000;
        cluster.borrowCaps[USDC     ] = 45_000_000;
        cluster.borrowCaps[scETH    ] = 15_000;
        cluster.borrowCaps[scUSD    ] = 45_000_000;
        cluster.borrowCaps[wstkscETH] = type(uint256).max;
        cluster.borrowCaps[wstkscUSD] = type(uint256).max;
        cluster.borrowCaps[wS       ] = 90_000_000;
        cluster.borrowCaps[stS      ] = type(uint256).max;
        cluster.borrowCaps[wOS      ] = type(uint256).max;
        cluster.supplyCaps[PT_wstkscETH      ] = type(uint256).max;
        cluster.supplyCaps[PT_wstkscUSD      ] = type(uint256).max;
        cluster.supplyCaps[PT_wOS      ] = type(uint256).max;
        cluster.supplyCaps[PT_stS      ] = type(uint256).max;


        // define IRMs
        {

            // Base=0% APY,  Kink(90%)=15.00% APY  Max=100.00% APY 0xc675Fe14c7baF2AB052096e0E5771ca3acd019c3 
            uint256[4] memory irmwS = [uint256(0), uint256(1145746606), uint256(40829424352), uint256(3865470566)];


            // Base=0% APY  Kink(90%)=9.00% APY  Max=50.00% APY 0x0Cd08B170C9b1b5190Ad2cc459242d81e2A7C90A
            uint256[4] memory irmMajor  = [uint256(0), uint256(706470369), uint256(23557417865), uint256(3865470566)];

            cluster.kinkIRMParams[WETH     ] = irmMajor;
            cluster.kinkIRMParams[USDC     ] = irmMajor;
            cluster.kinkIRMParams[scETH    ] = irmMajor;
            cluster.kinkIRMParams[scUSD    ] = irmMajor;
            cluster.kinkIRMParams[wS       ] = irmwS;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.01e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                     0                1         2        3       4        5         6       7         8         9            10           11         12
            //                     WETH             USDC     scETH    scUSD   wstkscETH wstkscUSD wS      stS      wOS        PT_wstkscETH PT_wstkscUSD PT_wOS     PT_stS 
            /* 0  WETH         */ [uint16(0.000e4), 0.780e4, 0.915e4, 0.780e4, 0.000e4, 0.000e4, 0.780e4, 0.780e4, 0.000e4,0.000e4, 0.000e4, 0.000e4, 0.000e4],
            /* 1  USDC         */ [uint16(0.780e4), 0.000e4, 0.780e4, 0.915e4, 0.000e4, 0.000e4, 0.780e4, 0.780e4, 0.000e4,0.000e4, 0.000e4, 0.000e4, 0.000e4],
            /* 2  scETH        */ [uint16(0.915e4), 0.780e4, 0.000e4, 0.780e4, 0.000e4, 0.000e4, 0.780e4, 0.780e4, 0.000e4,0.000e4, 0.000e4, 0.000e4, 0.000e4],
            /* 3  scUSDC       */ [uint16(0.780e4), 0.915e4, 0.780e4, 0.000e4, 0.000e4, 0.000e4, 0.780e4, 0.780e4, 0.000e4,0.000e4, 0.000e4, 0.000e4, 0.000e4],
            /* 4  wstkscETH    */ [uint16(0.915e4), 0.780e4, 0.915e4, 0.780e4, 0.000e4, 0.000e4, 0.780e4, 0.780e4, 0.000e4,0.000e4, 0.000e4, 0.000e4, 0.000e4],
            /* 5  wstkscUSD    */ [uint16(0.780e4), 0.915e4, 0.780e4, 0.915e4, 0.000e4, 0.000e4, 0.780e4, 0.780e4, 0.000e4,0.000e4, 0.000e4, 0.000e4, 0.000e4],
            /* 6  wS           */ [uint16(0.780e4), 0.780e4, 0.780e4, 0.780e4, 0.000e4, 0.000e4, 0.000e4, 0.915e4, 0.000e4,0.000e4, 0.000e4, 0.000e4, 0.000e4],
            /* 7  stS          */ [uint16(0.000e4), 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.915e4, 0.000e4, 0.000e4,0.000e4, 0.000e4, 0.000e4, 0.000e4],
            /* 8  wOS          */ [uint16(0.000e4), 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.915e4, 0.000e4, 0.000e4,0.000e4, 0.000e4, 0.000e4, 0.000e4],
            /* 9  PT_wstkscETH */ [uint16(0.915e4), 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4,0.000e4, 0.000e4, 0.000e4, 0.000e4],
            /* 10  PT_wstkscUSD*/ [uint16(0.000e4), 0.915e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4,0.000e4, 0.000e4, 0.000e4, 0.000e4],
            /* 11  PT_wOS      */ [uint16(0.000e4), 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.915e4, 0.000e4, 0.000e4,0.000e4, 0.000e4, 0.000e4, 0.000e4],
            /* 12  PT_stS      */ [uint16(0.000e4), 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.000e4, 0.915e4, 0.000e4, 0.000e4,0.000e4, 0.000e4, 0.000e4, 0.000e4]

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
