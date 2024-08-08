// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, CoreInfoLib} from "../../utils/ScriptUtils.s.sol";
import {KinkIRM} from "../../04_KinkIRM.s.sol";
import {EVault} from "../../07_EVault.s.sol";
import {EulerRouterFactory} from "../../../src/OracleFactory/EulerRouterFactory.sol";
import {BasePerspective} from "../../../src/Perspectives/implementation/BasePerspective.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";

contract InitialVaults is ScriptUtils, CoreInfoLib {
    address internal constant USD = address(840);
    address internal constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address internal constant wstETH = 0x5979D7b546E38E414F7E9822514be443A4800529;
    address internal constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address internal constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address internal constant USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address[] internal assetsList;

    address internal constant WETHUSD = 0xb70977986f38c74aB22D8ffaa0B7E13A7d574dD2;
    address internal constant wstETHUSD = 0x92a31a99ae3d754c6880fCc9eaEe502f5205624E;
    address internal constant WBTCUSD = 0x30Dcb2c78a01B9AD67c8cB8853D09EAEF1842594;
    address internal constant USDCUSD = 0x862b1042f653AE74880D0d3EBf0DDEe90aB8601D;
    address internal constant USDTUSD = 0x53aC2d35D724fc32BdabF1b92Be5B326b76c1205;
    address[] internal oracleAdaptersList;

    address internal constant ORACLE_ROUTER_GOVERNOR = 0x0000000000000000000000000000000000000000; // TODO
    address internal constant RISK_OFF_VAULTS_GOVERNOR = 0x0000000000000000000000000000000000000000; // TODO

    mapping(address => address) internal escrowVaults;
    mapping(address => address) internal riskOffVaults;

    uint16[][] internal riskOffEscrowLTVs;
    uint16[][] internal riskOffRiskOffLTVs;
    address[] internal IRMList;

    constructor() {
        assetsList = [WETH, wstETH, WBTC, USDC, USDT];
        oracleAdaptersList = [WETHUSD, wstETHUSD, WBTCUSD, USDCUSD, USDTUSD];

        riskOffEscrowLTVs = [
            [0, 0.89e4, 0.83e4, 0.83e4, 0.83e4],
            [0.89e4, 0, 0.8e4, 0.8e4, 0.8e4],
            [0.75e4, 0.75e4, 0, 0.75e4, 0.75e4],
            [0.76e4, 0.76e4, 0.76e4, 0, 0.87e4],
            [0.76e4, 0.76e4, 0.76e4, 0.87e4, 0]
        ];

        riskOffRiskOffLTVs = [
            [0, 0.87e4, 0.81e4, 0.81e4, 0.81e4],
            [0.87e4, 0, 0.78e4, 0.78e4, 0.78e4],
            [0.73e4, 0.73e4, 0, 0.73e4, 0.73e4],
            [0.74e4, 0.74e4, 0.74e4, 0, 0.85e4],
            [0.74e4, 0.74e4, 0.74e4, 0.85e4, 0]
        ];
    }

    function run() public returns (address[] memory) {
        CoreInfo memory coreInfo = deserializeCoreInfo(
            vm.readFile(string.concat(vm.projectRoot(), "/script/CoreInfo.json"))
        );

        // deploy the oracle router
        startBroadcast();
        address oracleRouter = EulerRouterFactory(coreInfo.oracleRouterFactory).deploy(getDeployer());
        stopBroadcast();

        // TODO
        // deploy the IRMs
        address defaultIRM = (new KinkIRM()).deploy(coreInfo.kinkIRMFactory, 0, 1406417851, 19050045013, 2147483648);
        IRMList = [defaultIRM, defaultIRM, defaultIRM, defaultIRM, defaultIRM];

        // deploy the vaults
        EVault deployer = new EVault();
        for (uint256 i = 0; i < assetsList.length; ++i) {
            address asset = assetsList[i];

            (, escrowVaults[asset]) =
                deployer.deploy(address(0), false, coreInfo.eVaultFactory, true, asset, address(0), address(0));

            (, riskOffVaults[asset]) =
                deployer.deploy(address(0), false, coreInfo.eVaultFactory, true, asset, oracleRouter, USD);
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
            IEVault(riskOffVaults[asset]).setMaxLiquidationDiscount(0.1e4);
            IEVault(riskOffVaults[asset]).setLiquidationCoolOffTime(1);
            IEVault(riskOffVaults[asset]).setInterestRateModel(IRMList[i]);
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
