// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {ManageCluster} from "./ManageCluster.s.sol";
import {OracleVerifier} from "../../../utils/SanityCheckOracle.s.sol";

contract Cluster is ManageCluster {
    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/mainnet/clusters/YieldCluster.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [
            USDC,
            USDT,
            rlUSD,
            USDe,
            eUSDe,
            frxUSD,
            TBILL,
            PT_srUSDe_02APR2026,
            PT_jrUSDe_02APR2026,
            PT_cUSD_23JUL2026,
            PT_stcUSD_23JUL2026
        ];
    }

    function configureCluster() internal override {

        // define the governors here
        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = multisigAddresses.DAO; //governorAddresses.accessControlEmergencyGovernor;

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
        cluster.oracleProviders[USDC                     ] = "0x6213f24332D35519039f2afa7e3BffE105a37d3F";
        cluster.oracleProviders[USDT                     ] = "0x587CABe0521f5065b561A6e68c25f338eD037FF9";
        cluster.oracleProviders[rlUSD                    ] = "0x3bDcB804Fd42Ccb2B7Cf329fa07724bEcB872970";
        cluster.oracleProviders[USDe                     ] = "0x93840A424aBc32549809Dd0Bc07cEb56E137221C";
        cluster.oracleProviders[eUSDe                    ] = "ExternalVault|0x93840A424aBc32549809Dd0Bc07cEb56E137221C";
        cluster.oracleProviders[frxUSD                   ] = "0x252e25BD698EA17945419A705a783242e1e656a7";
        cluster.oracleProviders[TBILL                    ] = "0x3577A7eA55fD30D489640791BA903B6FA278B840";
        cluster.oracleProviders[PT_srUSDe_02APR2026      ] = "0xb0BAa4DC6AF4f2C1541Ee4eA4AfE01A4183254F0";
        cluster.oracleProviders[PT_jrUSDe_02APR2026      ] = "0x566C246475B853B7DaFf705ad5c5E78753EeF5Dd";
        cluster.oracleProviders[PT_cUSD_23JUL2026        ] = "0x15dd2dd913bb1d0925323e194e01d78d186838ec";
        cluster.oracleProviders[PT_stcUSD_23JUL2026      ] = "0x55edbe218bb9744729c65a3c58b571a05d1dcb36";
        
        cluster.oracleProviders[sBUIDL                   ] = "ExternalVault|0x1CF7192cF739675186653D453828C0A670ed5Cd9";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
        cluster.supplyCaps[USDC                     ] = 300_000_000;
        cluster.supplyCaps[USDT                     ] = 100_000_000;
        cluster.supplyCaps[rlUSD                    ] = 100_000_000;
        cluster.supplyCaps[USDe                     ] = 700_000;
        cluster.supplyCaps[eUSDe                    ] = 100_000;
        cluster.supplyCaps[frxUSD                   ] = 100_000;
        cluster.supplyCaps[TBILL                    ] = 0;
        cluster.supplyCaps[PT_srUSDe_02APR2026      ] = 0;
        cluster.supplyCaps[PT_jrUSDe_02APR2026      ] = 0;
        cluster.supplyCaps[PT_cUSD_23JUL2026        ] = 1_000_000;
        cluster.supplyCaps[PT_stcUSD_23JUL2026      ] = 0;

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
        cluster.borrowCaps[USDC                     ] = 270_000_000;
        cluster.borrowCaps[USDT                     ] = 75_000_000;
        cluster.borrowCaps[rlUSD                    ] = 90_000_000;
        cluster.borrowCaps[USDe                     ] = 630_000;
        cluster.borrowCaps[eUSDe                    ] = 90_000;
        cluster.borrowCaps[frxUSD                   ] = 0;
        cluster.borrowCaps[TBILL                    ] = 0;
        cluster.borrowCaps[PT_srUSDe_02APR2026      ] = 0;
        cluster.borrowCaps[PT_jrUSDe_02APR2026      ] = 0;
        cluster.borrowCaps[PT_cUSD_23JUL2026        ] = type(uint256).max;
        cluster.borrowCaps[PT_stcUSD_23JUL2026      ] = 0;

        // define IRM classes here and assign them to the assets
        {
            // Base=0.00% APY,  Kink(90.00%)=6.00% APY  Max=40.00% APY
            uint256[4] memory irm_USD_1_MEGA_YIELD = [uint256(0), uint256(477682641), uint256(20526145828), uint256(3865470566)];

            cluster.kinkIRMParams[USDC        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USDT        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[rlUSD       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[USDe        ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[eUSDe       ] = irm_USD_1_MEGA_YIELD;
            cluster.kinkIRMParams[frxUSD      ] = irm_USD_1_MEGA_YIELD;
        }

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 30 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;

        cluster.spreadLTVOverride[6][5] = 0.01e4; // eUSDe/USDe
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
        //                                  0               1       2       3       4        5       6        7       8       9       10
        //                                  USDC            USDT    rlUSD   USDe    eUSDe   frxUSD  TBILL   PT_srUSDe_02APR2026 PT_jrUSDe_02APR2026 PT_cUSD_23JUL2026 PT_stcUSD_23JUL2026
        /* 0  USDC                      */ [uint16(0.00e4), 0.96e4, 0.96e4, 0.96e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  USDT                      */ [uint16(0.96e4), 0.00e4, 0.96e4, 0.96e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  rlUSD                     */ [uint16(0.96e4), 0.96e4, 0.00e4, 0.96e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 3  USDe                      */ [uint16(0.92e4), 0.92e4, 0.92e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 4  eUSDe                     */ [uint16(0.90e4), 0.90e4, 0.90e4, 0.94e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 5  frxUSD                    */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 6  TBILL                     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 7  PT_srUSDe_02APR2026       */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 8  PT_jrUSDe_02APR2026       */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 9  PT_cUSD_23JUL2026         */ [uint16(0.87e4), 0.87e4, 0.87e4, 0.87e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 10 PT_stcUSD_23JUL2026       */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];

        // define external ltvs here. columns are liability vaults, rows are collateral vaults.
        // double check the order of collaterals against the order of externalVaults in the addresses file
        cluster.externalLTVs = [
        //                                  0                1       2      3       4       5       6       7       8       9       10
        //                                  USDC            USDT    rlUSD   USDe    eUSDe   frxUSD  TBILL   PT_srUSDe_02APR2026 PT_jrUSDe_02APR2026 PT_cUSD_23JUL2026 PT_stcUSD_23JUL2026
        /* 0  Prime USDC                */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 1  Prime USDT                */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  RWA sBUIDL                */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];
    }

    function postOperations() internal view override {
        //for (uint256 i = 0; i < cluster.vaults.length; ++i) {
        //    OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], cluster.vaults, false);
        //}
    }
}
