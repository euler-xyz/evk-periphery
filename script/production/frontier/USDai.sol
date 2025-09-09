// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ManageCluster} from "./ManageCluster.s.sol";

contract Cluster is ManageCluster {
    address internal constant USDai  = 0x0A1a1A107E45b7Ced86833863f482BC5f4ed82EF;
    address internal constant sUSDai = 0x0B2b2B2076d95dda7817e785989fE353fe955ef9;
    address internal constant USDe   = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34;
    address internal constant PT_USDai  = 0x8b4Ca42bB3B1d789859f106222CF7DC5EEd48CCb;
    address internal constant PT_sUSDai = 0x936F210d277bf489A3211CeF9AB4BC47a7B69C96;

    function defineCluster() internal override {
        // define the path to the cluster addresses file here
        cluster.clusterAddressesPath = "/script/production/frontier/USDai.json";

        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other
        // arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as
        // needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [USDC, USDT, USDai, sUSDai, USDe, PT_USDai, PT_sUSDai];
    }

    function configureCluster() internal override {
        super.configureCluster();

        cluster.oracleRoutersGovernor = cluster.vaultsGovernor = 0x060DB084bF41872861f175d83f3cb1B5566dfEA3;

        // define unit of account here
        cluster.unitOfAccount = USD;

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
        cluster.oracleProviders[USDC  ] = "0xEeB17ddb1B604c22d878e2b2a90B2Bf4E7d36641";
        cluster.oracleProviders[USDT  ] = "0x3b24485168B448ED1da471265c3Bc4fBAaC4a2ab";
        cluster.oracleProviders[USDai ] = "0xae80AadE8Ff7cc7fE8493338898073fB1A4FB057";
        cluster.oracleProviders[sUSDai] = "ExternalVault|0xae80AadE8Ff7cc7fE8493338898073fB1A4FB057";
        cluster.oracleProviders[USDe  ] = "0xD76802F99c339D3085C59027dDD9D4AE4957a651";
        cluster.oracleProviders[PT_USDai ] = "0x394ad562f638c80917b01be6ffe63c858104ed46";
        cluster.oracleProviders[PT_sUSDai] = "0x83bAB8b13cb87Ab7f80Fece53F340F0714CeFeeF";


        // define IRM classes here and assign them to the assets or refer to the adaptive IRM address directly
        {
            // Base=0% APY  Kink(90%)=9.5% APY  Max=70.00% APY
            uint256[4] memory irm = [uint256(0), uint256(743995130), uint256(32454376574), uint256(3865470566)];

            cluster.kinkIRMParams[USDC] = irm;
            cluster.kinkIRMParams[USDT] = irm;
            cluster.kinkIRMParams[USDe] = irm;
        }

        cluster.supplyCaps[USDC  ] = 50_000_000;
        cluster.supplyCaps[USDT  ] = 50_000_000;
        cluster.supplyCaps[USDai ] = 50_000_000;
        cluster.supplyCaps[sUSDai] = 50_000_000;
        cluster.supplyCaps[USDe  ] = 50_000_000;
        cluster.supplyCaps[PT_USDai ] = 10_000_000;
        cluster.supplyCaps[PT_sUSDai] = 5_000_000;

        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [
            //                0          1         2         3         4         5         6
            //                USDC       USDT      USDai     sUSDai    USDe      PT_USDai  PT_sUSDai
            /* 0  USDC     */ [LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 1  USDT     */ [LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 2  USDai    */ [0.940e4,  0.905e4,  LTV_ZERO, LTV_ZERO, 0.905e4,  LTV_ZERO, LTV_ZERO],
            /* 3  sUSDai   */ [0.850e4,  0.800e4,  LTV_ZERO, LTV_ZERO, 0.800e4,  LTV_ZERO, LTV_ZERO],
            /* 4  USDe     */ [LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 5  PT_USDai */ [0.915e4,  0.880e4,  LTV_ZERO, LTV_ZERO, 0.880e4,  LTV_ZERO, LTV_ZERO],
            /* 6  PT_sUSDai*/ [0.800e4,  0.750e4,  LTV_ZERO, LTV_ZERO, 0.750e4,  LTV_ZERO, LTV_ZERO]
        ];

        cluster.borrowLTVsOverride = [
            //                0          1         2         3         4         5         6
            //                USDC       USDT      USDai     sUSDai    USDe      PT_USDai  PT_sUSDai
            /* 0  USDC     */ [LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 1  USDT     */ [LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 2  USDai    */ [0.915e4,  0.880e4,  LTV_ZERO, LTV_ZERO, 0.880e4,  LTV_ZERO, LTV_ZERO],
            /* 3  sUSDai   */ [0.800e4,  0.750e4,  LTV_ZERO, LTV_ZERO, 0.750e4,  LTV_ZERO, LTV_ZERO],
            /* 4  USDe     */ [LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO, LTV_ZERO],
            /* 5  PT_USDai */ [0.880e4,  0.845e4,  LTV_ZERO, LTV_ZERO, 0.845e4,  LTV_ZERO, LTV_ZERO],
            /* 6  PT_sUSDai*/ [0.750e4,  0.700e4,  LTV_ZERO, LTV_ZERO, 0.700e4,  LTV_ZERO, LTV_ZERO]
        ];
    }
}
