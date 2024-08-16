// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, CoreInfoLib} from "../../utils/ScriptUtils.s.sol";
import {KinkIRM} from "../../04_KinkIRM.s.sol";
import {EVault} from "../../07_EVault.s.sol";
import {EulerRouterFactory} from "../../../src/EulerRouterFactory/EulerRouterFactory.sol";
import {BasePerspective} from "../../../src/Perspectives/implementation/BasePerspective.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";

contract InitialVaults is ScriptUtils, CoreInfoLib {
    address internal constant USD = address(840);
    address internal constant WETH = 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2;
    address internal constant wstETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    // address internal constant sDAI = ;
    address[] internal assetsList;

    address internal constant WETHUSD = 0x9ba991C56eB386AB58A3373215Afb5cf52ed78A7;
    address internal constant wstETHUSD = 0x509aB758603aaf54Ad64567137C5cFA522a899d1;
    address internal constant USDCUSD = 0xa87dA6Bb80fB51155D245B0A6f27184E425B4952;
    address internal constant USDTUSD = 0x3B66ebD98f9E5D53A9d2Cc7ffFD2F760f7EbDD19;
    // address internal constant sDAIUSD = ;
    address[] internal oracleAdaptersList;

    address internal constant ORACLE_ROUTER_GOVERNOR = 0x0000000000000000000000000000000000000000; // TODO
    address internal constant RISK_OFF_VAULTS_GOVERNOR = 0x0000000000000000000000000000000000000000; // TODO

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
        CoreInfo memory coreInfo =
            deserializeCoreInfo(vm.readFile(string.concat(vm.projectRoot(), "/script/CoreInfo.json")));

        // deploy the oracle router
        startBroadcast();
        address oracleRouter = EulerRouterFactory(coreInfo.oracleRouterFactory).deploy(getDeployer());
        stopBroadcast();

        {
            KinkIRM deployer = new KinkIRM();

            // Base=0% APY  Kink(90%)=2.7% APY  Max=82.7% APY
            address irmWETH = deployer.deploy(coreInfo.kinkIRMFactory, 0, 218407859, 42500370385, 3865470566);

            // Base=0% APY  Kink(45%)=4.75% APY  Max=84.75% APY
            address irmWstETH = deployer.deploy(coreInfo.kinkIRMFactory, 0, 760869530, 7611888145, 1932735283);

            // Base=0% APY  Kink(92%)=6.5% APY  Max=66.5% APY
            address irmUSDC = deployer.deploy(coreInfo.kinkIRMFactory, 0, 505037995, 41211382066, 3951369912);

            // Base=0% APY  Kink(92%)=6.5% APY  Max=81.5% APY
            address irmUSDT = deployer.deploy(coreInfo.kinkIRMFactory, 0, 505037995, 49166860226, 3951369912);

            irmList = [irmWETH, irmWstETH, irmUSDC, irmUSDT];
        }

        // deploy the vaults
        {
            EVault deployer = new EVault();
            for (uint256 i = 0; i < assetsList.length; ++i) {
                address asset = assetsList[i];

                (, escrowVaults[asset]) =
                    deployer.deploy(address(0), false, coreInfo.eVaultFactory, true, asset, address(0), address(0));

                (, riskOffVaults[asset]) =
                    deployer.deploy(address(0), false, coreInfo.eVaultFactory, true, asset, oracleRouter, USD);
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

            // allow lower interest fee by configuring the protocol config
            ProtocolConfig(coreInfo.protocolConfig).setVaultInterestFeeRange(riskOffVaults[asset], true, 0.05e4, 1e4);

            // configure the escrow vaults and verify them by the escrow perspective
            IEVault(escrowVaults[asset]).setHookConfig(address(0), 0);
            IEVault(escrowVaults[asset]).setGovernorAdmin(address(0));
            BasePerspective(coreInfo.escrowPerspective).perspectiveVerify(escrowVaults[asset], true);

            // configure the riskOff vaults and verify them by the whitelist perspective
            IEVault(riskOffVaults[asset]).setMaxLiquidationDiscount(0.15e4);
            IEVault(riskOffVaults[asset]).setLiquidationCoolOffTime(1);
            IEVault(riskOffVaults[asset]).setInterestRateModel(irmList[i]);
            IEVault(riskOffVaults[asset]).setInterestFee(0.05e4);
            IEVault(riskOffVaults[asset]).setHookConfig(address(0), 0);
            IEVault(riskOffVaults[asset]).setGovernorAdmin(RISK_OFF_VAULTS_GOVERNOR);
            BasePerspective(coreInfo.governableWhitelistPerspective).perspectiveVerify(riskOffVaults[asset], true);
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
