// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        cluster.clusterAddressesPath = "/script/production/mainnet/clusters/PrimeCluster.json";

        // The other arrays and the LTV matrices follow this order, so don't reorder it. An asset may be listed more than
        // once to deploy several vaults for it, but the per-asset mappings are keyed by asset address.
        cluster.assets = [
            WETH,
            wstETH,
            weETH,
            ezETH,
            rsETH,
            tETH,
            USDC,
            USDT,
            USDtb,
            TBILL,
            WBTC,
            cbBTC,
            LBTC,
            xAUt
        ];
    }

    function configureCluster() internal override {
        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = multisigAddresses.DAO;

        cluster.unitOfAccount = USD;

        // Per-asset exceptions to the values below go in the matching *Override mapping.
        cluster.feeReceiver = address(0);
        cluster.interestFee = 0.1e4;
        cluster.interestFeeOverride[WETH] = 0;
        cluster.maxLiquidationDiscount = 0.15e4;
        cluster.liquidationCoolOffTime = 1;
        cluster.hookTarget = address(0);
        cluster.hookedOps = 0;
        cluster.configFlags = 0;

        // Oracle providers are adapter names as returned by the adapter's `name()`, or an adapter address.
        // - Cross adapters: "CrossAdapter=<adapterName1>+<adapterName2>".
        // - RedStone Classic adapters return "ChainlinkOracle" but are named "RedstoneClassicOracle" here.
        // - An asset that is itself an ERC4626 vault recognised by the External Vaults Registry takes the
        //   "ExternalVault|" prefix, so the router resolves the vault.
        cluster.oracleProviders[WETH     ] = "ChainlinkOracle";
        cluster.oracleProviders[wstETH   ] = "CrossAdapter=LidoFundamentalOracle+ChainlinkOracle";
        cluster.oracleProviders[weETH    ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[ezETH    ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[rsETH    ] = "0xc4406E4a14D2c0378952649BF56716A39CE64c6B";
        cluster.oracleProviders[tETH     ] = "0x74b77011c244bd7edff34e4cbf23fe41defa313d";
        cluster.oracleProviders[USDC     ] = "ChainlinkOracle";
        cluster.oracleProviders[USDT     ] = "ChainlinkOracle";
        cluster.oracleProviders[USDtb    ] = "FixedRateOracle";
        cluster.oracleProviders[TBILL    ] = "0x3577A7eA55fD30D489640791BA903B6FA278B840";
        cluster.oracleProviders[WBTC     ] = "0x8e8cfcbe490da27032a6edacb6a8436be904cd4e";
        cluster.oracleProviders[cbBTC    ] = "0xd0156a894f2d14b127a8c37360d6879891f62efa";
        cluster.oracleProviders[LBTC     ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[xAUt     ] = "0x6cbca9757201680f65bc10022395c224b490f699";

        // Caps are in whole tokens. 0 allows no supply or borrowing; type(uint256).max means no cap.
        cluster.supplyCaps[WETH       ] = 75_000;
        cluster.supplyCaps[wstETH     ] = 10_000;
        cluster.supplyCaps[weETH      ] = 1_500;
        cluster.supplyCaps[ezETH      ] = 0;
        cluster.supplyCaps[rsETH      ] = 0;
        cluster.supplyCaps[tETH       ] = 1_500;
        cluster.supplyCaps[USDC       ] = 75_000_000;
        cluster.supplyCaps[USDT       ] = 50_000_000;
        cluster.supplyCaps[USDtb      ] = 10_000_000;
        cluster.supplyCaps[TBILL      ] = 0;
        cluster.supplyCaps[WBTC       ] = 600;
        cluster.supplyCaps[cbBTC      ] = 500;
        cluster.supplyCaps[LBTC       ] = 10;
        cluster.supplyCaps[xAUt       ] = 300;

        cluster.borrowCaps[WETH       ] = 67_500;
        cluster.borrowCaps[wstETH     ] = 7_500;
        cluster.borrowCaps[weETH      ] = 0;
        cluster.borrowCaps[ezETH      ] = 0;
        cluster.borrowCaps[rsETH      ] = 0;
        cluster.borrowCaps[tETH       ] = 0;
        cluster.borrowCaps[USDC       ] = 67_500_000;
        cluster.borrowCaps[USDT       ] = 45_000_000;
        cluster.borrowCaps[USDtb      ] = 9_000_000;
        cluster.borrowCaps[TBILL      ] = 0;
        cluster.borrowCaps[WBTC       ] = 510;
        cluster.borrowCaps[cbBTC      ] = 425;
        cluster.borrowCaps[LBTC       ] = 0;
        cluster.borrowCaps[xAUt       ] = type(uint256).max;

        {
            // Base=0.00% APY,  Kink(90.00%)=2.30% APY  Max=40.00% APY
            uint256[4] memory irmETH       = [uint256(0), uint256(186416016),  uint256(23147545444), uint256(3865470566)];

            // Base=0% APY,  Kink(85.00%)=0.50% APY  Max=80.00% APY
            uint256[4] memory irmWSTETH    = [uint256(0), uint256(43292497), uint256(28666371159), uint256(3650722201)];

            // Base=0% APY,  Kink(85%)=1.00% APY  Max=100.00% APY
            uint256[4] memory irmBTC       = [uint256(0), uint256(86370144),  uint256(33604673898), uint256(3650722201)];

            // Base=0% APY,  Kink(25%)=4.60% APY  Max=848.77% APY
            uint256[4] memory irmETH_LRT   = [uint256(0), uint256(1327273625), uint256(21691866441), uint256(1073741824)];

            // Base=0.00% APY,  Kink(90.00%)=6.50% APY  Max=40.00% APY
            uint256[4] memory irmUSD_1     = [uint256(0), uint256(516261061),  uint256(20178940043), uint256(3865470566)];

            // Base=0% APY,  Kink(85%)=0.60% APY  Max=100.00% APY
            uint256[4] memory irmCBBTC     = [uint256(0), uint256(51925146),  uint256(33799862224), uint256(3650722201)];

            // Base=0% APY,  Kink(25%)=2.50% APY  Max=100.00% APY
            uint256[4] memory irmLBTC      = [uint256(0), uint256(728739169),  uint256(6575907893), uint256(1073741824)];

            cluster.kinkIRMParams[WETH   ] = irmETH;
            cluster.kinkIRMParams[wstETH ] = irmWSTETH;
            cluster.kinkIRMParams[weETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[ezETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[rsETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[tETH   ] = irmETH_LRT;
            cluster.kinkIRMParams[USDC   ] = irmUSD_1;
            cluster.kinkIRMParams[USDT   ] = irmUSD_1;
            cluster.kinkIRMParams[USDtb  ] = irmUSD_1;
            cluster.kinkIRMParams[WBTC   ] = irmBTC;
            cluster.kinkIRMParams[cbBTC  ] = irmCBBTC;
            cluster.kinkIRMParams[LBTC   ] = irmLBTC;
        }

        // A lowered liquidation LTV ramps down over this period.
        cluster.rampDuration = 14 days;

        // Borrow LTV is the liquidation LTV minus this spread.
        cluster.spreadLTV = 0.02e4;

        // Liquidation LTVs: rows are collateral vaults, columns are liability vaults.
        cluster.ltvs = [
        //                0               1       2       3       4       5       6       7       8       9       10      11      12      13
        //                WETH            wstETH  weETH   ezETH   rsETH   tETH    USDC    USDT    USDtb   TBILL   WBTC    cbBTC   LBTC    xAUt
        /* 0  WETH    */ [uint16(0.00e4), 0.94e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.86e4, 0.86e4, 0.86e4, 0.00e4, 0.75e4, 0.80e4, 0.00e4, 0.00e4],
        /* 1  wstETH  */ [uint16(0.96e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.84e4, 0.84e4, 0.88e4, 0.00e4, 0.74e4, 0.79e4, 0.00e4, 0.00e4],
        /* 2  weETH   */ [uint16(0.94e4), 0.94e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.82e4, 0.82e4, 0.82e4, 0.00e4, 0.72e4, 0.77e4, 0.00e4, 0.00e4],
        /* 3  ezETH   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 4  rsETH   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 5  tETH    */ [uint16(0.94e4), 0.94e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.77e4, 0.77e4, 0.77e4, 0.00e4, 0.69e4, 0.74e4, 0.00e4, 0.00e4],
        /* 6  USDC    */ [uint16(0.87e4), 0.83e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.96e4, 0.96e4, 0.00e4, 0.84e4, 0.82e4, 0.00e4, 0.00e4],
        /* 7  USDT    */ [uint16(0.87e4), 0.83e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.96e4, 0.00e4, 0.96e4, 0.00e4, 0.84e4, 0.82e4, 0.00e4, 0.00e4],
        /* 8  USDtb   */ [uint16(0.87e4), 0.83e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.96e4, 0.96e4, 0.00e4, 0.00e4, 0.84e4, 0.82e4, 0.00e4, 0.00e4],
        /* 9  TBILL   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 10 WBTC    */ [uint16(0.84e4), 0.82e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.86e4, 0.86e4, 0.86e4, 0.00e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4],
        /* 11 cbBTC   */ [uint16(0.84e4), 0.82e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.86e4, 0.86e4, 0.86e4, 0.00e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4],
        /* 12 LBTC    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 13 xAUt    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.77e4, 0.77e4, 0.77e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];

        // Liquidation LTVs of external collateral vaults, in the order of externalVaults in the cluster JSON.
        cluster.externalLTVs = [
        //                       0               1       2       3       4       5       6       7       8       9       10      11      12      13
        //                       WETH            wstETH  weETH   ezETH   rsETH   tETH    USDC    USDT    USDtb   TBILL   WBTC    cbBTC   LBTC    xAUt
        /* 0  Escrow wstETH  */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  Escrow sUSDS   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];
    }

    function postOperations() internal view override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], cluster.vaults, false);
        }
    }
}
