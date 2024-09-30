// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder} from "../../utils/ScriptUtils.s.sol";
import {KinkIRM} from "../../04_IRM.s.sol";
import {EVaultDeployer, OracleRouterDeployer, EulerRouter} from "../../07_EVault.s.sol";
import {OracleVerifier} from "../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../utils/PerspectiveCheck.s.sol";
import {CustomWhitelistPerspective} from "../../../src/Perspectives/deployed/CustomWhitelistPerspective.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

contract DeployMegaCluster is BatchBuilder {
    address internal constant USD     = address(840);
    address internal constant BTC     = 0xbBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB;
    address internal constant WETH    = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant wstETH  = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant cbETH   = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address internal constant ezETH   = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
    address internal constant RETH    = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address internal constant METH    = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa;
    address internal constant WEETH   = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant RSETH   = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
    address internal constant FRXETH  = 0x5E8422345238F34275888049021821E8E08CAa1f;
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
    address internal constant EURS    = 0xdB25f211AB05b1c97D595516F45794528a807ad8;
    address internal constant sUSDe   = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;
    address internal constant USDS    = 0xdC035D45d973E3EC169d2276DDab16f1e407384F;
    address internal constant sUSDS   = 0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD;
    address internal constant FDUSD   = 0xc5f0f7b66764F6ec8C8Dff7BA683102295E16409;
    address internal constant USD0    = 0x73A15FeD60Bf67631dC6cd7Bc5B6e8da8190aCF5;
    address internal constant GHO     = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f;
    address internal constant crvUSD  = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    address internal constant FRAX    = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    address internal constant tBTC    = 0x18084fbA666a33d37592fA2633fD49a74DD93a88;
    address internal constant WBTC    = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant cbBTC   = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant LBTC    = 0x8236a87084f8B84306f72007F36F2618A5634494;
    address internal constant SOLVBTC = 0x7A56E1C57C7475CCf742a1832B028F0456652F97;

    address oracleRouter;
    address[] internal assets;
    address[] internal vaults;
    uint256[] internal supplyCaps;
    uint16[][] internal ltvs;
    mapping(address => mapping(address => address)) internal oracleAdapters;
    mapping(address => address) internal irms;

    constructor() {
        // fixme wM, mTBILL scap
        assets     = [WETH,    wstETH,  cbETH, ezETH, RETH,   METH,   WEETH, RSETH, FRXETH, ETHx,  rswETH, USDC,        USDC,        USDC,        USDT,          PYUSD,      USDY,      wM,                mTBILL,            USDe,       wUSDM,     EURC,      EURS,      sUSDe,     USDS,       sUSDS,     FDUSD,       USD0,       GHO,       crvUSD,    FRAX,      tBTC, WBTC,  cbBTC, LBTC, SOLVBTC];
        supplyCaps = [378_000, 160_000, 8_740, 9_270, 17_300, 18_500, 9_710, 9_450, 3_890,  3_740, 3_880,  500_000_000, 500_000_000, 500_000_000, 1_000_000_000, 25_000_000, 9_520_000, type(uint256).max, type(uint256).max, 50_000_000, 2_500_000, 2_250_000, 2_270_000, 2_270_000, 20_000_000, 1_000_000, 100_000_000, 25_000_000, 2_500_000, 2_500_000, 2_500_000, 158,  1_570, 157,   157,  789];
      //supplyCaps = [378_055, 160_241, 8_748, 9_276, 17_327, 18_574, 9_713, 9_458, 3_893,  3_745, 3_881,  500_000_000, 500_000_000, 500_000_000, 1_000_000_000, 25_000_000, 9_523_810, type(uint256).max, type(uint256).max, 50_025_013, 2_500_500, 2_252_252, 2_272_727, 2_272_727, 20_000_000, 1_000_000, 100_000_000, 25_042_572, 2_500_000, 2_502_753, 2_506_768, 158,  1_576, 157,   157,  789];
        supplyCaps = encodeAmountCaps(assets, supplyCaps);

        oracleAdapters[wstETH][WETH]  = 0xA9E18Ece44DcCd4E623135098C8B0887C87F6128; // Cross_wstETH/ETH=Lido_wstETH/stETH+Chainlink_stETH/ETH
        oracleAdapters[cbETH][WETH]   = 0xD41641d2D8b3B0DCaEdFab917AA4c140C4dBAb77; // Chainlink_CBETH/ETH
        oracleAdapters[ezETH][WETH]   = 0x0F239a09D9B4f048d2EfE36a4204692F8DF5B564; // Chainlink_ezETH/ETH
        oracleAdapters[RETH][WETH]    = 0xE39Da17508ec3fE7806a58b0aBe15A2df742cBfE; // Chainlink_RETH/ETH
        oracleAdapters[METH][WETH]    = 0x6bF6cc2d082273eF4f373Cb180e05d7D380ecaf6; // Chainlink_METH/ETH
        oracleAdapters[WEETH][WETH]   = 0x8116Ff3BCF7460FEF6B1b258dd7959Ea3DfDF778; // Chainlink_WEETH/ETH
        oracleAdapters[RSETH][WETH]   = 0x375b0dcFE72efBc03937A3FfFc1de13d97D6F4B1; // Chainlink_RSETH/ETH
        oracleAdapters[FRXETH][WETH]  = address(0);
        oracleAdapters[ETHx][WETH]    = 0x0fe1A11CC41459A60471BEF0177C08C4f09f94d9; // Chainlink_ETHx/ETH
        oracleAdapters[rswETH][WETH]  = 0xcEa9Db0E0602879DCcB2DC2D1Bb343B7f9143073; // Chainlink_rswETH/ETH
        oracleAdapters[USDC][WETH]    = 0x2eA2b307cD934a6e705eAcFCb6B806d018Cd62CF; // Chainlink_USDC/ETH
        oracleAdapters[USDT][WETH]    = 0xc3928c5AcE4c047053eBCf547F9d513261e87a78; // Chainlink_USDT/ETH
        oracleAdapters[PYUSD][WETH]   = address(0);
        oracleAdapters[USDY][WETH]    = address(0);
        oracleAdapters[wM][WETH]      = address(0);
        oracleAdapters[mTBILL][WETH]  = address(0);
        oracleAdapters[USDe][WETH]    = address(0);
        oracleAdapters[wUSDM][WETH]   = address(0);
        oracleAdapters[EURC][WETH]    = address(0);
        oracleAdapters[EURS][WETH]    = address(0);
        oracleAdapters[sUSDe][WETH]   = address(0);
        oracleAdapters[USDS][WETH]    = address(0);
        oracleAdapters[sUSDS][WETH]   = address(0);
        oracleAdapters[FDUSD][WETH]   = address(0);
        oracleAdapters[USD0][WETH]    = address(0);
        oracleAdapters[GHO][WETH]     = address(0);
        oracleAdapters[crvUSD][WETH]  = address(0);
        oracleAdapters[FRAX][WETH]    = 0x81D21c8f60dfD0f0c91013DCEa964E731f78665e; // Chainlink_FRAX/ETH
        oracleAdapters[tBTC][WETH]    = address(0);
        oracleAdapters[WBTC][WETH]    = address(0);
        oracleAdapters[cbBTC][WETH]   = 0xDC149E485a29Fc9384D8e634Ae9170ae1727BeaB; // Cross_cbBTC/ETH=Chronicle_cbBTC/USDC+Chainlink_USDC/ETH
        oracleAdapters[LBTC][WETH]    = address(0);
        oracleAdapters[SOLVBTC][WETH] = address(0);

        oracleAdapters[WETH][USD]    = 0x10674C8C1aE2072d4a75FE83f1E159425fd84E1D; // Chainlink_ETH/USD
        oracleAdapters[wstETH][USD]  = 0x02dd5B7ab536629d2235276aBCDf8eb3Af9528D7; // Cross_wstETH/USD=Lido_wstETH/stETH+Chainlink_stETH/USD
        oracleAdapters[cbETH][USD]   = 0x8710019824E557F907Fb0B8BD23d610d74dD7444; // Cross_CBETH/USD=Chainlink_CBETH/ETH+Chainlink_ETH/USD
        oracleAdapters[ezETH][USD]   = 0x2B23B4EAAe78D0343d5168A6A489F7daBc9a8205; // Cross_ezETH/USD=Chainlink_ezETH/ETH+Chainlink_ETH/USD
        oracleAdapters[RETH][USD]    = 0x73bDDD7B48B653D4e78D88916a40f9890049ebE9; // Cross_RETH/USD=Chainlink_RETH/ETH+Chainlink_ETH/USD
        oracleAdapters[METH][USD]    = 0xe7a32E7A8b2536924D8ac4913F80d9133558eC27; // Cross_mETH/USD=Chainlink_mETH/ETH+Chainlink_ETH/USD
        oracleAdapters[WEETH][USD]   = 0x6A7c5B6EBFFc65c464f0A3D88913c906bF7A72aF; // Cross_weETH/USD=Chainlink_weETH/ETH+Chainlink_ETH/USD
        oracleAdapters[RSETH][USD]   = 0xd9274249FD71413342F75168c476CC357B17A3A1; // Cross_RSETH/USD=Chainlink_RSETH/ETH+Chainlink_ETH/USD
        oracleAdapters[FRXETH][USD]  = address(0);
        oracleAdapters[ETHx][USD]    = 0x1DF4f5afD2Ad4E830a343C7C32824A9F4b525496; // Cross_ETHx/USD=Chainlink_ETHx/ETH+Chainlink_ETH/USD
        oracleAdapters[rswETH][USD]  = 0x951bcDd3551Bb617f3B98FcD9E6A5c0e70432928; // Cross_rswETH/USD=Chainlink_rswETH/ETH+Chainlink_ETH/USD
        oracleAdapters[USDC][USD]    = 0x6213f24332D35519039f2afa7e3BffE105a37d3F; // Chainlink_USDC/USD
        oracleAdapters[USDT][USD]    = 0x587CABe0521f5065b561A6e68c25f338eD037FF9; // Chainlink_USDT/USD
        oracleAdapters[PYUSD][USD]   = 0x27895A6295a5117CB989d610DF1Df39DC2CDBf8F; // Chainlink_PYUSD/USD
        oracleAdapters[USDY][USD]    = address(0);
        oracleAdapters[wM][WETH]     = address(0);
        oracleAdapters[mTBILL][USD]  = address(0);
        oracleAdapters[USDe][USD]    = 0x8211B9ae40b06d3Db0215E520F232184Af355378; // Chainlink_USDe/USD
        oracleAdapters[wUSDM][USD]   = address(0);
        oracleAdapters[EURC][USD]    = address(0);
        oracleAdapters[EURS][USD]    = address(0);
        oracleAdapters[sUSDe][USD]   = 0xD4fF9D4e0A3E5995A0E040632F34271b2e9c8a42; // Chainlink_sUSDe/USD
        oracleAdapters[USDS][USD]    = 0x6245cd4E6fef97ccc0508242135fdF2577006cfc; // Chronicle_USDS/USD
        oracleAdapters[sUSDS][USD]   = 0x5a47412c769A6a57bA757253fB199eDC3cCFCDe6; // Chainlink_sUSDS/USD
        oracleAdapters[FDUSD][USD]   = address(0);
        oracleAdapters[USD0][USD]    = 0xd9c823f4061d4a09881D26290BC41D910119C7Ec; // Chainlink_USD0/USD
        oracleAdapters[GHO][USD]     = 0x5291579cA14767A54E00fEd2872D609E7850dF75; // Chainlink_GHO/USD
        oracleAdapters[crvUSD][USD]  = 0x24eFfF312944A66eE45058550fEBDcc65C9f099e; // Chainlink_CRVUSD/USD
        oracleAdapters[FRAX][USD]    = 0xE93999C098EC339E1CbcEB5bB0C1Fd37a867921c; // Chainlink_FRAX/USD
        oracleAdapters[tBTC][USD]    = 0x1bDc02Cc6F129815Cb666Cb10f08037985D8A7d2; // Chainlink_tBTC/USD
        oracleAdapters[WBTC][USD]    = 0x8F358638Eb5D0afF47E5b320213C07235e40ebe2; // Cross_WBTC/USD=Chainlink_WBTC/BTC+Chainlink_BTC/USD
        oracleAdapters[cbBTC][USD]   = 0x5a435d7b7E5f39e19172b0f4D5012363b7d2036F; // Chainlink_cbBTC/USD
        oracleAdapters[LBTC][USD]    = address(0);
        oracleAdapters[SOLVBTC][USD] = address(0);

        oracleAdapters[WETH][BTC]    = 0xccE9D62e73d97CEF4F09c73f6924234B435Ee704; // Chainlink_ETH/BTC
        oracleAdapters[wstETH][BTC]  = address(0);
        oracleAdapters[cbETH][BTC]   = address(0);
        oracleAdapters[ezETH][BTC]   = address(0);
        oracleAdapters[RETH][BTC]    = address(0);
        oracleAdapters[METH][BTC]    = address(0);
        oracleAdapters[WEETH][BTC]   = address(0);
        oracleAdapters[RSETH][BTC]   = address(0);
        oracleAdapters[FRXETH][BTC]  = address(0);
        oracleAdapters[ETHx][BTC]    = address(0);
        oracleAdapters[rswETH][BTC]  = address(0);
        oracleAdapters[USDC][BTC]    = address(0);
        oracleAdapters[USDT][BTC]    = address(0);
        oracleAdapters[PYUSD][BTC]   = address(0);
        oracleAdapters[USDY][BTC]    = address(0);
        oracleAdapters[wM][WETH]     = address(0);
        oracleAdapters[mTBILL][BTC]  = address(0);
        oracleAdapters[USDe][BTC]    = address(0);
        oracleAdapters[wUSDM][BTC]   = address(0);
        oracleAdapters[EURC][BTC]    = address(0);
        oracleAdapters[EURS][BTC]    = address(0);
        oracleAdapters[sUSDe][BTC]   = address(0);
        oracleAdapters[USDS][BTC]    = address(0);
        oracleAdapters[sUSDS][BTC]   = address(0);
        oracleAdapters[FDUSD][BTC]   = address(0);
        oracleAdapters[USD0][BTC]    = address(0);
        oracleAdapters[GHO][BTC]     = address(0);
        oracleAdapters[crvUSD][BTC]  = address(0);
        oracleAdapters[FRAX][BTC]    = address(0);
        oracleAdapters[tBTC][BTC]    = address(0);
        oracleAdapters[WBTC][BTC]    = 0xc38B1ae5f9bDd68D44b354fD06b16488Be4Bc0d4; // Chainlink_WBTC/BTC
        oracleAdapters[cbBTC][BTC]   = address(0);
        oracleAdapters[LBTC][BTC]    = address(0);
        oracleAdapters[SOLVBTC][BTC] = address(0);

        ltvs = [    //  WETH    wstETH  cbETH   ezETH   RETH    METH    WEETH   RSETH   FRXETH  ETHx    rswETH  USDCETH USDCUSD USDCBTC USDT    PYUSD   USDY    wM      mTBILL  USDe    wUSDM   EURC    EURS    sUSDe   USDS    sUSDS   FDUSD   USD0    GHO     crvUSD  FRAX    tBTC    WBTC    cbBTC   LBTC   SOLVBTC
        /* WETH    */  [0     , 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.89e4, 0     , 0     , 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.83e4, 0.83e4, 0.83e4, 0.83e4, 0.83e4],
        /* wstETH  */  [0.93e4, 0     , 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.93e4, 0.86e4, 0     , 0     , 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.86e4, 0.79e4, 0.79e4, 0.79e4, 0.79e4, 0.79e4],
        /* cbETH   */  [0.92e4, 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0     , 0     , 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* ezETH   */  [0.92e4, 0.92e4, 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0     , 0     , 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* RETH    */  [0.92e4, 0.92e4, 0.92e4, 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0     , 0     , 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* METH    */  [0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0     , 0     , 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* WEETH   */  [0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0     , 0     , 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* RSETH   */  [0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0     , 0     , 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4],
        /* FRXETH  */  [0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0     , 0.90e4, 0.90e4, 0.81e4, 0     , 0     , 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4],
        /* ETHx    */  [0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0     , 0.90e4, 0.81e4, 0     , 0     , 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4],
        /* rswETH  */  [0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.00e4, 0.84e4, 0     , 0     , 0.84e4, 0.84e4, 0.84e4, 0.81e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4],
        /* USDCETH */  [0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0     , 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4],
        /* USDCUSD */  [0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.95e4, 0     , 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4],
        /* USDCBTC */  [0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.95e4, 0.95e4, 0     , 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4],
        /* USDT    */  [0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0     , 0.95e4, 0     , 0     , 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.95e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4, 0.89e4],
        /* PYUSD   */  [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0     , 0.92e4, 0     , 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* USDY    */  [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0     , 0.92e4, 0     , 0.92e4, 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* wM      */  [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0     , 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* mTBILL  */  [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0     , 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* USDe    */  [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0     , 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* wUSDM   */  [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0     , 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* EURC    */  [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0     , 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* EURS    */  [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0     , 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* sUSDe   */  [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0     , 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* USDS    */  [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0     , 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* sUSDS   */  [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0     , 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* FDUSD   */  [0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0     , 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4],
        /* USD0    */  [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0     , 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* GHO     */  [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0     , 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0     , 0.90e4, 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* crvUSD  */  [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0     , 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0     , 0.90e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* FRAX    */  [0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0     , 0.90e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0.90e4, 0     , 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4],
        /* tBTC    */  [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0     , 0     , 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0     , 0.90e4, 0.90e4, 0.90e4, 0.90e4],
        /* WBTC    */  [0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0     , 0     , 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0     , 0.92e4, 0.92e4, 0.92e4],
        /* cbBTC   */  [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0     , 0     , 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0     , 0.90e4, 0.90e4],
        /* LBTC    */  [0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0.71e4, 0     , 0     , 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.81e4, 0.90e4, 0.90e4, 0.90e4, 0     , 0.90e4],
        /* SOLVBTC */  [0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0.75e4, 0     , 0     , 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.84e4, 0.92e4, 0.92e4, 0.92e4, 0.92e4, 0     ]
        ];
    }

    function run() public returns (address) {        
        // deploy the oracle router
        {
            OracleRouterDeployer deployer = new OracleRouterDeployer();
            oracleRouter = deployer.deploy(peripheryAddresses.oracleRouterFactory);
        }

        // deploy the IRMs
        {
            // fixme define IRM classes
            KinkIRM deployer = new KinkIRM();

            // Base=0% APY  Kink(90%)=2.7% APY  Max=82.7% APY
            address irmETH = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 218407859, 42500370385, 3865470566);

            // Base=0% APY  Kink(45%)=4.75% APY  Max=84.75% APY
            address irmWstETH = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 760869530, 7611888145, 1932735283);

            // Base=0% APY  Kink(45%)=7% APY  Max=307% APY
            address irmOtherETH = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 1109317568, 17921888499, 1932735283);

            // Base=0% APY  Kink(92%)=5.5% APY  Max=62.5% APY
            address irmUSD = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 429380030, 39838751680, 3951369912);

            // Base=0% APY  Kink(80%)=9% APY  Max=84% APY
            address irmUSDe = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 794785584, 19315443049, 3435973836);

            // Base=0% APY  Kink(80%)=5.5% APY  Max=85.5% APY
            address irmOtherUSD = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 493787035, 20818956206, 3435973836);

            // Base=0% APY  Kink(45%)=4% APY  Max=304% APY
            address irmBTC = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 643054912, 18204129717, 1932735283);

            irms[WETH]    = irmETH;
            irms[wstETH]  = irmWstETH;
            irms[cbETH]   = irmOtherETH;
            irms[ezETH]   = irmOtherETH;
            irms[RETH]    = irmOtherETH;
            irms[METH]    = irmOtherETH;
            irms[WEETH]   = irmOtherETH;
            irms[RSETH]   = irmOtherETH;
            irms[FRXETH]  = irmOtherETH;
            irms[ETHx]    = irmOtherETH;
            irms[rswETH]  = irmOtherETH;
            irms[USDC]    = irmUSD;
            irms[USDT]    = irmUSD;
            irms[PYUSD]   = irmOtherUSD;
            irms[USDY]    = irmOtherUSD;
            irms[wM]      = irmOtherUSD;
            irms[mTBILL]  = irmOtherUSD;
            irms[USDe]    = irmUSDe;
            irms[wUSDM]   = irmOtherUSD;
            irms[EURC]    = irmOtherUSD;
            irms[EURS]    = irmOtherUSD;
            irms[sUSDe]   = irmOtherUSD;
            irms[USDS]    = irmOtherUSD;
            irms[sUSDS]   = irmUSD;
            irms[FDUSD]   = irmOtherUSD;
            irms[USD0]    = irmOtherUSD;
            irms[GHO]     = irmOtherUSD;
            irms[crvUSD]  = irmOtherUSD;
            irms[FRAX]    = irmUSD;
            irms[tBTC]    = irmBTC;
            irms[WBTC]    = irmBTC;
            irms[cbBTC]   = irmBTC;
            irms[LBTC]    = irmBTC;
            irms[SOLVBTC] = irmBTC;
        }

        // deploy the vaults
        {
            EVaultDeployer deployer = new EVaultDeployer();

            uint256 USDCCounter = 0;
            address unitOfAccount = WETH;
            for (uint256 i = 0; i < assets.length; ++i) {
                address asset = assets[i];

                if (asset == USDT) unitOfAccount = USD;
                else if (asset == tBTC) unitOfAccount = BTC;
                
                if (asset == USDC) {
                    if (USDCCounter == 0) {
                        vaults.push(deployer.deploy(coreAddresses.eVaultFactory, true, asset, oracleRouter, WETH));
                    } else if (USDCCounter == 1) {
                        vaults.push(deployer.deploy(coreAddresses.eVaultFactory, true, asset, oracleRouter, USD));
                    } else if (USDCCounter == 2) {
                        vaults.push(deployer.deploy(coreAddresses.eVaultFactory, true, asset, oracleRouter, BTC));
                    }

                    USDCCounter++;
                } else {
                    vaults.push(deployer.deploy(coreAddresses.eVaultFactory, true, asset, oracleRouter, unitOfAccount));
                }
            }
        }

        // configure the vaults and the oracle router
        for (uint256 i = 0; i < vaults.length; ++i) {
            address vault = vaults[i];
            address vaultAsset = IEVault(vault).asset();
            address unitOfAccount = IEVault(vault).unitOfAccount();
            address oracleAdapter = oracleAdapters[vaultAsset][unitOfAccount];

            if (vaultAsset != unitOfAccount && EulerRouter(oracleRouter).getConfiguredOracle(vaultAsset, unitOfAccount) == address(0)) {
                govSetConfig(oracleRouter, vaultAsset, unitOfAccount, oracleAdapter);
            }
            
            setMaxLiquidationDiscount(vault, 0.15e4);
            setLiquidationCoolOffTime(vault, 1);
            setInterestRateModel(vault, irms[vaultAsset]);

            for (uint256 j = 0; j < vaults.length; ++j) {
                address collateral = vaults[j];
                address collateralAsset = IEVault(collateral).asset();
                uint16 ltv = ltvs[j][i];
                
                if (ltv != 0) {
                    oracleAdapter = oracleAdapters[collateralAsset][unitOfAccount];

                    if (EulerRouter(oracleRouter).resolvedVaults(collateral) == address(0)) {
                        govSetResolvedVault(oracleRouter, collateral, true);
                    }

                    if (collateralAsset != unitOfAccount && EulerRouter(oracleRouter).getConfiguredOracle(collateralAsset, unitOfAccount) == address(0)) {
                        govSetConfig(oracleRouter, collateralAsset, unitOfAccount, oracleAdapter);
                    }

                    setLTV(vault, collateral, ltv - 0.02e4, ltv, 0);
                }
            }
        }

        executeBatch();

        // prepare the results
        address[] memory result = new address[](vaults.length);
        for (uint256 i = 0; i < vaults.length; ++i) {
            address vault = vaults[i];

            OracleVerifier.verifyOracleConfig(vault);
            PerspectiveVerifier.verifyPerspective(
                peripheryAddresses.eulerUngoverned0xPerspective,
                vault,
                PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | 
                PerspectiveVerifier.E__GOVERNOR | 
                PerspectiveVerifier.E__LTV_COLLATERAL_RECOGNITION
            );

            result[i] = vault;
        }

        return address(new CustomWhitelistPerspective(result));
    }
}
