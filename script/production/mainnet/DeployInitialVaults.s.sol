// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, CoreAddressesLib, PeripheryAddressesLib} from "../../utils/ScriptUtils.s.sol";
import {KinkIRM} from "../../04_KinkIRM.s.sol";
import {EVaultDeployer} from "../../07_EVault.s.sol";
import {EulerRouterFactory} from "../../../src/EulerRouterFactory/EulerRouterFactory.sol";
import {BasePerspective} from "../../../src/Perspectives/implementation/BasePerspective.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";

contract DeployInitialVaults is ScriptUtils, CoreAddressesLib, PeripheryAddressesLib {
    address internal constant USD = address(840);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address[] internal assetsList;

    // TODO double check
    address internal constant WETHUSD = 0x10674C8C1aE2072d4a75FE83f1E159425fd84E1D;
    address internal constant wstETHUSD = 0x02dd5B7ab536629d2235276aBCDf8eb3Af9528D7;
    address internal constant USDCUSD = 0x6213f24332D35519039f2afa7e3BffE105a37d3F;
    address internal constant USDTUSD = 0x587CABe0521f5065b561A6e68c25f338eD037FF9;
    address[] internal oracleAdaptersList;

    address internal constant DAO_MULTISIG = 0xcAD001c30E96765aC90307669d578219D4fb1DCe;
    address internal constant ORACLE_ROUTER_GOVERNOR = DAO_MULTISIG;
    address internal constant RISK_OFF_VAULTS_GOVERNOR = DAO_MULTISIG;

    mapping(address => address) internal escrowVaults;
    mapping(address => address) internal riskOffVaults;

    uint16[][] internal riskOffEscrowLTVs;
    uint16[][] internal riskOffRiskOffLTVs;
    address[] internal irmList;

    constructor() {
        assetsList = [WETH, wstETH, USDC, USDT];
        oracleAdaptersList = [WETHUSD, wstETHUSD, USDCUSD, USDTUSD];

        riskOffEscrowLTVs = [
            [0, 0.89e4, 0.83e4, 0.83e4],
            [0.89e4, 0, 0.8e4, 0.8e4],
            [0.76e4, 0.76e4, 0, 0.87e4],
            [0.76e4, 0.76e4, 0.87e4, 0]
        ];

        riskOffRiskOffLTVs = [
            [0, 0.87e4, 0.81e4, 0.81e4],
            [0.87e4, 0, 0.78e4, 0.78e4],
            [0.74e4, 0.74e4, 0, 0.85e4],
            [0.74e4, 0.74e4, 0.85e4, 0]
        ];
    }

    function run() public returns (address[] memory) {
        CoreAddresses memory coreAddresses = deserializeCoreAddresses(getInputConfig("CoreAddresses.json"));
        PeripheryAddresses memory peripheryAddresses =
            deserializePeripheryAddresses(getInputConfig("PeripheryAddresses.json"));

        // deploy the oracle router
        startBroadcast();
        address oracleRouter = EulerRouterFactory(peripheryAddresses.oracleRouterFactory).deploy(getDeployer());
        stopBroadcast();

        // deploy the IRMs
        {
            KinkIRM deployer = new KinkIRM();

            // Base=0% APY  Kink(90%)=2.7% APY  Max=82.7% APY
            address irmWETH = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 218407859, 42500370385, 3865470566);

            // Base=0% APY  Kink(45%)=4.75% APY  Max=84.75% APY
            address irmWstETH = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 760869530, 7611888145, 1932735283);

            // Base=0% APY  Kink(92%)=6.5% APY  Max=66.5% APY
            address irmUSDC = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 505037995, 41211382066, 3951369912);

            // Base=0% APY  Kink(92%)=6.5% APY  Max=81.5% APY
            address irmUSDT = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 505037995, 49166860226, 3951369912);

            irmList = [irmWETH, irmWstETH, irmUSDC, irmUSDT];
        }

        // deploy the vaults
        {
            EVaultDeployer deployer = new EVaultDeployer();
            for (uint256 i = 0; i < assetsList.length; ++i) {
                address asset = assetsList[i];

                (, escrowVaults[asset]) =
                    deployer.deploy(address(0), false, coreAddresses.eVaultFactory, true, asset, address(0), address(0));

                (, riskOffVaults[asset]) =
                    deployer.deploy(address(0), false, coreAddresses.eVaultFactory, true, asset, oracleRouter, USD);
            }
        }

        // configure the oracle router
        startBroadcast();
        for (uint256 i = 0; i < assetsList.length; ++i) {
            address asset = assetsList[i];

            EulerRouter(oracleRouter).govSetConfig(asset, USD, oracleAdaptersList[i]);
            EulerRouter(oracleRouter).govSetResolvedVault(escrowVaults[asset], true);
            EulerRouter(oracleRouter).govSetResolvedVault(riskOffVaults[asset], true);
        }

        // transfer the oracle router governance
        EulerRouter(oracleRouter).transferGovernance(ORACLE_ROUTER_GOVERNOR);

        // configure the LTVs
        setLTVs(riskOffVaults, escrowVaults, riskOffEscrowLTVs);
        setLTVs(riskOffVaults, riskOffVaults, riskOffRiskOffLTVs);

        for (uint256 i = 0; i < assetsList.length; ++i) {
            address asset = assetsList[i];

            // configure the escrow vaults and verify them by the escrow perspective
            IEVault(escrowVaults[asset]).setHookConfig(address(0), 0);
            IEVault(escrowVaults[asset]).setGovernorAdmin(address(0));
            BasePerspective(peripheryAddresses.escrowedCollateralPerspective).perspectiveVerify(
                escrowVaults[asset], true
            );

            // configure the riskOff vaults and verify them by the whitelist perspective
            IEVault(riskOffVaults[asset]).setMaxLiquidationDiscount(0.15e4);
            IEVault(riskOffVaults[asset]).setLiquidationCoolOffTime(1);
            IEVault(riskOffVaults[asset]).setInterestRateModel(irmList[i]);
            // TODO check fee and other params
            IEVault(riskOffVaults[asset]).setInterestFee(0.1e4);
            IEVault(riskOffVaults[asset]).setHookConfig(address(0), 0);
            IEVault(riskOffVaults[asset]).setGovernorAdmin(RISK_OFF_VAULTS_GOVERNOR);

            BasePerspective(peripheryAddresses.governedPerspective).perspectiveVerify(riskOffVaults[asset], true);
        }

        stopBroadcast();

        // prepare the results
        address[] memory result = new address[](2 * assetsList.length);
        for (uint256 i = 0; i < assetsList.length; ++i) {
            address asset = assetsList[i];
            result[i] = escrowVaults[asset];
            result[i + assetsList.length] = riskOffVaults[asset];
        }
        return result;
    }

    function setLTVs(
        mapping(address => address) storage vaults,
        mapping(address => address) storage collaterals,
        uint16[][] storage ltvs
    ) internal {
        for (uint256 i = 0; i < assetsList.length; ++i) {
            for (uint256 j = 0; j < assetsList.length; ++j) {
                if (i == j) continue;

                address collateralAsset = assetsList[i];
                address vaultAsset = assetsList[j];
                uint16 ltv = ltvs[i][j];

                IEVault(vaults[vaultAsset]).setLTV(collaterals[collateralAsset], ltv - 0.02e4, ltv, 0);
            }
        }
    }
}
