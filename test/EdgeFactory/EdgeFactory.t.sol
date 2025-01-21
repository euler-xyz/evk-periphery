// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {EdgeFactory} from "../../src/EdgeFactory/EdgeFactory.sol";
import {IEdgeFactory} from "../../src/EdgeFactory/interfaces/IEdgeFactory.sol";
import {EulerRouterFactory} from "../../src/EulerRouterFactory/EulerRouterFactory.sol";

import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {StubPriceOracle} from "euler-price-oracle-test/adapter/StubPriceOracle.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IRMTestDefault} from "evk-test/mocks/IRMTestDefault.sol";
import {TestERC20} from "evk-test/mocks/TestERC20.sol";

contract EdgeFactoryTest is EVaultTestBase {
    EdgeFactory edgeFactory;
    EulerRouterFactory eulerRouterFactory;
    address irm;
    StubPriceOracle stubOracle;

    function setUp() public override {
        super.setUp();
        eulerRouterFactory = new EulerRouterFactory(address(evc));
        edgeFactory = new EdgeFactory(address(factory), address(eulerRouterFactory));
        irm = address(new IRMTestDefault());
        stubOracle = new StubPriceOracle();
    }

    function testDeploy_Simple() public {
        IEdgeFactory.VaultParams[] memory vaultParams = new IEdgeFactory.VaultParams[](2);
        vaultParams[0] = IEdgeFactory.VaultParams(address(assetTST), irm, true);
        vaultParams[1] = IEdgeFactory.VaultParams(address(assetTST2), irm, true);

        IEdgeFactory.AdapterParams[] memory adapterParams = new IEdgeFactory.AdapterParams[](2);
        adapterParams[0] = IEdgeFactory.AdapterParams(address(assetTST), unitOfAccount, address(stubOracle));
        adapterParams[1] = IEdgeFactory.AdapterParams(address(assetTST2), unitOfAccount, address(stubOracle));

        address[] memory externalVaults = new address[](0);
        IEdgeFactory.RouterParams memory routerParams = IEdgeFactory.RouterParams(externalVaults, adapterParams);

        IEdgeFactory.LTVParams[] memory ltvParams = new IEdgeFactory.LTVParams[](2);
        ltvParams[0] = IEdgeFactory.LTVParams(0, 1, 0.8e4, 0.9e4);
        ltvParams[1] = IEdgeFactory.LTVParams(1, 0, 0.8e4, 0.9e4);

        IEdgeFactory.DeployParams memory deployParams =
            IEdgeFactory.DeployParams(vaultParams, routerParams, ltvParams, unitOfAccount);

        stubOracle.setPrice(address(assetTST), address(unitOfAccount), 1e18);
        stubOracle.setPrice(address(assetTST2), address(unitOfAccount), 1e18);

        (address router, address[] memory vaults) = edgeFactory.deploy(deployParams);
        _verifyDeployment(router, vaults, deployParams);
    }

    function testDeploy_Large() public {
        TestERC20 assetTST3 = new TestERC20("Test Token 3", "TST3", 18, false);
        TestERC20 assetTST4 = new TestERC20("Test Token 4", "TST4", 18, false);
        TestERC20 assetTST5 = new TestERC20("Test Token 5", "TST5", 18, false);

        IEdgeFactory.VaultParams[] memory vaultParams = new IEdgeFactory.VaultParams[](5);
        vaultParams[0] = IEdgeFactory.VaultParams(address(assetTST), irm, true);
        vaultParams[1] = IEdgeFactory.VaultParams(address(assetTST2), address(0), false);
        vaultParams[2] = IEdgeFactory.VaultParams(address(assetTST3), address(0), false);
        vaultParams[3] = IEdgeFactory.VaultParams(address(assetTST4), address(0), false);
        vaultParams[4] = IEdgeFactory.VaultParams(address(assetTST5), address(0), false);

        IEdgeFactory.AdapterParams[] memory adapterParams = new IEdgeFactory.AdapterParams[](5);
        adapterParams[0] = IEdgeFactory.AdapterParams(address(assetTST), unitOfAccount, address(stubOracle));
        adapterParams[1] = IEdgeFactory.AdapterParams(address(assetTST2), unitOfAccount, address(stubOracle));
        adapterParams[2] = IEdgeFactory.AdapterParams(address(assetTST3), unitOfAccount, address(stubOracle));
        adapterParams[3] = IEdgeFactory.AdapterParams(address(assetTST4), unitOfAccount, address(stubOracle));
        adapterParams[4] = IEdgeFactory.AdapterParams(address(assetTST5), unitOfAccount, address(stubOracle));

        address[] memory externalVaults = new address[](0);
        IEdgeFactory.RouterParams memory routerParams = IEdgeFactory.RouterParams(externalVaults, adapterParams);

        IEdgeFactory.LTVParams[] memory ltvParams = new IEdgeFactory.LTVParams[](4);
        ltvParams[0] = IEdgeFactory.LTVParams(0, 1, 0.8e4, 0.9e4);
        ltvParams[1] = IEdgeFactory.LTVParams(0, 2, 0.8e4, 0.9e4);
        ltvParams[2] = IEdgeFactory.LTVParams(0, 3, 0.8e4, 0.9e4);
        ltvParams[3] = IEdgeFactory.LTVParams(0, 4, 0.8e4, 0.9e4);

        IEdgeFactory.DeployParams memory deployParams =
            IEdgeFactory.DeployParams(vaultParams, routerParams, ltvParams, unitOfAccount);

        stubOracle.setPrice(address(assetTST), address(unitOfAccount), 1e18);
        stubOracle.setPrice(address(assetTST2), address(unitOfAccount), 1e18);
        stubOracle.setPrice(address(assetTST3), address(unitOfAccount), 1e18);
        stubOracle.setPrice(address(assetTST4), address(unitOfAccount), 1e18);
        stubOracle.setPrice(address(assetTST5), address(unitOfAccount), 1e18);

        (address router, address[] memory vaults) = edgeFactory.deploy(deployParams);
        _verifyDeployment(router, vaults, deployParams);
    }

    function testDeploy_RevertsWhenTooSmall() public {
        IEdgeFactory.VaultParams[] memory vaultParams = new IEdgeFactory.VaultParams[](1);
        vaultParams[0] = IEdgeFactory.VaultParams(address(assetTST), irm, true);

        IEdgeFactory.AdapterParams[] memory adapterParams = new IEdgeFactory.AdapterParams[](1);
        adapterParams[0] = IEdgeFactory.AdapterParams(address(assetTST), unitOfAccount, address(stubOracle));

        address[] memory externalVaults = new address[](0);
        IEdgeFactory.RouterParams memory routerParams = IEdgeFactory.RouterParams(externalVaults, adapterParams);

        IEdgeFactory.LTVParams[] memory ltvParams = new IEdgeFactory.LTVParams[](0);

        IEdgeFactory.DeployParams memory deployParams =
            IEdgeFactory.DeployParams(vaultParams, routerParams, ltvParams, unitOfAccount);

        stubOracle.setPrice(address(assetTST), address(unitOfAccount), 1e18);

        vm.expectRevert(IEdgeFactory.E_TooFewVaults.selector);
        edgeFactory.deploy(deployParams);
    }

    function testDeploy_HandlesNonBorrowableVault() public {
        IEdgeFactory.VaultParams[] memory vaultParams = new IEdgeFactory.VaultParams[](2);
        vaultParams[0] = IEdgeFactory.VaultParams(address(assetTST), irm, true);
        vaultParams[1] = IEdgeFactory.VaultParams(address(assetTST2), irm, false);

        IEdgeFactory.AdapterParams[] memory adapterParams = new IEdgeFactory.AdapterParams[](2);
        adapterParams[0] = IEdgeFactory.AdapterParams(address(assetTST), unitOfAccount, address(stubOracle));
        adapterParams[1] = IEdgeFactory.AdapterParams(address(assetTST2), unitOfAccount, address(stubOracle));

        address[] memory externalVaults = new address[](0);
        IEdgeFactory.RouterParams memory routerParams = IEdgeFactory.RouterParams(externalVaults, adapterParams);

        IEdgeFactory.LTVParams[] memory ltvParams = new IEdgeFactory.LTVParams[](1);
        ltvParams[0] = IEdgeFactory.LTVParams(0, 1, 0.8e4, 0.9e4);

        IEdgeFactory.DeployParams memory deployParams =
            IEdgeFactory.DeployParams(vaultParams, routerParams, ltvParams, unitOfAccount);

        stubOracle.setPrice(address(assetTST), address(unitOfAccount), 1e18);
        stubOracle.setPrice(address(assetTST2), address(unitOfAccount), 1e18);

        (address router, address[] memory vaults) = edgeFactory.deploy(deployParams);
        _verifyDeployment(router, vaults, deployParams);
    }

    function testDeploy_RevertsWhenLTVForNonBorrowableVault() public {
        IEdgeFactory.VaultParams[] memory vaultParams = new IEdgeFactory.VaultParams[](2);
        vaultParams[0] = IEdgeFactory.VaultParams(address(assetTST), irm, true);
        vaultParams[1] = IEdgeFactory.VaultParams(address(assetTST2), irm, false);

        IEdgeFactory.AdapterParams[] memory adapterParams = new IEdgeFactory.AdapterParams[](2);
        adapterParams[0] = IEdgeFactory.AdapterParams(address(assetTST), unitOfAccount, address(stubOracle));
        adapterParams[1] = IEdgeFactory.AdapterParams(address(assetTST2), unitOfAccount, address(stubOracle));

        address[] memory externalVaults = new address[](0);
        IEdgeFactory.RouterParams memory routerParams = IEdgeFactory.RouterParams(externalVaults, adapterParams);

        IEdgeFactory.LTVParams[] memory ltvParams = new IEdgeFactory.LTVParams[](1);
        ltvParams[0] = IEdgeFactory.LTVParams(1, 0, 0.8e4, 0.9e4);

        IEdgeFactory.DeployParams memory deployParams =
            IEdgeFactory.DeployParams(vaultParams, routerParams, ltvParams, unitOfAccount);

        stubOracle.setPrice(address(assetTST), address(unitOfAccount), 1e18);
        stubOracle.setPrice(address(assetTST2), address(unitOfAccount), 1e18);

        vm.expectRevert(IEdgeFactory.E_LTVForNonBorrowableVault.selector);
        edgeFactory.deploy(deployParams);
    }

    function testDeploy_HandlesExternalVaults() public {
        IEdgeFactory.VaultParams[] memory vaultParams = new IEdgeFactory.VaultParams[](2);
        vaultParams[0] = IEdgeFactory.VaultParams(address(assetTST), irm, true);
        vaultParams[1] = IEdgeFactory.VaultParams(address(assetTST2), irm, false);

        IEdgeFactory.AdapterParams[] memory adapterParams = new IEdgeFactory.AdapterParams[](2);
        adapterParams[0] = IEdgeFactory.AdapterParams(address(assetTST), unitOfAccount, address(stubOracle));
        adapterParams[1] = IEdgeFactory.AdapterParams(address(assetTST2), unitOfAccount, address(stubOracle));

        address[] memory externalVaults = new address[](2);
        externalVaults[0] = address(assetTST);
        externalVaults[1] = address(assetTST2);
        IEdgeFactory.RouterParams memory routerParams = IEdgeFactory.RouterParams(externalVaults, adapterParams);

        IEdgeFactory.LTVParams[] memory ltvParams = new IEdgeFactory.LTVParams[](1);
        ltvParams[0] = IEdgeFactory.LTVParams(0, 1, 0.8e4, 0.9e4);

        IEdgeFactory.DeployParams memory deployParams =
            IEdgeFactory.DeployParams(vaultParams, routerParams, ltvParams, unitOfAccount);

        vm.mockCall(
            address(assetTST), abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(makeAddr("assetTST.asset"))
        );
        vm.mockCall(
            address(assetTST2), abi.encodeWithSelector(IERC4626.asset.selector), abi.encode(makeAddr("assetTST2.asset"))
        );
        stubOracle.setPrice(address(assetTST), address(unitOfAccount), 1e18);
        stubOracle.setPrice(address(assetTST2), address(unitOfAccount), 1e18);

        (address router, address[] memory vaults) = edgeFactory.deploy(deployParams);
        _verifyDeployment(router, vaults, deployParams);
    }

    function _verifyDeployment(address router, address[] memory vaults, IEdgeFactory.DeployParams memory deployParams)
        internal
        view
    {
        // Verify vaults
        IEdgeFactory.VaultParams[] memory vaultParams = deployParams.vaults;
        IEdgeFactory.LTVParams[] memory ltvParams = deployParams.ltv;
        IEdgeFactory.RouterParams memory routerParams = deployParams.router;
        IEdgeFactory.AdapterParams[] memory adapterParams = routerParams.adapters;

        assertEq(vaults.length, vaultParams.length);
        for (uint256 i; i < vaults.length; ++i) {
            assertEq(vaults[i], factory.proxyList(i + 2));
            assertEq(IEVault(vaults[i]).asset(), vaultParams[i].asset);
            assertEq(IEVault(vaults[i]).oracle(), router);
            assertEq(IEVault(vaults[i]).unitOfAccount(), deployParams.unitOfAccount);
            assertEq(IEVault(vaults[i]).governorAdmin(), address(0));

            if (vaultParams[i].borrowable) {
                assertEq(IEVault(vaults[i]).interestRateModel(), vaultParams[i].irm);
                assertEq(IEVault(vaults[i]).interestFee(), 0.1e4);
                assertEq(IEVault(vaults[i]).liquidationCoolOffTime(), 1);
                assertEq(IEVault(vaults[i]).maxLiquidationDiscount(), 0.15e4);
            }
        }

        // Verify LTVs
        for (uint256 i; i < ltvParams.length; ++i) {
            (
                uint16 borrowLTV,
                uint16 liquidationLTV,
                uint16 initialLiquidationLTV,
                uint48 targetTimestamp,
                uint32 rampDuration
            ) = IEVault(vaults[ltvParams[i].controllerVaultIndex]).LTVFull(vaults[ltvParams[i].collateralVaultIndex]);
            assertEq(borrowLTV, ltvParams[i].borrowLTV);
            assertEq(liquidationLTV, ltvParams[i].liquidationLTV);
            assertEq(initialLiquidationLTV, 0);
            assertEq(targetTimestamp, block.timestamp);
            assertEq(rampDuration, 0);
        }

        // Verify pricing
        assertEq(router, eulerRouterFactory.deployments(0));
        assertEq(EulerRouter(router).governor(), address(0));
        for (uint256 i; i < vaults.length; ++i) {
            assertEq(EulerRouter(router).resolvedVaults(vaults[i]), IEVault(vaults[i]).asset());
        }

        for (uint256 i; i < adapterParams.length; ++i) {
            assertEq(
                EulerRouter(router).getConfiguredOracle(adapterParams[i].base, adapterParams[i].quote),
                adapterParams[i].adapter
            );
        }

        for (uint256 i; i < routerParams.externalResolvedVaults.length; ++i) {
            assertEq(
                EulerRouter(router).resolvedVaults(routerParams.externalResolvedVaults[i]),
                IERC4626(routerParams.externalResolvedVaults[i]).asset()
            );
        }
    }
}
