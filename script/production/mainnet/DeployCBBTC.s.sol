// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder} from "../../utils/ScriptUtils.s.sol";
import {OracleVerifier} from "../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../utils/PerspectiveCheck.s.sol";
import {KinkIRM} from "../../04_IRM.s.sol";
import {EVaultDeployer, OracleRouterDeployer} from "../../07_EVault.s.sol";

contract DeployCBBTC is BatchBuilder {
    // final governor addresses
    address internal constant MULTISIG = 0xcAD001c30E96765aC90307669d578219D4fb1DCe;
    address internal constant ORACLE_ROUTER_GOVERNOR = MULTISIG;
    address internal constant VAULTS_GOVERNOR = MULTISIG;

    // assets
    address internal constant USD = address(840);
    address internal constant cbBTC = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    // oracle adapters
    address internal constant cbBTCUSD = 0x04A56636015Ef379e21Bb78aa61069E721D0cf1C;
    address internal constant WETHUSD = 0x10674C8C1aE2072d4a75FE83f1E159425fd84E1D;
    address internal constant wstETHUSD = 0x02dd5B7ab536629d2235276aBCDf8eb3Af9528D7;
    address internal constant USDCUSD = 0x6213f24332D35519039f2afa7e3BffE105a37d3F;
    address internal constant USDTUSD = 0x587CABe0521f5065b561A6e68c25f338eD037FF9;

    address internal IRM;
    address internal oracleRouter;
    address[] internal assets;
    address[] internal oracleAdapters;
    uint16[] internal borrowableEscrowLTVs;
    uint16[] internal borrowableBorrowableLTVs;

    mapping(address => address) internal escrowVaults;
    mapping(address => address) internal borrowableVaults;

    constructor() {
        assets           = [cbBTC,    WETH,    wstETH,    USDC,    USDT];
        oracleAdapters   = [cbBTCUSD, WETHUSD, wstETHUSD, USDCUSD, USDTUSD];

        escrowVaults[cbBTC] = 0x7fAeE4175B4Ac5AC117106Ea726b7C373C67a419;
        escrowVaults[WETH] = 0xb3b36220fA7d12f7055dab5c9FD18E860e9a6bF8;
        escrowVaults[wstETH] = 0xF6E2EfDF175e7a91c8847dade42f2d39A9aE57D4;
        escrowVaults[USDC] = 0xB93d4928f39fBcd6C89a7DFbF0A867E6344561bE;
        escrowVaults[USDT] = 0x2343b4bCB96EC35D8653Fb154461fc673CB20a7e;
        
        borrowableVaults[WETH] = 0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2;
        borrowableVaults[wstETH] = 0xbC4B4AC47582c3E38Ce5940B80Da65401F4628f1;
        borrowableVaults[USDC] = 0x797DD80692c3b2dAdabCe8e30C07fDE5307D48a9;
        borrowableVaults[USDT] = 0x313603FA690301b0CaeEf8069c065862f9162162;

        //                                                  cbBTC
        borrowableEscrowLTVs =     /* escrow cbBTC      */ [0.00e4,
                                   /* escrow WETH       */  0.83e4,
                                   /* escrow wstETH     */  0.80e4,
                                   /* escrow USDC       */  0.76e4,
                                   /* escrow USDT       */  0.76e4];

        //                                                  cbBTC
        borrowableBorrowableLTVs = /* borrowable cbBTC  */ [0.00e4,
                                   /* borrowable WETH   */  0.81e4,
                                   /* borrowable wstETH */  0.78e4,
                                   /* borrowable USDC   */  0.74e4,
                                   /* borrowable USDT   */  0.74e4];
    }

    function run() public returns (address) {
        // deploy the IRM
        {
            KinkIRM deployer = new KinkIRM();

            // Base=0% APY  Kink(45%)=4% APY  Max=304% APY
            IRM = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 643054912, 18204129717, 1932735283);
        }

        // deploy the oracle router
        {
            OracleRouterDeployer deployer = new OracleRouterDeployer();
            oracleRouter = deployer.deploy(peripheryAddresses.oracleRouterFactory);
        }

        // deploy the borrowable cbBTC vault
        {
            EVaultDeployer deployer = new EVaultDeployer();
            borrowableVaults[cbBTC] = deployer.deploy(coreAddresses.eVaultFactory, true, cbBTC, oracleRouter, USD);
        }

        // configure the oracle router
        for (uint256 i = 0; i < assets.length; ++i) {
            address asset = assets[i];
            govSetResolvedVault(oracleRouter, escrowVaults[asset], true);
            govSetResolvedVault(oracleRouter, borrowableVaults[asset], true);
            govSetConfig(oracleRouter, asset, USD, oracleAdapters[i]);
        }
        transferGovernance(oracleRouter, ORACLE_ROUTER_GOVERNOR);

        // configure the borrowable cbBTC vault
        setMaxLiquidationDiscount(borrowableVaults[cbBTC], 0.15e4);
        setLiquidationCoolOffTime(borrowableVaults[cbBTC], 1);
        setInterestRateModel(borrowableVaults[cbBTC], IRM);
        
        for (uint256 i = 0; i < assets.length; ++i) {
            address collateral = escrowVaults[assets[i]];
            uint16 ltv = borrowableEscrowLTVs[i];

            if (ltv != 0) setLTV(borrowableVaults[cbBTC], collateral, ltv - 0.02e4, ltv, 0);
        }

        for (uint256 i = 0; i < assets.length; ++i) {
            address collateral = borrowableVaults[assets[i]];
            uint16 ltv = borrowableBorrowableLTVs[i];

            if (ltv != 0) setLTV(borrowableVaults[cbBTC], collateral, ltv - 0.02e4, ltv, 0);
        }

        setHookConfig(borrowableVaults[cbBTC], address(0), 0);
        setGovernorAdmin(borrowableVaults[cbBTC], VAULTS_GOVERNOR);
        executeBatch();

        // sanity check the oracle config and perspectives
        OracleVerifier.verifyOracleConfig(borrowableVaults[cbBTC]);
        PerspectiveVerifier.verifyPerspective(
            peripheryAddresses.eulerUngovernedNzxPerspective,
            borrowableVaults[cbBTC],
            PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | PerspectiveVerifier.E__GOVERNOR
        );

        return borrowableVaults[cbBTC];
    }
}
