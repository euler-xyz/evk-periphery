// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ScriptUtils, CoreAddressesLib, PeripheryAddressesLib} from "../../utils/ScriptUtils.s.sol";
import {KinkIRM} from "../../04_KinkIRM.s.sol";
import {EVaultDeployer} from "../../07_EVault.s.sol";
import {EulerRouterFactory} from "../../../src/EulerRouterFactory/EulerRouterFactory.sol";
import {BasePerspective} from "../../../src/Perspectives/implementation/BasePerspective.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {ProtocolConfig} from "evk/ProtocolConfig/ProtocolConfig.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";

contract DeployInitialVaults is ScriptUtils, CoreAddressesLib, PeripheryAddressesLib {
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
    address[] internal irmList;

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

            // Base=0% APY  Kink(45%)=4% APY  Max=304% APY
            address irmWBTC = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 643054912, 18204129717, 1932735283);

            // Base=0% APY  Kink(92%)=6.5% APY  Max=66.5% APY
            address irmUSDC = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 505037995, 41211382066, 3951369912);

            // Base=0% APY  Kink(92%)=6.5% APY  Max=81.5% APY
            address irmUSDT = deployer.deploy(peripheryAddresses.kinkIRMFactory, 0, 505037995, 49166860226, 3951369912);

            irmList = [irmWETH, irmWstETH, irmWBTC, irmUSDC, irmUSDT];
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
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](3 * assetsList.length + 1);
        address deployerAddress = getDeployer();

        for (uint256 i = 0; i < assetsList.length; ++i) {
            address asset = assetsList[i];
            uint256 index = 3 * i;

            items[index].targetContract = oracleRouter;
            items[index].onBehalfOfAccount = deployerAddress;
            items[index].data = abi.encodeCall(EulerRouter.govSetConfig, (asset, USD, oracleAdaptersList[i]));

            items[index + 1].targetContract = oracleRouter;
            items[index + 1].onBehalfOfAccount = deployerAddress;
            items[index + 1].data = abi.encodeCall(EulerRouter.govSetResolvedVault, (escrowVaults[asset], true));

            items[index + 2].targetContract = oracleRouter;
            items[index + 2].onBehalfOfAccount = deployerAddress;
            items[index + 2].data = abi.encodeCall(EulerRouter.govSetResolvedVault, (riskOffVaults[asset], true));
        }

        // transfer the oracle router governance
        items[items.length - 1].targetContract = oracleRouter;
        items[items.length - 1].onBehalfOfAccount = deployerAddress;
        items[items.length - 1].data =
            abi.encodeCall(EulerRouter(oracleRouter).transferGovernance, (ORACLE_ROUTER_GOVERNOR));

        IEVC(coreAddresses.evc).batch(items);

        // configure the LTVs
        setLTVs(coreAddresses, riskOffVaults, escrowVaults, riskOffEscrowLTVs);
        setLTVs(coreAddresses, riskOffVaults, riskOffVaults, riskOffRiskOffLTVs);

        items = new IEVC.BatchItem[](10 * assetsList.length);
        for (uint256 i = 0; i < assetsList.length; ++i) {
            address asset = assetsList[i];
            uint256 index = 10 * i;

            // configure the escrow vaults and verify them by the escrow perspective
            items[index].targetContract = escrowVaults[asset];
            items[index].onBehalfOfAccount = deployerAddress;
            items[index].data = abi.encodeCall(IEVault(escrowVaults[asset]).setHookConfig, (address(0), 0));

            items[index + 1].targetContract = escrowVaults[asset];
            items[index + 1].onBehalfOfAccount = deployerAddress;
            items[index + 1].data = abi.encodeCall(IEVault(escrowVaults[asset]).setGovernorAdmin, (address(0)));

            items[index + 2].targetContract = peripheryAddresses.escrowedCollateralPerspective;
            items[index + 2].onBehalfOfAccount = deployerAddress;
            items[index + 2].data = abi.encodeCall(BasePerspective.perspectiveVerify, (escrowVaults[asset], true));

            // configure the riskOff vaults and verify them by the whitelist perspective
            items[index + 3].targetContract = riskOffVaults[asset];
            items[index + 3].onBehalfOfAccount = deployerAddress;
            items[index + 3].data = abi.encodeCall(IEVault(riskOffVaults[asset]).setMaxLiquidationDiscount, (0.15e4));

            items[index + 4].targetContract = riskOffVaults[asset];
            items[index + 4].onBehalfOfAccount = deployerAddress;
            items[index + 4].data = abi.encodeCall(IEVault(riskOffVaults[asset]).setLiquidationCoolOffTime, (1));

            items[index + 5].targetContract = riskOffVaults[asset];
            items[index + 5].onBehalfOfAccount = deployerAddress;
            items[index + 5].data = abi.encodeCall(IEVault(riskOffVaults[asset]).setInterestRateModel, (irmList[i]));

            items[index + 6].targetContract = riskOffVaults[asset];
            items[index + 6].onBehalfOfAccount = deployerAddress;
            items[index + 6].data = abi.encodeCall(IEVault(riskOffVaults[asset]).setInterestFee, (0.1e4));

            items[index + 7].targetContract = riskOffVaults[asset];
            items[index + 7].onBehalfOfAccount = deployerAddress;
            items[index + 7].data = abi.encodeCall(IEVault(riskOffVaults[asset]).setHookConfig, (address(0), 0));

            items[index + 8].targetContract = riskOffVaults[asset];
            items[index + 8].onBehalfOfAccount = deployerAddress;
            items[index + 8].data =
                abi.encodeCall(IEVault(riskOffVaults[asset]).setGovernorAdmin, (RISK_OFF_VAULTS_GOVERNOR));

            items[index + 9].targetContract = peripheryAddresses.governedPerspective;
            items[index + 9].onBehalfOfAccount = deployerAddress;
            items[index + 9].data = abi.encodeCall(BasePerspective.perspectiveVerify, (riskOffVaults[asset], true));
        }

        IEVC(coreAddresses.evc).batch(items);

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
        CoreAddresses memory coreAddresses,
        mapping(address => address) storage vaults,
        mapping(address => address) storage collaterals,
        uint16[][] storage ltvs
    ) internal {
        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](assetsList.length * assetsList.length - assetsList.length);
        address deployerAddress = getDeployer();

        uint256 index;
        for (uint256 i = 0; i < assetsList.length; ++i) {
            for (uint256 j = 0; j < assetsList.length; ++j) {
                if (i == j) continue;

                address collateralAsset = assetsList[i];
                address vaultAsset = assetsList[j];
                uint16 ltv = ltvs[i][j];

                items[index].targetContract = vaults[vaultAsset];
                items[index].onBehalfOfAccount = deployerAddress;
                items[index].data = abi.encodeCall(
                    IEVault(vaults[vaultAsset]).setLTV, (collaterals[collateralAsset], ltv - 0.02e4, ltv, 0)
                );

                ++index;
            }
        }

        IEVC(coreAddresses.evc).batch(items);
    }
}
