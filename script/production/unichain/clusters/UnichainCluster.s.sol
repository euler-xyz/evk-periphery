// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/unichain/clusters/UnichainCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            USDC,
            USDT0,
            sUSDC,
            WETH,
            wstETH,
            weETH,
            rsETH,
            ezETH,
            WBTC,
            UNI
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
        // External Vaults Registry, the string should be preceded by "ExternalVault|" prefix. this is in order to resolve 
        // the asset (vault) in the oracle router.
        // in case the adapter is not present in the Adapter Registry, the adapter address can be passed instead in form of a string.
        cluster.oracleProviders[USDC  ] = "0xd544ccb6f2231bd1ccac0258cba89e8a13d4a421";
        cluster.oracleProviders[USDT0 ] = "0x5939ee098eb6d411c3727b78ee665771f5cb0501";
        cluster.oracleProviders[sUSDC ] = "ExternalVault|0xd544ccb6f2231bd1ccac0258cba89e8a13d4a421";
        cluster.oracleProviders[WETH  ] = "0xf5c2dfd1740d18ad7cf23fba76cc11d877802937";
        cluster.oracleProviders[wstETH] = "0xfc40b9415ff4591ec304f3c18509a6dc28c408ca";
        cluster.oracleProviders[weETH ] = "0xf7129a6280dcfff6149792186b54c818ea4d80d6";
        cluster.oracleProviders[rsETH ] = "0xbad0e1da7d39a21455acef570cf9f3a8881f5e23";
        cluster.oracleProviders[ezETH ] = "0xf2b8616744502851343c52da76e9adfb97f08b91";
        cluster.oracleProviders[WBTC  ] = "0x997d72fb46690f304c7db92df9aa823323fb23b2";
        cluster.oracleProviders[UNI   ] = "0x7e262cd6226328aaf4ea5c993a952e18dd633bc8";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[USDC  ] = 150_000_000;
        cluster.supplyCaps[USDT0 ] = 100_000_000;
        cluster.supplyCaps[sUSDC ] = 80_000_000;
        cluster.supplyCaps[WETH  ] = 15_000;
        cluster.supplyCaps[wstETH] = 1_130;
        cluster.supplyCaps[weETH ] = 22_500;
        cluster.supplyCaps[rsETH ] = 750;
        cluster.supplyCaps[ezETH ] = 1_500;
        cluster.supplyCaps[WBTC  ] = 100;
        cluster.supplyCaps[UNI   ] = 125_000;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[USDC  ] = 135_000_000;
        cluster.borrowCaps[USDT0 ] = 90_000_000;
        cluster.borrowCaps[sUSDC ] = 64_000_000;
        cluster.borrowCaps[WETH  ] = 13_500;
        cluster.borrowCaps[wstETH] = 290;
        cluster.borrowCaps[weETH ] = 9_000;
        cluster.borrowCaps[rsETH ] = 190;
        cluster.borrowCaps[ezETH ] = 375;
        cluster.borrowCaps[WBTC  ] = 90;
        cluster.borrowCaps[UNI   ] = 100_000;

        // define IRM classes here and assign them to the assets
        {
            // Base=0.00% APY,  Kink(90.00%)=6.50% APY  Max=40.00% APY
            uint256[4] memory irmUSD  = [uint256(0), uint256(516261061),  uint256(20178940043), uint256(3865470566)];

            // Base=0.00% APY,  Kink(80.00%)=2.00% APY  Max=40.00% APY
            uint256[4] memory irmSUSDC= [uint256(0), uint256(182632435),  uint256(11682115056), uint256(3435973836)];

            // Base=0.00% APY,  Kink(90.00%)=2.70% APY  Max=40.00% APY
            uint256[4] memory irmWETH = [uint256(0), uint256(218407859),  uint256(22859618857), uint256(3865470566)];

            // Base=0.00% APY,  Kink(40.00%)=1.00% APY  Max=80.00% APY
            uint256[4] memory irmWEETH = [uint256(0), uint256(183536557),  uint256(7105566128), uint256(1717986918)];

            // Base=0% APY  Kink(25%)=0.50% APY  Max=80.00% APY
            uint256[4] memory irmLST  = [uint256(0), uint256(147194492),  uint256(5733274237), uint256(1073741824)];

            // Base=0% APY  Kink(90%)=1.00% APY  Max=80.00% APY
            uint256[4] memory irmBTC  = [uint256(0), uint256(81571803),  uint256(42633396738), uint256(3865470566)];

            // Base=0% APY  Kink(80%)=5.00% APY  Max=80.00% APY
            uint256[4] memory irmUNI  = [uint256(0), uint256(449973958),  uint256(19883875652), uint256(3435973836)];

            cluster.kinkIRMParams[USDC  ] = irmUSD;
            cluster.kinkIRMParams[USDT0 ] = irmUSD;
            cluster.kinkIRMParams[sUSDC ] = irmSUSDC;
            cluster.kinkIRMParams[WETH  ] = irmWETH;
            cluster.kinkIRMParams[wstETH] = irmLST;
            cluster.kinkIRMParams[weETH ] = irmWEETH;
            cluster.kinkIRMParams[rsETH ] = irmLST;
            cluster.kinkIRMParams[ezETH ] = irmLST;
            cluster.kinkIRMParams[WBTC  ] = irmBTC;
            cluster.kinkIRMParams[UNI   ] = irmUNI;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 1 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0               1       2       3       4       5       6       7       8       9
        //                USDC            USDT0   sUSDC   WETH    wstETH  weETH   rsETH   ezETH   WBTC    UNI
        /* 0  USDC    */ [uint16(0.00e4), 0.96e4, 0.96e4, 0.86e4, 0.84e4, 0.83e4, 0.82e4, 0.82e4, 0.86e4, 0.68e4],
        /* 1  USDT0   */ [uint16(0.96e4), 0.00e4, 0.93e4, 0.86e4, 0.84e4, 0.83e4, 0.82e4, 0.82e4, 0.86e4, 0.68e4],
        /* 2  sUSDC   */ [uint16(0.96e4), 0.94e4, 0.00e4, 0.84e4, 0.82e4, 0.81e4, 0.80e4, 0.80e4, 0.84e4, 0.66e4],
        /* 3  WETH    */ [uint16(0.86e4), 0.86e4, 0.84e4, 0.00e4, 0.95e4, 0.94e4, 0.93e4, 0.93e4, 0.80e4, 0.63e4],
        /* 4  wstETH  */ [uint16(0.84e4), 0.84e4, 0.82e4, 0.95e4, 0.00e4, 0.93e4, 0.92e4, 0.92e4, 0.79e4, 0.62e4],
        /* 5  weETH   */ [uint16(0.83e4), 0.83e4, 0.81e4, 0.94e4, 0.93e4, 0.00e4, 0.91e4, 0.91e4, 0.78e4, 0.61e4],
        /* 6  rsETH   */ [uint16(0.82e4), 0.82e4, 0.80e4, 0.93e4, 0.92e4, 0.91e4, 0.00e4, 0.91e4, 0.77e4, 0.60e4],
        /* 7  ezETH   */ [uint16(0.82e4), 0.82e4, 0.80e4, 0.93e4, 0.92e4, 0.91e4, 0.91e4, 0.00e4, 0.77e4, 0.60e4],
        /* 8  WBTC    */ [uint16(0.86e4), 0.86e4, 0.84e4, 0.80e4, 0.79e4, 0.78e4, 0.77e4, 0.77e4, 0.00e4, 0.63e4],
        /* 9  UNI     */ [uint16(0.68e4), 0.68e4, 0.66e4, 0.63e4, 0.62e4, 0.61e4, 0.60e4, 0.60e4, 0.63e4, 0.00e4]
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
