// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/mainnet/clusters/PrimeCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            WETH,
            wstETH,
            cbETH,
            weETH,
            ezETH,
            RETH,
            rsETH,
            tETH,
            USDC,
            USDT,
            wM,
            USDS,
            sUSDS,
            USDtb,
            rlUSD,
            USDe,
            sUSDe,
            syrupUSDC,
            TBILL,
            WBTC,
            cbBTC,
            LBTC,
            xAUt
        ];
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = governorAddresses.accessControlEmergencyGovernor;
        cluster.vaultsGovernor = governorAddresses.accessControlEmergencyGovernor;

        // define unit of account here
        cluster.unitOfAccount = USD;

        // define fee receiver here and interest fee here. if needed to be defined per asset, populate the feeReceiverOverride and interestFeeOverride mappings
        cluster.feeReceiver = address(0);
        cluster.interestFee = 0.1e4;

        cluster.interestFeeOverride[WETH] = 0;

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

        cluster.oracleProviders[WETH     ] = "ChainlinkOracle";
        cluster.oracleProviders[wstETH   ] = "CrossAdapter=LidoFundamentalOracle+ChainlinkOracle";
        cluster.oracleProviders[cbETH    ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[weETH    ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[ezETH    ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[RETH     ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[rsETH    ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[tETH     ] = "0x74b77011c244bd7edff34e4cbf23fe41defa313d";
        cluster.oracleProviders[USDC     ] = "ChainlinkOracle";
        cluster.oracleProviders[USDT     ] = "ChainlinkOracle";
        cluster.oracleProviders[wM       ] = "FixedRateOracle";
        cluster.oracleProviders[USDS     ] = "ChainlinkOracle";
        cluster.oracleProviders[sUSDS    ] = "ExternalVault|ChainlinkOracle";
        cluster.oracleProviders[USDtb    ] = "FixedRateOracle";
        cluster.oracleProviders[rlUSD    ] = "FixedRateOracle";
        cluster.oracleProviders[USDe     ] = "0x8211B9ae40b06d3Db0215E520F232184Af355378";
        cluster.oracleProviders[sUSDe    ] = "ExternalVault|0x8211B9ae40b06d3Db0215E520F232184Af355378";
        cluster.oracleProviders[syrupUSDC] = "ExternalVault|ChainlinkOracle";
        cluster.oracleProviders[TBILL    ] = "0x3577A7eA55fD30D489640791BA903B6FA278B840";
        cluster.oracleProviders[WBTC     ] = "0x8e8cfcbe490da27032a6edacb6a8436be904cd4e"; // "CrossAdapter=FixedRateOracle+ChainlinkOracle";
        cluster.oracleProviders[cbBTC    ] = "0xd0156a894f2d14b127a8c37360d6879891f62efa"; // "CrossAdapter=FixedRateOracle+ChainlinkOracle";
        cluster.oracleProviders[LBTC     ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[xAUt     ] = "0x6cbca9757201680f65bc10022395c224b490f699";
        
        cluster.oracleProviders[sBUIDL ] = "ExternalVault|0x1CF7192cF739675186653D453828C0A670ed5Cd9";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[WETH       ] = 75_000;
        cluster.supplyCaps[wstETH     ] = 10_000;
        cluster.supplyCaps[cbETH      ] = 30;
        cluster.supplyCaps[weETH      ] = 13_500;
        cluster.supplyCaps[ezETH      ] = 5_000;
        cluster.supplyCaps[RETH       ] = 30;
        cluster.supplyCaps[rsETH      ] = 27_000;
        cluster.supplyCaps[tETH       ] = 9_400;
        cluster.supplyCaps[USDC       ] = 75_000_000;
        cluster.supplyCaps[USDT       ] = 50_000_000;
        cluster.supplyCaps[wM         ] = 100_000;
        cluster.supplyCaps[USDS       ] = 100_000;
        cluster.supplyCaps[sUSDS      ] = 100_000;
        cluster.supplyCaps[USDtb      ] = 20_000_000;
        cluster.supplyCaps[rlUSD      ] = 100_000;
        cluster.supplyCaps[USDe       ] = 100_000;
        cluster.supplyCaps[sUSDe      ] = 100_000;
        cluster.supplyCaps[syrupUSDC  ] = 100_000;
        cluster.supplyCaps[TBILL      ] = 0;//10_000_000;
        cluster.supplyCaps[WBTC       ] = 600;
        cluster.supplyCaps[cbBTC      ] = 500;
        cluster.supplyCaps[LBTC       ] = 300;
        cluster.supplyCaps[xAUt       ] = 300;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[WETH       ] = 67_500;
        cluster.borrowCaps[wstETH     ] = 7_500;
        cluster.borrowCaps[cbETH      ] = 0;
        cluster.borrowCaps[weETH      ] = 3_380;
        cluster.borrowCaps[ezETH      ] = 1_200;
        cluster.borrowCaps[RETH       ] = 0;
        cluster.borrowCaps[rsETH      ] = 6_750;
        cluster.borrowCaps[tETH       ] = 1_600;
        cluster.borrowCaps[USDC       ] = 67_500_000;
        cluster.borrowCaps[USDT       ] = 45_000_000;
        cluster.borrowCaps[wM         ] = 0;
        cluster.borrowCaps[USDS       ] = 0;
        cluster.borrowCaps[sUSDS      ] = 0;
        cluster.borrowCaps[USDtb      ] = 18_000_000;
        cluster.borrowCaps[rlUSD      ] = 0;
        cluster.borrowCaps[USDe       ] = 0;
        cluster.borrowCaps[sUSDe      ] = 0;
        cluster.borrowCaps[syrupUSDC  ] = 0;
        cluster.borrowCaps[TBILL      ] = 0;//type(uint256).max;
        cluster.borrowCaps[WBTC       ] = 510;
        cluster.borrowCaps[cbBTC      ] = 425;
        cluster.borrowCaps[LBTC       ] = 75;
        cluster.borrowCaps[xAUt       ] = type(uint256).max;

        // define IRM classes here and assign them to the assets
        {
            // Base=0.00% APY,  Kink(90.00%)=2.30% APY  Max=40.00% APY
            uint256[4] memory irmETH       = [uint256(0), uint256(186416016),  uint256(23147545444), uint256(3865470566)];

            // Base=0% APY,  Kink(85.00%)=0.50% APY  Max=80.00% APY
            uint256[4] memory irmWSTETH    = [uint256(0), uint256(43292497), uint256(28666371159), uint256(3650722201)];

            // Base=0% APY,  Kink(85%)=1.00% APY  Max=100.00% APY
            uint256[4] memory irmBTC       = [uint256(0), uint256(86370144),  uint256(33604673898), uint256(3650722201)];

            // Base=0% APY,  Kink(40%)=4.60% APY  Max=145.96% APY
            uint256[4] memory irmETH_LST   = [uint256(0), uint256(829546015),  uint256(10514117840), uint256(1717986918)];

            // Base=0% APY,  Kink(25%)=4.60% APY  Max=848.77% APY
            uint256[4] memory irmETH_LRT   = [uint256(0), uint256(1327273625), uint256(21691866441), uint256(1073741824)];

            // Base=0.00% APY,  Kink(90.00%)=6.50% APY  Max=13.00% APY
            uint256[4] memory irmUSD_1     = [uint256(0), uint256(516261061),  uint256(4371001016), uint256(3865470566)];

            // Base=0.00% APY,  Kink(90.00%)=6.50% APY  Max=20.00% APY
            uint256[4] memory irmRLUSD     = [uint256(0), uint256(516261061),  uint256(8805534268), uint256(3865470566)];
            
            // Base=0% APY,  Kink(40%)=2.79% APY  Max=145.96% APY
            uint256[4] memory irmRWA_YLD_1 = [uint256(0), uint256(507574932),  uint256(10728765229), uint256(1717986918)];

            // Base=0% APY,  Kink(85%)=0.60% APY  Max=100.00% APY
            uint256[4] memory irmCBBTC     = [uint256(0), uint256(51925146),  uint256(33799862224), uint256(3650722201)];

            // Base=0% APY,  Kink(25%)=2.50% APY  Max=100.00% APY
            uint256[4] memory irmLBTC      = [uint256(0), uint256(728739169),  uint256(6575907893), uint256(1073741824)];

            cluster.kinkIRMParams[WETH   ] = irmETH;
            cluster.kinkIRMParams[wstETH ] = irmWSTETH;
            cluster.kinkIRMParams[cbETH  ] = irmETH_LST;
            cluster.kinkIRMParams[weETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[ezETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[RETH   ] = irmETH_LST;
            cluster.kinkIRMParams[rsETH  ] = irmETH_LRT;
            cluster.kinkIRMParams[tETH   ] = irmETH_LRT;
            cluster.kinkIRMParams[USDC   ] = irmUSD_1;
            cluster.kinkIRMParams[USDT   ] = irmUSD_1;
            cluster.kinkIRMParams[wM     ] = irmUSD_1;
            cluster.kinkIRMParams[USDS   ] = irmUSD_1;
            cluster.kinkIRMParams[sUSDS  ] = irmRWA_YLD_1;
            cluster.kinkIRMParams[USDtb  ] = irmUSD_1;
            cluster.kinkIRMParams[rlUSD  ] = irmRLUSD;
            cluster.kinkIRMParams[USDe   ] = irmUSD_1;
            cluster.kinkIRMParams[WBTC   ] = irmBTC;
            cluster.kinkIRMParams[cbBTC  ] = irmCBBTC;
            cluster.kinkIRMParams[LBTC   ] = irmLBTC;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 30 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                0               1       2       3       4       5       6       7       8       9       10      11      12      13      14      15      16      17      18      19      20      21      22      23
        //                WETH            wstETH  cbETH   weETH   ezETH   RETH    rsETH   tETH    USDC    USDT    wM      USDS    sUSDS   USDtb   rlUSD   USDe    sUSDe syrupUSDC TBILL   WBTC    cbBTC   LBTC    xAUt    
        /* 0  WETH    */ [uint16(0.00e4), 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.85e4, 0.85e4, 0.00e4, 0.00e4, 0.00e4, 0.85e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.73e4, 0.78e4, 0.78e4, 0.00e4],
        /* 1  wstETH  */ [uint16(0.95e4), 0.00e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.83e4, 0.83e4, 0.00e4, 0.00e4, 0.00e4, 0.87e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.72e4, 0.77e4, 0.77e4, 0.00e4],
        /* 2  cbETH   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 3  weETH   */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.80e4, 0.80e4, 0.00e4, 0.00e4, 0.00e4, 0.80e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.70e4, 0.75e4, 0.75e4, 0.00e4],
        /* 4  ezETH   */ [uint16(0.93e4), 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.00e4, 0.90e4, 0.90e4, 0.77e4, 0.77e4, 0.00e4, 0.00e4, 0.00e4, 0.77e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.67e4, 0.72e4, 0.72e4, 0.00e4],
        /* 5  RETH    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 6  rsETH   */ [uint16(0.93e4), 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.90e4, 0.77e4, 0.77e4, 0.00e4, 0.00e4, 0.00e4, 0.77e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.67e4, 0.72e4, 0.72e4, 0.00e4],
        /* 7  tETH    */ [uint16(0.93e4), 0.93e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4, 0.77e4, 0.77e4, 0.00e4, 0.00e4, 0.00e4, 0.77e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.67e4, 0.72e4, 0.72e4, 0.00e4],
        /* 8  USDC    */ [uint16(0.87e4), 0.83e4, 0.00e4, 0.80e4, 0.80e4, 0.00e4, 0.80e4, 0.80e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.82e4, 0.80e4, 0.80e4, 0.00e4],
        /* 9  USDT    */ [uint16(0.87e4), 0.83e4, 0.00e4, 0.80e4, 0.80e4, 0.00e4, 0.80e4, 0.80e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.82e4, 0.80e4, 0.80e4, 0.00e4],
        /* 10 wM      */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 11 USDS    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 12 sUSDS   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 13 USDtb   */ [uint16(0.87e4), 0.83e4, 0.00e4, 0.80e4, 0.80e4, 0.00e4, 0.80e4, 0.80e4, 0.95e4, 0.95e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.82e4, 0.80e4, 0.80e4, 0.00e4],
        /* 14 rlUSD   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 15 USDe    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 16 sUSDe   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 17syrupUSDC*/ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 18 TBILL   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 19 WBTC    */ [uint16(0.82e4), 0.80e4, 0.00e4, 0.77e4, 0.77e4, 0.00e4, 0.77e4, 0.77e4, 0.86e4, 0.86e4, 0.00e4, 0.00e4, 0.00e4, 0.86e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4],
        /* 20 cbBTC   */ [uint16(0.82e4), 0.80e4, 0.00e4, 0.77e4, 0.77e4, 0.00e4, 0.77e4, 0.77e4, 0.86e4, 0.86e4, 0.00e4, 0.00e4, 0.00e4, 0.86e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.90e4, 0.00e4, 0.90e4, 0.00e4],
        /* 21 LBTC    */ [uint16(0.80e4), 0.78e4, 0.00e4, 0.75e4, 0.75e4, 0.00e4, 0.75e4, 0.75e4, 0.84e4, 0.84e4, 0.00e4, 0.00e4, 0.00e4, 0.84e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4],
        /* 22 xAUt    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.75e4, 0.75e4, 0.00e4, 0.00e4, 0.00e4, 0.75e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
        cluster.externalLTVs = [
        //                       0               1       2       3       4       5       6       7       8       9       10      11      12      13      14      15      16      17      18      19      20      21      22      23
        //                       WETH            wstETH  cbETH   weETH   ezETH   RETH    rsETH   tETH    USDC    USDT    wM      USDS    sUSDS   USDtb   rlUSD   USDe    sUSDe syrupUSDC TBILL   WBTC    cbBTC   LBTC    xAUt    
        /* 1  Escrow wstETH  */ [uint16(0.95e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.87e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  Escrow sUSDS   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.94e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 3  RWA sBUIDL     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.93e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.93e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];
    }

    function postOperations() internal view override {
        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], false);
        }
    }
}
