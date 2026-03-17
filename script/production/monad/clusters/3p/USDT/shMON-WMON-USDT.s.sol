// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "../../ManageCluster.s.sol";
import {OracleVerifier} from "../../../../../utils/SanityCheckOracle.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/monad/clusters/3p/USDT/shMON-WMON-USDT.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            shMON,
            WMON,
            USDT
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
        cluster.oracleProviders[shMON] = "0xFD8db30cE78b019700861F21F3b44117c0A2e000";
        cluster.oracleProviders[WMON] = "0x03e574FAD8b74FE9DA7F32d709bD881A6e8eF2dE";
        cluster.oracleProviders[USDT] = "0x2D842527F1E6CD19a643C127B175bb80924B3036";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[shMON] = 800_000_000;
        cluster.supplyCaps[WMON] = 720_000_000;
        cluster.supplyCaps[USDT] = 36_000_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[shMON] = type(uint256).max;
        cluster.borrowCaps[WMON] = 648_000_000;
        cluster.borrowCaps[USDT] = 32_400_000;

        // define IRM classes here and assign them to the assets
        {
            // Base=0.00% APY,  Kink(90.00%)=10.00% APY  Max=50.00% APY
            uint256[4] memory irmWMON = [uint256(0), uint256(781343251),  uint256(22883569897), uint256(3865470566)];
            // Base=0.00% APY,  Kink(90.00%)=5.5% APY  Max=18.00% APY
            uint256[4] memory irmUSDT = [uint256(0), uint256(438921808),  uint256(8261539992), uint256(3865470566)];

            cluster.kinkIRMParams[WMON] = irmWMON;
            cluster.kinkIRMParams[USDT] = irmUSDT;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 0 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.01e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0                1        2    
        //                shMON            WMON     USDT
        /* 0  shMON    */ [uint16(0.00e4), 0.94e4, 0.80e4],
        /* 1  WMON     */ [uint16(0.00e4), 0.00e4, 0.80e4],
        /* 2  USDT     */ [uint16(0.00e4), 0.80e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
        // No external vaults in this cluster
    }

    function postOperations() internal view override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }
    }
}
