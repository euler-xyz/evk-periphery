// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {TestERC20} from "evk-test/mocks/TestERC20.sol";
import {IRMLinearKink} from "evk/InterestRateModels/IRMLinearKink.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

import {EulerUngovernedPerspective} from "../../src/Perspectives/deployed/EulerUngovernedPerspective.sol";
import {EscrowedCollateralPerspective} from "../../src/Perspectives/deployed/EscrowedCollateralPerspective.sol";
import {PerspectiveErrors} from "../../src/Perspectives/implementation/PerspectiveErrors.sol";
import {SnapshotRegistry} from "../../src/SnapshotRegistry/SnapshotRegistry.sol";
import {EulerKinkIRMFactory} from "../../src/IRMFactory/EulerKinkIRMFactory.sol";
import {EulerRouterFactory} from "../../src/EulerRouterFactory/EulerRouterFactory.sol";
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
    SnapshotRegistry irmRegistry;

    EscrowedCollateralPerspective escrowedCollateralPerspective;
    EulerUngovernedPerspective eulerUngovernedPerspective1;
    EulerUngovernedPerspective eulerUngovernedPerspective2;
    EulerUngovernedPerspective eulerUngovernedPerspective3;

    TestERC20 assetTST3;
    TestERC20 assetTST4;
    StubERC4626 xvTST3; // xv stands for external vault
    StubERC4626 xvTST4;

    address vaultEscrow;
    address vaultBase1;
    address vaultBase2;
    address vaultBase3;
    address vaultBase4;
    address vaultBase5xv;
    address vaultBase6xv;

    function setUp() public virtual override {
        super.setUp();

        // set up external erc4626 vaults
        assetTST3 = new TestERC20("Test Token 3", "TST3", 18, false);
        assetTST4 = new TestERC20("Test Token 4", "TST4", 18, false);
        xvTST3 = new StubERC4626(address(assetTST3), 1.1e18);
        xvTST4 = new StubERC4626(address(assetTST4), 1.05e18);

        // deploy the oracle-related contracts
        routerFactory = new EulerRouterFactory(address(evc));
        router = EulerRouter(routerFactory.deploy(routerGovernor));
        adapterRegistry = new SnapshotRegistry(address(evc), registryOwner);
        externalVaultRegistry = new SnapshotRegistry(address(evc), registryOwner);
        irmFactory = new EulerKinkIRMFactory();
        irmRegistry = new SnapshotRegistry(address(evc), registryOwner);

        // deploy the IRMs
        irmFactory = new EulerKinkIRMFactory();
        address irmZero = irmFactory.deploy(0, 0, 0, 0);
        address irmDefault = irmFactory.deploy(0, 1406417851, 19050045013, 2147483648);
        address irmCustom1 = address(new IRMLinearKink(0, 1, 2, 3));
        address irmCustom2 = address(new IRMLinearKink(0, 4, 5, 6));

        // deploy different perspectives
        escrowedCollateralPerspective = new EscrowedCollateralPerspective(address(factory));

        address[] memory recognizedUnitOfAccounts = new address[](2);
        recognizedUnitOfAccounts[0] = address(840);
        recognizedUnitOfAccounts[1] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

        address[] memory recognizedCollateralPerspectives = new address[](1);
        recognizedCollateralPerspectives[0] = address(0);
        eulerUngovernedPerspective1 = new EulerUngovernedPerspective(
            "Euler Ungoverned Perspective 1",
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(externalVaultRegistry),
            address(irmFactory),
            address(irmRegistry),
            recognizedUnitOfAccounts,
            recognizedCollateralPerspectives
        );

        recognizedCollateralPerspectives[0] = address(escrowedCollateralPerspective);
        eulerUngovernedPerspective2 = new EulerUngovernedPerspective(
            "Euler Ungoverned Perspective 2",
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(externalVaultRegistry),
            address(irmFactory),
            address(irmRegistry),
            recognizedUnitOfAccounts,
            recognizedCollateralPerspectives
        );

        recognizedCollateralPerspectives = new address[](2);
        recognizedCollateralPerspectives[0] = address(escrowedCollateralPerspective);
        recognizedCollateralPerspectives[1] = address(eulerUngovernedPerspective1);
        eulerUngovernedPerspective3 = new EulerUngovernedPerspective(
            "Euler Ungoverned Perspective 3",
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(externalVaultRegistry),
            address(irmFactory),
            address(irmRegistry),
            recognizedUnitOfAccounts,
            recognizedCollateralPerspectives
        );

        // deploy example vaults and configure them
        vaultEscrow = factory.createProxy(address(0), true, abi.encodePacked(address(assetTST), address(0), address(0)));
        vaultBase1 = factory.createProxy(address(0), true, abi.encodePacked(address(assetTST), router, USD));
        vaultBase2 = factory.createProxy(address(0), true, abi.encodePacked(address(assetTST2), router, USD));
        vaultBase3 = factory.createProxy(address(0), true, abi.encodePacked(address(assetTST2), router, WETH));
        vaultBase4 = factory.createProxy(address(0), false, abi.encodePacked(address(assetTST2), router, WETH));
        vaultBase5xv = factory.createProxy(address(0), true, abi.encodePacked(address(xvTST3), router, WETH));
        vaultBase6xv = factory.createProxy(address(0), true, abi.encodePacked(address(xvTST4), router, USD));

        {
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

            // further configure the oracle
            vm.startPrank(routerGovernor);
            router.govSetResolvedVault(vaultEscrow, true);
            router.govSetResolvedVault(vaultBase1, true);
            router.govSetResolvedVault(vaultBase2, true);
            router.govSetResolvedVault(vaultBase3, true);
            router.govSetResolvedVault(vaultBase4, true);
            router.govSetResolvedVault(vaultBase5xv, true);
            router.govSetResolvedVault(vaultBase6xv, true);
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
        }

        // add the custom IRM to the registry
        vm.startPrank(registryOwner);
        irmRegistry.add(address(irmCustom1), address(0), address(0));
        vm.stopPrank();

        // configure the vaults
        IEVault(vaultEscrow).setHookConfig(address(0), 0);
        IEVault(vaultEscrow).setGovernorAdmin(address(0));

        IEVault(vaultBase1).setInterestRateModel(irmZero);
        IEVault(vaultBase1).setMaxLiquidationDiscount(0.1e4);
        IEVault(vaultBase1).setLiquidationCoolOffTime(1);
        IEVault(vaultBase1).setLTV(vaultBase2, 0.1e4, 0.2e4, 0);
        IEVault(vaultBase1).setCaps(1, 2);
        IEVault(vaultBase1).setHookConfig(address(0), 0);
        IEVault(vaultBase1).setGovernorAdmin(address(0));

        IEVault(vaultBase2).setInterestRateModel(irmDefault);
        IEVault(vaultBase2).setMaxLiquidationDiscount(0.2e4);
        IEVault(vaultBase2).setLiquidationCoolOffTime(1);
        IEVault(vaultBase2).setLTV(vaultBase1, 0.3e4, 0.4e4, 0);
        IEVault(vaultBase2).setHookConfig(address(0), 0);
        IEVault(vaultBase2).setGovernorAdmin(address(0));

        IEVault(vaultBase3).setInterestRateModel(irmCustom1);
        IEVault(vaultBase3).setMaxLiquidationDiscount(0.2e4);
        IEVault(vaultBase3).setLiquidationCoolOffTime(1);
        IEVault(vaultBase3).setLTV(vaultEscrow, 0.5e4, 0.6e4, 0);
        IEVault(vaultBase3).setHookConfig(address(0), 0);
        IEVault(vaultBase3).setGovernorAdmin(address(0));

        IEVault(vaultBase4).setInterestRateModel(irmCustom2);
        IEVault(vaultBase4).setMaxLiquidationDiscount(0.2e4);
        IEVault(vaultBase4).setLiquidationCoolOffTime(1);
        IEVault(vaultBase4).setLTV(vaultEscrow, 0.7e4, 0.8e4, 0);
        IEVault(vaultBase4).setHookConfig(address(0), 0);
        IEVault(vaultBase4).setGovernorAdmin(address(0));

        IEVault(vaultBase5xv).setInterestRateModel(irmDefault);
        IEVault(vaultBase5xv).setMaxLiquidationDiscount(0.2e4);
        IEVault(vaultBase5xv).setLiquidationCoolOffTime(1);
        IEVault(vaultBase5xv).setLTV(vaultBase6xv, 0.3e4, 0.4e4, 0);
        IEVault(vaultBase5xv).setHookConfig(address(0), 0);
        IEVault(vaultBase5xv).setGovernorAdmin(address(0));

        IEVault(vaultBase6xv).setInterestRateModel(irmZero);
        IEVault(vaultBase6xv).setMaxLiquidationDiscount(0.1e4);
        IEVault(vaultBase6xv).setLiquidationCoolOffTime(1);
        IEVault(vaultBase6xv).setLTV(vaultBase5xv, 0.1e4, 0.2e4, 0);
        IEVault(vaultBase6xv).setCaps(1, 2);
        IEVault(vaultBase6xv).setHookConfig(address(0), 0);
        IEVault(vaultBase6xv).setGovernorAdmin(address(0));

        vm.label(address(escrowedCollateralPerspective), "escrowedCollateralPerspective");
        vm.label(address(eulerUngovernedPerspective1), "eulerUngovernedPerspective1");
        vm.label(address(eulerUngovernedPerspective2), "eulerUngovernedPerspective2");
        vm.label(address(eulerUngovernedPerspective3), "eulerUngovernedPerspective3");
        vm.label(vaultEscrow, "vaultEscrow");
        vm.label(vaultBase1, "vaultBase1");
        vm.label(vaultBase2, "vaultBase2");
        vm.label(vaultBase3, "vaultBase3");
        vm.label(vaultBase4, "vaultBase4");
        vm.label(vaultBase5xv, "vaultBase5xv");
        vm.label(vaultBase6xv, "vaultBase6xv");
        vm.label(address(assetTST3), "assetTST3");
        vm.label(address(assetTST4), "assetTST4");
        vm.label(address(xvTST3), "xvTST3");
        vm.label(address(xvTST4), "xvTST4");
    }
}
