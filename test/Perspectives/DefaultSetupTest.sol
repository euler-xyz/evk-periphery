// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {TestERC20} from "evk-test/mocks/TestERC20.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

import {EulerBasePerspective} from "../../src/Perspectives/deployed/EulerBasePerspective.sol";
import {EscrowPerspective} from "../../src/Perspectives/deployed/EscrowPerspective.sol";
import {PerspectiveErrors} from "../../src/Perspectives/implementation/PerspectiveErrors.sol";
import {SnapshotRegistry} from "../../src/OracleFactory/SnapshotRegistry.sol";
import {EulerKinkIRMFactory} from "../../src/IRMFactory/EulerKinkIRMFactory.sol";
import {EulerRouterFactory} from "../../src/OracleFactory/EulerRouterFactory.sol";
import {StubPriceOracle} from "../utils/StubPriceOracle.sol";
import {StubERC4626} from "../utils/StubERC4626.sol";

contract DefaultSetupTest is EVaultTestBase, PerspectiveErrors {
    address internal constant USD = address(840);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address registryOwner = makeAddr("registryOwner");
    address routerGovernor = makeAddr("routerGovernor");

    EulerRouterFactory routerFactory;
    EulerRouter router;
    SnapshotRegistry adapterRegistry;
    SnapshotRegistry externalVaultRegistry;
    EulerKinkIRMFactory irmFactory;

    EscrowPerspective escrowPerspective;
    EulerBasePerspective eulerBasePerspective1;
    EulerBasePerspective eulerBasePerspective2;
    EulerBasePerspective eulerBasePerspective3;

    TestERC20 assetTST3;
    TestERC20 assetTST4;
    StubERC4626 xvTST3; // xv stands for external vault
    StubERC4626 xvTST4;

    address vaultEscrow;
    address vaultBase1;
    address vaultBase2;
    address vaultBase3;
    address vaultBase4xv;
    address vaultBase5xv;

    function setUp() public virtual override {
        super.setUp();

        // set up external erc4626 vaults
        assetTST3 = new TestERC20("Test Token 3", "TST3", 18, false);
        assetTST4 = new TestERC20("Test Token 4", "TST4", 18, false);
        xvTST3 = new StubERC4626(address(assetTST3), 1.1e18);
        xvTST4 = new StubERC4626(address(assetTST4), 1.05e18);

        // deploy the oracle-related contracts
        routerFactory = new EulerRouterFactory();
        router = EulerRouter(routerFactory.deploy(routerGovernor));
        adapterRegistry = new SnapshotRegistry(registryOwner);
        externalVaultRegistry = new SnapshotRegistry(registryOwner);
        irmFactory = new EulerKinkIRMFactory();

        address irmZero = irmFactory.deploy(0, 0, 0, 0);
        address irmDefault = irmFactory.deploy(0, 1406417851, 19050045013, 2147483648);

        // deploy different perspectives
        escrowPerspective = new EscrowPerspective(address(factory));

        address[] memory recognizedCollateralPerspectives = new address[](1);
        recognizedCollateralPerspectives[0] = address(0);
        eulerBasePerspective1 = new EulerBasePerspective(
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(externalVaultRegistry),
            address(irmFactory),
            recognizedCollateralPerspectives
        );

        recognizedCollateralPerspectives[0] = address(escrowPerspective);
        eulerBasePerspective2 = new EulerBasePerspective(
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(externalVaultRegistry),
            address(irmFactory),
            recognizedCollateralPerspectives
        );

        recognizedCollateralPerspectives = new address[](2);
        recognizedCollateralPerspectives[0] = address(escrowPerspective);
        recognizedCollateralPerspectives[1] = address(eulerBasePerspective1);
        eulerBasePerspective3 = new EulerBasePerspective(
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(externalVaultRegistry),
            address(irmFactory),
            recognizedCollateralPerspectives
        );

        // deploy example vaults and configure them
        vaultEscrow =
            factory.createProxy(address(0), false, abi.encodePacked(address(assetTST), address(0), address(0)));
        vaultBase1 = factory.createProxy(address(0), false, abi.encodePacked(address(assetTST), router, USD));
        vaultBase2 = factory.createProxy(address(0), false, abi.encodePacked(address(assetTST2), router, USD));
        vaultBase3 = factory.createProxy(address(0), false, abi.encodePacked(address(assetTST2), router, WETH));
        vaultBase4xv = factory.createProxy(address(0), false, abi.encodePacked(address(xvTST3), router, WETH));
        vaultBase5xv = factory.createProxy(address(0), false, abi.encodePacked(address(xvTST4), router, USD));

        IEVault(vaultEscrow).setGovernorAdmin(address(0));

        IEVault(vaultBase1).setInterestRateModel(irmZero);
        IEVault(vaultBase1).setMaxLiquidationDiscount(0.1e4);
        IEVault(vaultBase1).setLiquidationCoolOffTime(1);
        IEVault(vaultBase1).setLTV(vaultBase2, 0.1e4, 0.2e4, 0);
        IEVault(vaultBase1).setCaps(1, 2);
        IEVault(vaultBase1).setGovernorAdmin(address(0));

        IEVault(vaultBase2).setInterestRateModel(irmDefault);
        IEVault(vaultBase2).setMaxLiquidationDiscount(0.2e4);
        IEVault(vaultBase2).setLiquidationCoolOffTime(1);
        IEVault(vaultBase2).setLTV(vaultBase1, 0.3e4, 0.4e4, 0);
        IEVault(vaultBase2).setGovernorAdmin(address(0));

        IEVault(vaultBase3).setInterestRateModel(irmDefault);
        IEVault(vaultBase3).setMaxLiquidationDiscount(0.2e4);
        IEVault(vaultBase3).setLiquidationCoolOffTime(1);
        IEVault(vaultBase3).setLTV(vaultEscrow, 0.5e4, 0.6e4, 0);
        IEVault(vaultBase3).setGovernorAdmin(address(0));

        IEVault(vaultBase4xv).setInterestRateModel(irmDefault);
        IEVault(vaultBase4xv).setMaxLiquidationDiscount(0.2e4);
        IEVault(vaultBase4xv).setLiquidationCoolOffTime(1);
        IEVault(vaultBase4xv).setLTV(vaultBase5xv, 0.3e4, 0.4e4, 0);
        IEVault(vaultBase4xv).setGovernorAdmin(address(0));

        IEVault(vaultBase5xv).setInterestRateModel(irmZero);
        IEVault(vaultBase5xv).setMaxLiquidationDiscount(0.1e4);
        IEVault(vaultBase5xv).setLiquidationCoolOffTime(1);
        IEVault(vaultBase5xv).setLTV(vaultBase4xv, 0.1e4, 0.2e4, 0);
        IEVault(vaultBase5xv).setCaps(1, 2);
        IEVault(vaultBase5xv).setGovernorAdmin(address(0));

        // configure the oracle
        address stubAdapter_assetTST_USD = address(new StubPriceOracle());
        address stubAdapter_assetTST_WETH = address(new StubPriceOracle());
        address stubAdapter_assetTST2_USD = address(new StubPriceOracle());
        address stubAdapter_assetTST2_WETH = address(new StubPriceOracle());
        address stubAdapter_assetTST3_USD = address(new StubPriceOracle());
        address stubAdapter_assetTST3_WETH = address(new StubPriceOracle());
        address stubAdapter_assetTST4_USD = address(new StubPriceOracle());
        address stubAdapter_assetTST4_WETH = address(new StubPriceOracle());
        vm.startPrank(registryOwner);
        adapterRegistry.add(stubAdapter_assetTST_USD, address(assetTST), USD);
        adapterRegistry.add(stubAdapter_assetTST_WETH, address(assetTST), WETH);
        adapterRegistry.add(stubAdapter_assetTST2_USD, address(assetTST2), USD);
        adapterRegistry.add(stubAdapter_assetTST2_WETH, address(assetTST2), WETH);
        adapterRegistry.add(stubAdapter_assetTST3_USD, address(assetTST3), USD);
        adapterRegistry.add(stubAdapter_assetTST3_WETH, address(assetTST3), WETH);
        adapterRegistry.add(stubAdapter_assetTST4_USD, address(assetTST4), USD);
        adapterRegistry.add(stubAdapter_assetTST4_WETH, address(assetTST4), WETH);
        externalVaultRegistry.add(address(xvTST3), address(xvTST3), address(assetTST3));
        externalVaultRegistry.add(address(xvTST4), address(xvTST4), address(assetTST4));
        vm.stopPrank();

        vm.startPrank(routerGovernor);
        router.govSetResolvedVault(vaultEscrow, true);
        router.govSetResolvedVault(vaultBase1, true);
        router.govSetResolvedVault(vaultBase2, true);
        router.govSetResolvedVault(vaultBase3, true);
        router.govSetResolvedVault(vaultBase4xv, true);
        router.govSetResolvedVault(vaultBase5xv, true);
        router.govSetResolvedVault(address(xvTST3), true);
        router.govSetResolvedVault(address(xvTST4), true);
        router.govSetConfig(address(assetTST), USD, stubAdapter_assetTST_USD);
        router.govSetConfig(address(assetTST), WETH, stubAdapter_assetTST_WETH);
        router.govSetConfig(address(assetTST2), USD, stubAdapter_assetTST2_USD);
        router.govSetConfig(address(assetTST2), WETH, stubAdapter_assetTST2_WETH);
        router.govSetConfig(address(assetTST3), USD, stubAdapter_assetTST3_USD);
        router.govSetConfig(address(assetTST3), WETH, stubAdapter_assetTST3_WETH);
        router.govSetConfig(address(assetTST4), USD, stubAdapter_assetTST4_USD);
        router.govSetConfig(address(assetTST4), WETH, stubAdapter_assetTST4_WETH);
        router.transferGovernance(address(0));
        vm.stopPrank();

        vm.label(address(escrowPerspective), "escrowPerspective");
        vm.label(address(eulerBasePerspective1), "eulerBasePerspective1");
        vm.label(address(eulerBasePerspective2), "eulerBasePerspective2");
        vm.label(address(eulerBasePerspective3), "eulerBasePerspective3");
        vm.label(vaultEscrow, "vaultEscrow");
        vm.label(vaultBase1, "vaultBase1");
        vm.label(vaultBase2, "vaultBase2");
        vm.label(vaultBase3, "vaultBase3");
        vm.label(vaultBase4xv, "vaultBase4xv");
        vm.label(vaultBase5xv, "vaultBase5xv");
        vm.label(address(assetTST3), "assetTST3");
        vm.label(address(assetTST4), "assetTST4");
        vm.label(address(xvTST3), "xvTST3");
        vm.label(address(xvTST4), "xvTST4");
    }
}
