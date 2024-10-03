// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder} from "../../../utils/ScriptUtils.s.sol";
import {IRMLens} from "../../../../src/Lens/IRMLens.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";
import "../../../../src/Lens/LensTypes.sol";

contract BaseMegaCluster is BatchBuilder {
    // do not change below addresses
    address internal constant USD     = address(840);
    address internal constant WETH    = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant wstETH  = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant cbETH   = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address internal constant WEETH   = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant ezETH   = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
    address internal constant RETH    = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address internal constant METH    = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa;
    address internal constant RSETH   = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
    address internal constant sfrxETH = 0xac3E018457B222d93114458476f3E3416Abbe38F;
    address internal constant ETHx    = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b;
    address internal constant rswETH  = 0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0;
    address internal constant USDC    = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT    = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address internal constant PYUSD   = 0x6c3ea9036406852006290770BEdFcAbA0e23A0e8;
    address internal constant USDY    = 0x96F6eF951840721AdBF46Ac996b59E0235CB985C;
    address internal constant wM      = 0x437cc33344a0B27A429f795ff6B469C72698B291;
    address internal constant mTBILL  = 0xDD629E5241CbC5919847783e6C96B2De4754e438;
    address internal constant USDe    = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3;
    address internal constant wUSDM   = 0x57F5E098CaD7A3D1Eed53991D4d66C45C9AF7812;
    address internal constant EURC    = 0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c;
    address internal constant sUSDe   = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address internal constant USDS    = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address internal constant sUSDS   = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address internal constant stUSD   = 0x0022228a2cc5E7eF0274A7Baa600d44da5aB5776;
    address internal constant stEUR   = 0x004626A008B1aCdC4c74ab51644093b155e59A23;
    address internal constant FDUSD   = 0xc5f0f7b66764F6ec8C8Dff7BA683102295E16409;
    address internal constant USD0    = 0x73A15FeD60Bf67631dC6cd7Bc5B6e8da8190aCF5;
    address internal constant GHO     = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    address internal constant crvUSD  = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    address internal constant FRAX    = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address internal constant tBTC    = 0x18084fbA666a33d37592fA2633fD49a74DD93a88;
    address internal constant WBTC    = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant cbBTC   = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant LBTC    = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address internal constant eBTC    = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642;
    address internal constant SOLVBTC = 0x7A56E1C57C7475CCf742a1832B028F0456652F97;

    struct Cluster {
        address stubOracle;
        address oracleRouter;
        address oracleRouterGovernor;
        address vaultsGovernor;
        address[] assets;
        address[] vaults;
        uint16[][] ltvs;
        address feeReceiver;
        uint16 interestFee;
        uint16 maxLiquidationDiscount;
        uint16 liquidationCoolOffTime;
        address hookTarget;
        uint32 hookedOps;
        uint32 configFlags;
        mapping(address asset => string provider) oracleProviders;
        mapping(address asset => uint256 supplyCapNoDecimals) supplyCaps;
        mapping(address asset => uint256 borrowCapNoDecimals) borrowCaps;
        mapping(address asset => uint256[4] kinkIRMParams) kinkIRMParams;
        mapping(uint256 baseRate => mapping(uint256 slope1 => mapping(uint256 slope2 => mapping(uint256 kink => address irm)))) kinkIRMMap;
        address[] irms;
    }

    Cluster internal cluster;

    function setUp() internal {
        // do not change the order of the assets in the .assets array. if done, it must be reflected in other the other arrays the ltvs matrix.
        // if more than one vauls has to be deployed for the same asset, it can be added in the array as many times as needed.
        // note however, that mappings may need reworking as they always use asset address as key.
        cluster.assets = [WETH, wstETH, cbETH, WEETH, ezETH, RETH, METH, RSETH, sfrxETH, ETHx, rswETH, USDC, USDT, PYUSD, USDY, wM, mTBILL, USDe, wUSDM, EURC, sUSDe, USDS, sUSDS, stUSD, stEUR, FDUSD, USD0, GHO, crvUSD, FRAX, tBTC, WBTC, cbBTC, LBTC, eBTC, SOLVBTC];

        // define the governors here
        cluster.oracleRouterGovernor = getDeployer();
        cluster.vaultsGovernor = getDeployer();

        // define fee receiver here and interest fee here. if needed to be defined per asset, it can be converted to a mapping
        cluster.feeReceiver = address(0);
        cluster.interestFee = 0.1e4;

        // define max liquidation discount here. if needed to be defined per asset, it can be converted to a mapping
        cluster.maxLiquidationDiscount = 0.15e4;

        // define liquidation cool off time here. if needed to be defined per asset, it can be converted to a mapping
        cluster.liquidationCoolOffTime = 1;

        // define hook target and hooked ops here. if needed to be defined per asset, it can be converted to a mapping
        cluster.hookTarget = address(0);
        cluster.hookedOps = OP_MAX_VALUE - 1;

        // define config flags here. if needed to be defined per asset, it can be converted to a mapping
        cluster.configFlags = 0;

        // define oracle providers here. 
        // adapter names can be found in the relevant adapter contract (as returned by the `name` function).
        // for cross adapters, use the following format: "CrossAdapter=<adapterName1>+<adapterName2>".
        // although Redstone Classic oracles reuse the ChainlinkOracle contract and return "ChainlinkOracle" name, 
        // they should be referred to as "RedstoneClassicOracle"
        cluster.oracleProviders[WETH   ] = "ChainlinkOracle";
        cluster.oracleProviders[wstETH ] = "CrossAdapter=LidoFundamentalOracle+ChainlinkOracle";
        cluster.oracleProviders[cbETH  ] = "CrossAdapter=FixedRateOracle+ChainlinkOracle";
        cluster.oracleProviders[WEETH  ] = "CrossAdapter=FixedRateOracle+ChainlinkOracle";
        cluster.oracleProviders[ezETH  ] = "CrossAdapter=FixedRateOracle+ChainlinkOracle";
        cluster.oracleProviders[RETH   ] = "CrossAdapter=FixedRateOracle+ChainlinkOracle";
        cluster.oracleProviders[METH   ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[RSETH  ] = "CrossAdapter=FixedRateOracle+ChainlinkOracle";
        cluster.oracleProviders[sfrxETH] = "CrossAdapter=FixedRateOracle+ChainlinkOracle";
        cluster.oracleProviders[ETHx   ] = "CrossAdapter=FixedRateOracle+ChainlinkOracle";
        cluster.oracleProviders[rswETH ] = "CrossAdapter=FixedRateOracle+ChainlinkOracle";
        cluster.oracleProviders[USDC   ] = "ChainlinkOracle";
        cluster.oracleProviders[USDT   ] = "ChainlinkOracle";
        cluster.oracleProviders[PYUSD  ] = "ChainlinkOracle";
        cluster.oracleProviders[USDY   ] = "PythOracle";
        cluster.oracleProviders[wM     ] = "FixedRateOracle";
        cluster.oracleProviders[mTBILL ] = "";
        cluster.oracleProviders[USDe   ] = "ChainlinkOracle";
        cluster.oracleProviders[wUSDM  ] = "ChainlinkOracle";
        cluster.oracleProviders[EURC   ] = "PythOracle";
        cluster.oracleProviders[sUSDe  ] = "ChainlinkOracle";
        cluster.oracleProviders[USDS   ] = "ChronicleOracle";
        cluster.oracleProviders[sUSDS  ] = "ChronicleOracle";
        cluster.oracleProviders[stUSD  ] = "ChainlinkOracle";
        cluster.oracleProviders[stEUR  ] = "ChainlinkOracle";
        cluster.oracleProviders[FDUSD  ] = "PythOracle";
        cluster.oracleProviders[USD0   ] = "ChainlinkOracle";
        cluster.oracleProviders[GHO    ] = "ChainlinkOracle";
        cluster.oracleProviders[crvUSD ] = "ChainlinkOracle";
        cluster.oracleProviders[FRAX   ] = "ChainlinkOracle";
        cluster.oracleProviders[tBTC   ] = "ChainlinkOracle";
        cluster.oracleProviders[WBTC   ] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";
        cluster.oracleProviders[cbBTC  ] = "ChainlinkOracle";
        cluster.oracleProviders[LBTC   ] = "";
        cluster.oracleProviders[eBTC   ] = "";
        cluster.oracleProviders[SOLVBTC] = "RedstoneClassicOracle";

        // define supply caps here
        cluster.supplyCaps[WETH   ] = 378_000;
        cluster.supplyCaps[wstETH ] = 160_000;
        cluster.supplyCaps[cbETH  ] = 8_740;
        cluster.supplyCaps[WEETH  ] = 36_000;
        cluster.supplyCaps[ezETH  ] = 9_270;
        cluster.supplyCaps[RETH   ] = 17_300;
        cluster.supplyCaps[METH   ] = 18_500;
        cluster.supplyCaps[RSETH  ] = 9_450;
        cluster.supplyCaps[sfrxETH] = 3_890;
        cluster.supplyCaps[ETHx   ] = 3_740;
        cluster.supplyCaps[rswETH ] = 3_880;
        cluster.supplyCaps[USDC   ] = 500_000_000;
        cluster.supplyCaps[USDT   ] = 1_000_000_000;
        cluster.supplyCaps[PYUSD  ] = 25_000_000;
        cluster.supplyCaps[USDY   ] = 9_520_000;
        cluster.supplyCaps[wM     ] = 1_000_000;
        cluster.supplyCaps[mTBILL ] = 250_000;
        cluster.supplyCaps[USDe   ] = 50_000_000;
        cluster.supplyCaps[wUSDM  ] = 2_500_000;
        cluster.supplyCaps[EURC   ] = 2_200_000;
        cluster.supplyCaps[sUSDe  ] = 2_270_000;
        cluster.supplyCaps[USDS   ] = 20_000_000;
        cluster.supplyCaps[sUSDS  ] = 1_000_000;
        cluster.supplyCaps[stUSD  ] = 250_000;
        cluster.supplyCaps[stEUR  ] = 211_000;
        cluster.supplyCaps[FDUSD  ] = 100_000_000;
        cluster.supplyCaps[USD0   ] = 25_000_000;
        cluster.supplyCaps[GHO    ] = 2_500_000;
        cluster.supplyCaps[crvUSD ] = 2_500_000;
        cluster.supplyCaps[FRAX   ] = 2_500_000;
        cluster.supplyCaps[tBTC   ] = 158;
        cluster.supplyCaps[WBTC   ] = 1_570;
        cluster.supplyCaps[cbBTC  ] = 157;
        cluster.supplyCaps[LBTC   ] = 157;
        cluster.supplyCaps[eBTC   ] = 157;
        cluster.supplyCaps[SOLVBTC] = 789;

        // define borrow caps here if needed

        // define IRM classes here and assign them to the assets
        {
            // Base=0% APY  Kink(90%)=2.7% APY  Max=82.7%  APY
            uint256[4] memory irmWETH      = [uint256(0), uint256(218407859),  uint256(42500370385), uint256(3865470566)];

            // Base=0% APY  Kink(45%)=4.75% APY  Max=84.75% APY
            uint256[4] memory irmWstETH    = [uint256(0), uint256(760869530),  uint256(7611888145),  uint256(1932735283)];

            // Base=0% APY  Kink(45%)=7% APY  Max=307% APY
            uint256[4] memory irmOtherETH  = [uint256(0), uint256(1109317568), uint256(17921888499), uint256(1932735283)];

            // Base=0% APY  Kink(92%)=5.5% APY  Max=62.5% APY
            uint256[4] memory irmUSD       = [uint256(0), uint256(429380030),  uint256(39838751680), uint256(3951369912)];

            // Base=0% APY  Kink(80%)=9% APY  Max=84% APY
            uint256[4] memory irmUSDe      = [uint256(0), uint256(794785584),  uint256(19315443049), uint256(3435973836)];

            // Base=0% APY  Kink(80%)=5.5% APY  Max=85.5% APY
            uint256[4] memory irmOtherUSD  = [uint256(0), uint256(493787035),  uint256(20818956206), uint256(3435973836)];

            // Base=0% APY  Kink(45%)=4% APY  Max=304% APY
            uint256[4] memory irmBTC       = [uint256(0), uint256(643054912),  uint256(18204129717), uint256(1932735283)];
            
            cluster.kinkIRMParams[WETH   ] = irmWETH;
            cluster.kinkIRMParams[wstETH ] = irmWstETH;
            cluster.kinkIRMParams[cbETH  ] = irmOtherETH;
            cluster.kinkIRMParams[WEETH  ] = irmOtherETH;
            cluster.kinkIRMParams[ezETH  ] = irmOtherETH;
            cluster.kinkIRMParams[RETH   ] = irmOtherETH;
            cluster.kinkIRMParams[METH   ] = irmOtherETH;
            cluster.kinkIRMParams[RSETH  ] = irmOtherETH;
            cluster.kinkIRMParams[sfrxETH] = irmOtherETH;
            cluster.kinkIRMParams[ETHx   ] = irmOtherETH;
            cluster.kinkIRMParams[rswETH ] = irmOtherETH;
            cluster.kinkIRMParams[USDC   ] = irmUSD;
            cluster.kinkIRMParams[USDT   ] = irmUSD;
            cluster.kinkIRMParams[PYUSD  ] = irmOtherUSD;
            cluster.kinkIRMParams[USDY   ] = irmOtherUSD;
            cluster.kinkIRMParams[wM     ] = irmOtherUSD;
            cluster.kinkIRMParams[mTBILL ] = irmOtherUSD;
            cluster.kinkIRMParams[USDe   ] = irmUSDe;
            cluster.kinkIRMParams[wUSDM  ] = irmOtherUSD;
            cluster.kinkIRMParams[EURC   ] = irmOtherUSD;
            cluster.kinkIRMParams[sUSDe  ] = irmOtherUSD;
            cluster.kinkIRMParams[USDS   ] = irmOtherUSD;
            cluster.kinkIRMParams[sUSDS  ] = irmUSD;
            cluster.kinkIRMParams[stUSD  ] = irmOtherUSD;
            cluster.kinkIRMParams[stEUR  ] = irmOtherUSD;
            cluster.kinkIRMParams[FDUSD  ] = irmOtherUSD;
            cluster.kinkIRMParams[USD0   ] = irmOtherUSD;
            cluster.kinkIRMParams[GHO    ] = irmOtherUSD;
            cluster.kinkIRMParams[crvUSD ] = irmOtherUSD;
            cluster.kinkIRMParams[FRAX   ] = irmUSD;
            cluster.kinkIRMParams[tBTC   ] = irmBTC;
            cluster.kinkIRMParams[WBTC   ] = irmBTC;
            cluster.kinkIRMParams[cbBTC  ] = irmBTC;
            cluster.kinkIRMParams[LBTC   ] = irmBTC;
            cluster.kinkIRMParams[eBTC   ] = irmBTC;
            cluster.kinkIRMParams[SOLVBTC] = irmBTC;
        }
    
        // define ltv values here. columns are liability vaults, rows are collateral vaults
        cluster.ltvs = [ 
        //             WETH    wstETH  cbETH   WEETH   ezETH   RETH    METH    RSETH   sfrxETH ETHx    rswETH  USDC    USDT    PYUSD   USDY    wM      mTBILL  USDe    wUSDM   EURC    sUSDe   USDS    sUSDS   stUSD   stEUR   FDUSD   USD0    GHO     crvUSD  FRAX    tBTC    WBTC    cbBTC   LBTC    eBTC    SOLVBTC
        /* WETH    */ [0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.83e4, 0.83e4, 0.83e4, 0.83e4, 0.83e4, 0.83e4],
        /* wstETH  */ [0.93e4, 0.00e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.79e4, 0.79e4, 0.79e4, 0.79e4, 0.79e4, 0.79e4],
        /* cbETH   */ [0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* WEETH   */ [0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* ezETH   */ [0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* RETH    */ [0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* METH    */ [0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* RSETH   */ [0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4],
        /* sfrxETH */ [0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4],
        /* ETHx    */ [0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4],
        /* rswETH  */ [0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4],
        /* USDC    */ [0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.00e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4],
        /* USDT    */ [0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.95e4, 0.00e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4],
        /* PYUSD   */ [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* USDY    */ [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* wM      */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* mTBILL  */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* USDe    */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* wUSDM   */ [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* EURC    */ [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* sUSDe   */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* USDS    */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* sUSDS   */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* stUSD   */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* stEUR   */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* FDUSD   */ [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* USD0    */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* GHO     */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* crvUSD  */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* FRAX    */ [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* tBTC    */ [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.00e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4],
        /* WBTC    */ [0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.00e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.00e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4],
        /* cbBTC   */ [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.00e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4, 0.90e4, 0.90e4],
        /* LBTC    */ [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.00e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.00e4, 0.90e4],
        /* eBTC    */ [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.00e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.00e4, 0.90e4],
        /* SOLVBTC */ [0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.00e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4]
        ];

        initializeCluster();
    }

    function dumpCluster() internal {
        string memory result = "";
        result = vm.serializeAddress("cluster", "stubOracle", cluster.stubOracle);
        result = vm.serializeAddress("cluster", "oracleRouter", cluster.oracleRouter);
        result = vm.serializeAddress("cluster", "vaults", cluster.vaults);
        result = vm.serializeAddress("cluster", "irms", cluster.irms);
        vm.writeJson(result, getInputConfigFilePath("ClusterAddresses.json"));
    }

    function loadCluster(string memory json) internal {
        cluster.stubOracle = getAddressFromJson(json, ".stubOracle");
        cluster.oracleRouter = getAddressFromJson(json, ".oracleRouter");
        cluster.vaults = getAddressesFromJson(json, ".vaults");
        cluster.irms = getAddressesFromJson(json, ".irms");

        for (uint256 i = 0; i < cluster.irms.length; ++i) {
            InterestRateModelDetailedInfo memory irmInfo = IRMLens(lensAddresses.irmLens).getInterestRateModelInfo(cluster.irms[i]);

            if (irmInfo.interestRateModelType == InterestRateModelType.KINK) {
                KinkIRMInfo memory kinkIRMInfo = abi.decode(irmInfo.interestRateModelParams, (KinkIRMInfo));
                cluster.kinkIRMMap[kinkIRMInfo.baseRate][kinkIRMInfo.slope1][kinkIRMInfo.slope2][kinkIRMInfo.kink] = cluster.irms[i];
            }
        }

        checkDataSanity();
    }

    function initializeCluster() private {
        encodeAmountCaps(cluster.assets, cluster.supplyCaps);
        encodeAmountCaps(cluster.assets, cluster.borrowCaps);

        string memory path = string.concat(vm.projectRoot(), "/script/production/mainnet/megaCluster/ClusterAddresses.json");
        if (vm.exists(path)) loadCluster(vm.readFile(path));
    }

    function checkDataSanity() private view {
        require(cluster.stubOracle != address(0), "stubOracle is not set");
        require(cluster.oracleRouter != address(0), "OracleRouter is not set");
        require(cluster.vaults.length == cluster.assets.length, "Vaults and assets length mismatch");
        require(cluster.irms.length == cluster.assets.length, "IRMs and assets length mismatch");

        for (uint256 i = 0; i < cluster.vaults.length; ++i) {
            require(cluster.assets[i] == IEVault(cluster.vaults[i]).asset(), "Asset is not equal to vault asset");
        }
    }
}
