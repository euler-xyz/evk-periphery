// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";

contract Cluster is ManageCluster {
    address internal constant PT_tbBILL_27NOV2025 = 0x5a791652f3b140d357df072d355a98ab754877D1;
    address internal constant PT_tbBILL_19FEB2026 = 0x9b3924f9652cabf3Db48B7B4C92E474c571B3Ab4;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/arbitrum/clusters/Theo.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT0, thBILL, PT_tbBILL_27NOV2025, PT_tbBILL_19FEB2026];
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
        // External Vaults Registry, the string should be preceded by "ExternalVault|" prefix. this is in order to resolve 
        // the asset (vault) in the oracle router.
        // in case the adapter is not present in the Adapter Registry, the adapter address can be passed instead in form of a string.
        cluster.oracleProviders[USDC] = "0x86220C3dC4AdA691E0b09ff8f371bFfE6eFd8C75";
        cluster.oracleProviders[USDT0] = "0x4d7e1Da95A407b28b17715ceCE2f3E1B101ecDFd";
        cluster.oracleProviders[thBILL] = "0x7Dd37Cdb2e44405da3C07d7dD91180F4542AeBc7";
        cluster.oracleProviders[PT_tbBILL_27NOV2025] = "0x1A726be873806c7E6dE55f899ED786ee6915d838";
        cluster.oracleProviders[PT_tbBILL_19FEB2026] = "0xf8Edd8F5b9e7615FBa154E08eddba8fAb4f37f0C";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[USDC] = 100_000_000;
        cluster.supplyCaps[USDT0] = 100_000_000;
        cluster.supplyCaps[thBILL] = 20_000_000;
        cluster.supplyCaps[PT_tbBILL_27NOV2025] = 100_000;
        cluster.supplyCaps[PT_tbBILL_19FEB2026] = 30_000_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[USDC] = 90_000_000;
        cluster.borrowCaps[USDT0] = 90_000_000;
        cluster.borrowCaps[thBILL] = 18_000_000;
        cluster.borrowCaps[PT_tbBILL_27NOV2025] = 0;
        cluster.borrowCaps[PT_tbBILL_19FEB2026] = type(uint256).max;

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(90%)=8.00% APY  Max=25.00% APY
            uint256[4] memory irmUSD = [uint256(0), uint256(630918865),  uint256(10785505476), uint256(3865470566)];

            cluster.kinkIRMParams[USDC]   = irmUSD;
            cluster.kinkIRMParams[USDT0]  = irmUSD;
            cluster.kinkIRMParams[thBILL] = irmUSD;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 30 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.01e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                          0               1       2       3         4
            //                          USDC            USDT    thBILL  PT_thBILL PT_thBILL 
            /* 0  USDC              */ [uint16(0.00e4), 0.95e4, 0.91e4, 0.00e4, 0.00e4],
            /* 1  USDT              */ [uint16(0.95e4), 0.00e4, 0.91e4, 0.00e4, 0.00e4],
            /* 2  thBILL            */ [uint16(0.91e4), 0.91e4, 0.00e4, 0.00e4, 0.00e4],
            /* 3  PT_thBILL_27NOV   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4],
            /* 4  PT_thBILL_19FEB   */ [uint16(0.91e4), 0.91e4, 0.95e4, 0.00e4, 0.00e4]
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
