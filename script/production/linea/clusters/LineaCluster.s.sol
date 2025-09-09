// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/linea/clusters/LineaCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            WETH,
            wstETH,
            WETH,
            weETH,
            WETH,
            ezETH,
            WETH,
            wrsETH
        ];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = governorAddresses.accessControlEmergencyGovernor;

        // define unit of account here
        cluster.unitOfAccount = WETH;

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
        cluster.oracleProviders[wstETH] = "0x9d7BB1b8b82A7C2409aE9d1133700e4e7Ea34ffE";
        cluster.oracleProviders[weETH ] = "0x2A00BA96A1779a3bCfB728906b22D1145ABCD659";
        cluster.oracleProviders[ezETH ] = "0xBb91e02922ab31F17554BEFA65a581CE0EDE32eD";
        cluster.oracleProviders[wrsETH] = "0xC8127c71Cb0B896b08821d7f7eea0b05022Ad871";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[WETH   ] = 20_000;
        cluster.supplyCaps[wstETH ] = 10_000;
        cluster.supplyCaps[weETH  ] = 5_000;
        cluster.supplyCaps[ezETH  ] = 5_000;
        cluster.supplyCaps[wrsETH ] = 5_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[WETH   ] = type(uint256).max;
        cluster.borrowCaps[wstETH ] = 5_000;
        cluster.borrowCaps[weETH  ] = 2_500;
        cluster.borrowCaps[ezETH  ] = 2_500;
        cluster.borrowCaps[wrsETH ] = 2_500;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(90%)=2.70% APY  Max=8.00% APY
            uint256[4] memory irmETH     = [uint256(0), uint256(218407859),  uint256(3712599046), uint256(3865470566)];

            // Base=0% APY,  Kink(50%)=2.00% APY  Max=12.00% APY
            uint256[4] memory irmETH_LST = [uint256(0), uint256(292211896),  uint256(1380090972), uint256(2147483648)];

            cluster.kinkIRMParams[WETH  ] = irmETH;
            cluster.kinkIRMParams[wstETH] = irmETH_LST;
            cluster.kinkIRMParams[weETH ] = irmETH_LST;
            cluster.kinkIRMParams[ezETH ] = irmETH_LST;
            cluster.kinkIRMParams[wrsETH] = irmETH_LST;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.01e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0               1       2       3       4       5       6       7
        //                WETH            wstETH  WETH    weETH   WETH    ezETH   WETH    wrsETH
        /* 0  WETH    */ [uint16(0.00e4), 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  wstETH  */ [uint16(0.95e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  WETH    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 3  weETH   */ [uint16(0.00e4), 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 4  WETH    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4],
        /* 5  ezETH   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4],
        /* 6  WETH    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.93e4],
        /* 7  wrsETH  */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.95e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
    }

    function postOperations() internal view override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }
    }
}
