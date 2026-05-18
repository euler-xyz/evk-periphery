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

        //vm.prank(multisigAddresses.DAO);
        //(bool success,) = coreAddresses.evc.call(hex"c16ae7a40000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000018000000000000000000000000000000000000000000000000000000000000002c000000000000000000000000000000000000000000000000000000000000003a000000000000000000000000000000000000000000000000000000000000004e00000000000000000000000000000000000000000000000000000000000000620000000000000000000000000000000000000000000000000000000000000076000000000000000000000000000000000000000000000000000000000000008a000000000000000000000000000000000000000000000000000000000000009800000000000000000000000000000000000000000000000000000000000000ac00000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000ce00000000000000000000000000000000000000000000000000000000000000e20000000000000000000000000d8b27cf359b7d15710a5be299af6e7bf904984c2000000000000000000000000cad001c30e96765ac90307669d578219d4fb1dce0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000844bca3d5b000000000000000000000000f6e2efdf175e7a91c8847dade42f2d39a9ae57d4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000093a8000000000000000000000000000000000000000000000000000000000000000000000000000000000797dd80692c3b2dadabce8e30c07fde5307d48a9000000000000000000000000cad001c30e96765ac90307669d578219d4fb1dce0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000248bcd40160000000000000000000000004bfdd866bb92cda334493a7036d554c2c80ad98500000000000000000000000000000000000000000000000000000000000000000000000000000000797dd80692c3b2dadabce8e30c07fde5307d48a9000000000000000000000000cad001c30e96765ac90307669d578219d4fb1dce0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000844bca3d5b000000000000000000000000a96b72470f4193a4e637de8bcc6a009d1dd360a2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000093a8000000000000000000000000000000000000000000000000000000000000000000000000000000000797dd80692c3b2dadabce8e30c07fde5307d48a9000000000000000000000000cad001c30e96765ac90307669d578219d4fb1dce0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000844bca3d5b000000000000000000000000f6e2efdf175e7a91c8847dade42f2d39a9ae57d4000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000093a8000000000000000000000000000000000000000000000000000000000000000000000000000000000797dd80692c3b2dadabce8e30c07fde5307d48a9000000000000000000000000cad001c30e96765ac90307669d578219d4fb1dce0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000844bca3d5b000000000000000000000000e3ca8369346a35b0633da9a4eb48394478c8bec2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000093a8000000000000000000000000000000000000000000000000000000000000000000000000000000000797dd80692c3b2dadabce8e30c07fde5307d48a9000000000000000000000000cad001c30e96765ac90307669d578219d4fb1dce0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000844bca3d5b000000000000000000000000c51e90b48fd7fbff316502b85a71e0ebb1ee5238000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000093a8000000000000000000000000000000000000000000000000000000000000000000000000000000000313603fa690301b0caeef8069c065862f9162162000000000000000000000000cad001c30e96765ac90307669d578219d4fb1dce0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000248bcd40160000000000000000000000004bfdd866bb92cda334493a7036d554c2c80ad98500000000000000000000000000000000000000000000000000000000000000000000000000000000313603fa690301b0caeef8069c065862f9162162000000000000000000000000cad001c30e96765ac90307669d578219d4fb1dce0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000844bca3d5b000000000000000000000000a96b72470f4193a4e637de8bcc6a009d1dd360a2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000093a8000000000000000000000000000000000000000000000000000000000000000000000000000000000313603fa690301b0caeef8069c065862f9162162000000000000000000000000cad001c30e96765ac90307669d578219d4fb1dce0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000844bca3d5b000000000000000000000000c51e90b48fd7fbff316502b85a71e0ebb1ee5238000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000093a8000000000000000000000000000000000000000000000000000000000000000000000000000000000328646cdfbad730432620d845b8f5a2f7d786c01000000000000000000000000cad001c30e96765ac90307669d578219d4fb1dce0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000248bcd40160000000000000000000000004bfdd866bb92cda334493a7036d554c2c80ad98500000000000000000000000000000000000000000000000000000000000000000000000000000000328646cdfbad730432620d845b8f5a2f7d786c01000000000000000000000000cad001c30e96765ac90307669d578219d4fb1dce0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000844bca3d5b000000000000000000000000a96b72470f4193a4e637de8bcc6a009d1dd360a2000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000093a8000000000000000000000000000000000000000000000000000000000000000000000000000000000328646cdfbad730432620d845b8f5a2f7d786c01000000000000000000000000cad001c30e96765ac90307669d578219d4fb1dce0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000844bca3d5b000000000000000000000000c51e90b48fd7fbff316502b85a71e0ebb1ee5238000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000093a8000000000000000000000000000000000000000000000000000000000");
        //require(success,"failure");
    }

    function configureCluster() internal override {
        // define the governors here
        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = multisigAddresses.DAO;// governorAddresses.accessControlEmergencyGovernor;

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
        cluster.oracleProviders[weETH    ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[ezETH    ] = "CrossAdapter=RateProviderOracle+ChainlinkOracle";
        cluster.oracleProviders[rsETH    ] = "0xc4406E4a14D2c0378952649BF56716A39CE64c6B";
        cluster.oracleProviders[tETH     ] = "0x74b77011c244bd7edff34e4cbf23fe41defa313d";
        cluster.oracleProviders[USDC     ] = "ChainlinkOracle";
        cluster.oracleProviders[USDT     ] = "ChainlinkOracle";
        cluster.oracleProviders[USDtb    ] = "FixedRateOracle";
        cluster.oracleProviders[TBILL    ] = "0x3577A7eA55fD30D489640791BA903B6FA278B840";
        cluster.oracleProviders[WBTC     ] = "0x8e8cfcbe490da27032a6edacb6a8436be904cd4e"; // "CrossAdapter=FixedRateOracle+ChainlinkOracle";
        cluster.oracleProviders[cbBTC    ] = "0xd0156a894f2d14b127a8c37360d6879891f62efa"; // "CrossAdapter=FixedRateOracle+ChainlinkOracle";
        cluster.oracleProviders[LBTC     ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[xAUt     ] = "0x6cbca9757201680f65bc10022395c224b490f699";
        
        cluster.oracleProviders[sBUIDL ] = "ExternalVault|0x1CF7192cF739675186653D453828C0A670ed5Cd9";

        // define supply caps here. 0 means no supply can occur, type(uint256).max means no cap defined hence max amount
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

        // define borrow caps here. 0 means no borrow can occur, type(uint256).max means no cap defined hence max amount
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

        // define IRM classes here and assign them to the assets
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

        // define the ramp duration to be used, in case the liquidation LTVs have to be ramped down
        cluster.rampDuration = 14 days;

        // define the spread between borrow and liquidation ltv
        cluster.spreadLTV = 0.02e4;
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
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

        // define external ltvs here. columns are liability vaults, rows are collateral vaults. 
        // double check the order of collaterals against the order of externalVaults in the addresses file
        cluster.externalLTVs = [
        //                       0               1       2       3       4       5       6       7       8       9       10      11      12      13
        //                       WETH            wstETH  weETH   ezETH   rsETH   tETH    USDC    USDT    USDtb   TBILL   WBTC    cbBTC   LBTC    xAUt    
        /* 1  Escrow wstETH  */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 2  Escrow sUSDS   */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4],
        /* 3  RWA sBUIDL     */ [uint16(0.00e4), 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4, 0.00e4]
        ];
    }

    function postOperations() internal view override {
        //for (uint256 i = 0; i < cluster.vaults.length; ++i) {
        //    OracleVerifier.verifyOracleConfig(lensAddresses.oracleLens, cluster.vaults[i], cluster.vaults, false);
        //}
    }
}
