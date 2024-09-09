// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder, IEVault} from "../../utils/ScriptUtils.s.sol";
import {OracleVerifier} from "../../utils/SanityCheckOracle.s.sol";
import {PerspectiveVerifier} from "../../utils/PerspectiveCheck.s.sol";
import {EVaultDeployer, OracleRouterDeployer} from "../../07_EVault.s.sol";

/*
to run:
   1. curl -L https://foundry.paradigm.xyz | bash
   2. foundryup
   3. git clone https://github.com/euler-xyz/evk-periphery.git && cd evk-periphery
   4. git clone https://github.com/euler-xyz/euler-interfaces.git
   5. git checkout custom-deployment-1 && cp .env.example .env
   6. sed -i '' 's|^ADDRESSES_DIR_PATH=.*|ADDRESSES_DIR_PATH="euler-interfaces/addresses/1"|' ./.env
   7. add the DEPLOYMENT_RPC_URL and the DEPLOYER_KEY in the .env file
   8. forge install && forge compile
   9. ./script/production/ExecuteSolidityScript.sh script/production/mainnet_custom_1/DeployVaults.s.sol
*/

contract DeployVaults is BatchBuilder {
    // final governor addresses
    address internal constant MULTISIG = 0x38afC3aA2c76b4cA1F8e1DabA68e998e1F4782DB;
    address internal constant ORACLE_ROUTER_GOVERNOR = MULTISIG;
    address internal constant GOVERNED_VAULTS_GOVERNOR = MULTISIG;
    address internal constant GOVERNED_VAULTS_FEE_RECEIVER = MULTISIG;

    // assets
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant cbETH = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address internal constant rETH = 0xae78736Cd615f374D3085123A210448E74Fc6393;
    address internal constant woETH = 0xDcEe70654261AF21C44c093C300eD3Bb97b78192;
    address internal constant ETHPlus = 0xE72B141DF173b999AE7c1aDcbF60Cc9833Ce56a8;
    address internal constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant ezETH = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110;
    address internal constant rsETH = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7;
    address internal constant amphrETH = 0x5fD13359Ba15A84B76f7F87568309040176167cd;
    address internal constant steakLRT = 0xBEEF69Ac7870777598A04B2bd4771c71212E6aBc;
    address internal constant pzETH = 0x8c9532a60E0E7C6BbD2B2c1303F63aCE1c3E9811;
    address internal constant rstETH = 0x7a4EffD87C2f3C55CA251080b1343b605f327E3a;

    // oracle adapters
    address internal constant wstETHETH = 0x7c37aB8Cd76Ee8888ad7F19C1F8a3A6D1622e9B8;
    address internal constant cbETHETH = 0xD41641d2D8b3B0DCaEdFab917AA4c140C4dBAb77;
    address internal constant rETHETH = 0xE39Da17508ec3fE7806a58b0aBe15A2df742cBfE;
    address internal constant oETHETH = 0xC499881FCc94d6755532e2C80b474858a564D637;
    address internal constant ETHPlusETH = 0xD4dF645c88767275fE1C22709BE415bD7B509199;
    address internal constant weETHETH = 0x04F50861b2CeC7831B27b74b565EfEeCeABED4Fd;
    address internal constant ezETHETH = 0x2E5c0B799eFbe406b98b7D5aDA26d6CD31734D6d;
    address internal constant rsETHETH = 0xB0dC8194eCA11EF10B4451BD596ed29049a2cf7c;
    address internal constant amphrETHETH = 0x517Cb608a08875FF60407F0209a87e093955A6C6;
    address internal constant steakLRTETH =0xc09B45b31b7DD7B7bEcb348f1Df192C6948986B9;
    address internal constant pzETHETH = 0x0E45B0bc6D05872E355cca26f14ec5519E302db6;
    address internal constant rstETHETH = 0x804C4fC1eb2202332eabaB8d2d81b1A5Cd48D875;

    // Base=0% APY  Kink(90%)=2.7% APY  Max=82.7% APY
    // baseRate=0 slope1=218407859 slope2=42500370385 kink=3865470566
    // already deployed at https://etherscan.io/address/0x3fF20b354dCc623073647e4F2a2cD955A45Defb1#readContract
    address internal constant IRM = 0x3fF20b354dCc623073647e4F2a2cD955A45Defb1;

    mapping(address => address) internal escrowVaults;
    mapping(address => address) internal governedVaults;

    address oracleRouter;
    address[] internal assets;
    bool[] internal isAssetERC4626;
    address[] internal oracleAdapters;
    uint16[] internal escrowSupplyCaps;
    uint16[] internal governedMaxLiquidationDiscounts;
    uint16[] internal governedInterestFees;
    address[] internal governedInterestRateModels;
    uint16[][] internal LTVs;

    constructor() {
        assets           = [wstETH,    cbETH,    rETH,    woETH,   ETHPlus,    weETH,    ezETH,    rsETH,    amphrETH,    steakLRT,    pzETH,    rstETH];
        isAssetERC4626   = [false,     false,    false,   true,    false,      false,    false,    false,    false,       false,       false,    false];
        oracleAdapters   = [wstETHETH, cbETHETH, rETHETH, oETHETH, ETHPlusETH, weETHETH, ezETHETH, rsETHETH, amphrETHETH, steakLRTETH, pzETHETH, rstETHETH];
        escrowSupplyCaps = [20_000,    600,      10_000,  3_000,   500,        12_000,   3_000,    4_000,    7_000,       7_000,       7_000,    7_000];
        escrowSupplyCaps = encodeAmountCaps(assets, escrowSupplyCaps);

        //                                 WETH     wstETH
        governedMaxLiquidationDiscounts = [0.15e4,   0.15e4];
        governedInterestFees            = [0.10e4,   0.10e4];
        governedInterestRateModels      = [IRM,      IRM];
        LTVs            = /* wstETH   */ [[0.945e4, 0.000e4],
                          /* cbETH    */  [0.860e4, 0.000e4],
                          /* rETH     */  [0.860e4, 0.000e4],
                          /* woETH    */  [0.860e4, 0.000e4],
                          /* ETHPlus  */  [0.860e4, 0.000e4],
                          /* weETH    */  [0.860e4, 0.000e4],
                          /* ezETH    */  [0.945e4, 0.000e4],
                          /* rsETH    */  [0.860e4, 0.000e4],
                          /* amphrETH */  [0.900e4, 0.900e4],
                          /* steakLRT */  [0.900e4, 0.900e4],
                          /* pzETH    */  [0.900e4, 0.900e4],
                          /* rstETH   */  [0.900e4, 0.900e4]];
    }

    function run() public returns (address eWETH, address eWstETH) {
        // deploy the oracle router
        {
            OracleRouterDeployer deployer = new OracleRouterDeployer();
            oracleRouter = deployer.deploy(peripheryAddresses.oracleRouterFactory);
        }

        // deploy the vaults
        {
            EVaultDeployer deployer = new EVaultDeployer();
            for (uint256 i = 0; i < assets.length; ++i) {
                address asset = assets[i];
                escrowVaults[asset] = deployer.deploy(coreAddresses.eVaultFactory, true, asset);
            }
            governedVaults[WETH] = deployer.deploy(coreAddresses.eVaultFactory, true, WETH, oracleRouter, WETH);
            governedVaults[wstETH] = deployer.deploy(coreAddresses.eVaultFactory, true, wstETH, oracleRouter, WETH);
        }

        // configure the oracle router
        for (uint256 i = 0; i < assets.length; ++i) {
            address asset = assets[i];
            govSetResolvedVault(oracleRouter, escrowVaults[asset], true);

            if (isAssetERC4626[i]) {
                govSetResolvedVault(oracleRouter, asset, true);
                govSetConfig(oracleRouter, IEVault(asset).asset(), WETH, oracleAdapters[i]);
            } else {
                govSetConfig(oracleRouter, asset, WETH, oracleAdapters[i]);
            }
        }
        transferGovernance(oracleRouter, ORACLE_ROUTER_GOVERNOR);

        // configure the escrow vaults and verify them by the escrow perspective
        for (uint256 i = 0; i < assets.length; ++i) {
            address vault = escrowVaults[assets[i]];
            setCaps(vault, escrowSupplyCaps[i], 0);
            setHookConfig(vault, address(0), 0);
            setGovernorAdmin(vault, address(0));
            perspectiveVerify(peripheryAddresses.escrowedCollateralPerspective, vault);
        }

        // configure the governed vaults
        for (uint256 i = 0; i < 2; ++i) {
            address vault = i == 0 ? governedVaults[WETH] : governedVaults[wstETH];
            setMaxLiquidationDiscount(vault, governedMaxLiquidationDiscounts[i]);
            setLiquidationCoolOffTime(vault, 1);
            setInterestRateModel(vault, governedInterestRateModels[i]);
            setInterestFee(vault, governedInterestFees[i]);
            setFeeReceiver(vault, GOVERNED_VAULTS_FEE_RECEIVER);

            for (uint256 j = 0; j < assets.length; ++j) {
                address collateral = escrowVaults[assets[j]];
                uint16 ltv = LTVs[j][i];

                if (ltv != 0) setLTV(vault, collateral, ltv - 0.025e4, ltv, 0);
            }

            setHookConfig(vault, address(0), 0);
            setGovernorAdmin(vault, GOVERNED_VAULTS_GOVERNOR);
        }
        
        executeBatch();

        // sanity check the oracle config
        OracleVerifier.verifyOracleConfig(governedVaults[WETH]);
        OracleVerifier.verifyOracleConfig(governedVaults[wstETH]);

        // sanity perspective check
        PerspectiveVerifier.verifyPerspective(
            peripheryAddresses.eulerUngoverned0xPerspective,
            governedVaults[WETH],
            PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | PerspectiveVerifier.E__GOVERNOR
        );
        PerspectiveVerifier.verifyPerspective(
            peripheryAddresses.eulerUngoverned0xPerspective,
            governedVaults[wstETH],
            PerspectiveVerifier.E__ORACLE_GOVERNED_ROUTER | PerspectiveVerifier.E__GOVERNOR
        );

        // prepare the results
        eWETH = governedVaults[WETH];
        eWstETH = governedVaults[wstETH];
    }
}
