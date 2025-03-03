// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

import {EulerUngovernedPerspectiveHarness} from "./EulerUngovernedPerspectiveHarness.sol";
import {EulerRouterFactory} from "../../src/EulerRouterFactory/EulerRouterFactory.sol";
import {SnapshotRegistry} from "../../src/SnapshotRegistry/SnapshotRegistry.sol";
import {IPerspective} from "../../src/Perspectives/implementation/interfaces/IPerspective.sol";
import {PerspectiveErrors} from "../../src/Perspectives/implementation/PerspectiveErrors.sol";
import {StubERC4626} from "../utils/StubERC4626.sol";

contract EulerUngovernedPerspectivePricingTest is Test {
    address internal constant USD = address(840);
    address internal constant BTC = address(0xb17c0111);
    address admin = makeAddr("admin");
    address stubAdapter = makeAddr("stubAdapter");

    EulerRouter router;
    SnapshotRegistry adapterRegistry;
    SnapshotRegistry externalVaultRegistry;

    EulerUngovernedPerspectiveHarness perspective;

    function setUp() public {
        router = new EulerRouter(address(1), admin);
        adapterRegistry = new SnapshotRegistry(address(1), admin);
        externalVaultRegistry = new SnapshotRegistry(address(1), admin);

        perspective = new EulerUngovernedPerspectiveHarness(
            address(0), address(0), address(adapterRegistry), address(externalVaultRegistry), address(0), address(0)
        );
    }

    /// @dev Scenario 1: EVK vault wraps unit of account.
    function test_verifyCollateralPricing_Scenario_1() public {
        // Collateral is eUSD, unitOfAccount is USD.
        address eUSD = address(new StubERC4626(USD, 1e18));
        vm.startPrank(admin);
        uint256 snapshot = vm.snapshot();

        // Good: eUSD is resolved.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(eUSD, true);
        perspective.verifyCollateralPricingHarness(address(router), eUSD, USD);

        // Bad: eUSD is not resolved.
        vm.revertTo(snapshot);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), eUSD, USD);

        // Bad: eUSD is resolved, eUSD -> USD adapter is configured.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(eUSD, true);
        router.govSetConfig(eUSD, USD, stubAdapter);
        adapterRegistry.add(stubAdapter, eUSD, USD);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), eUSD, USD);

        // Bad: eUSD is not resolved, eUSD -> USD adapter is configured.
        vm.revertTo(snapshot);
        router.govSetConfig(eUSD, USD, stubAdapter);
        adapterRegistry.add(stubAdapter, eUSD, USD);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), eUSD, USD);
    }

    /// @dev Scenario 2: EVK vault wraps EVK vault wraps unit of account. Nested vaults are disallowed.
    function test_verifyCollateralPricing_Scenario_2() public {
        // Collateral is eeUSD, unitOfAccount is USD.
        address eUSD = address(new StubERC4626(USD, 1e18));
        address eeUSD = address(new StubERC4626(eUSD, 1e18));
        vm.startPrank(admin);
        uint256 snapshot = vm.snapshot();

        // Bad: eeUSD is resolved. eUSD is resolved. Nested vaults are disallowed.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(eeUSD, true);
        router.govSetResolvedVault(eUSD, true);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), eeUSD, USD);

        // Bad: Nested vaults are disallowed.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(eeUSD, true);
        router.govSetResolvedVault(eUSD, true);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), eeUSD, USD);
    }

    /// @dev Scenario 3: EVK vault wraps external vault wraps unit of account.
    /// 1-nested external vaults are allowed. Pricing has to only be through vault resolution.
    function test_verifyCollateralPricing_Scenario_3() public {
        // Collateral is eeUSD, unitOfAccount is USD.
        address xUSD = address(new StubERC4626(USD, 1e18));
        address exUSD = address(new StubERC4626(xUSD, 1e18));
        vm.startPrank(admin);
        uint256 snapshot = vm.snapshot();

        // Good: exUSD is resolved. xUSD is resolved.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(exUSD, true);
        router.govSetResolvedVault(xUSD, true);
        externalVaultRegistry.add(xUSD, USD, xUSD);
        perspective.verifyCollateralPricingHarness(address(router), exUSD, USD);

        // Bad: exUSD is resolved. xUSD is not resolved.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(exUSD, true);
        externalVaultRegistry.add(xUSD, USD, xUSD);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), exUSD, USD);

        // Bad: exUSD is resolved. xUSD is resolved but not valid in the external vault registry.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(exUSD, true);
        router.govSetResolvedVault(xUSD, true);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), exUSD, USD);

        // Bad: exUSD is not resolved. xUSD is resolved.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(xUSD, true);
        externalVaultRegistry.add(xUSD, USD, xUSD);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), exUSD, USD);

        // Bad: exUSD is resolved. xUSD is resolved. An xUSD -> USD adapter is configured.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(exUSD, true);
        router.govSetResolvedVault(xUSD, true);
        router.govSetConfig(xUSD, USD, stubAdapter);
        adapterRegistry.add(stubAdapter, xUSD, USD);
        externalVaultRegistry.add(xUSD, USD, xUSD);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), exUSD, USD);

        // Bad: exUSD is resolved. xUSD is resolved. An exUSD -> USD adapter is configured.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(exUSD, true);
        router.govSetResolvedVault(xUSD, true);
        router.govSetConfig(exUSD, USD, stubAdapter);
        adapterRegistry.add(stubAdapter, exUSD, USD);
        externalVaultRegistry.add(xUSD, USD, xUSD);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), exUSD, USD);
    }

    /// @dev Scenario 4: EVK vault wraps external vault wraps external vault wraps unit of account.
    /// 2-nested external vaults are disallowed.
    function test_verifyCollateralPricing_Scenario_4() public {
        // Collateral is eeUSD, unitOfAccount is USD.
        address xUSD = address(new StubERC4626(USD, 1e18));
        address xxUSD = address(new StubERC4626(xUSD, 1e18));
        address exxUSD = address(new StubERC4626(xxUSD, 1e18));
        vm.startPrank(admin);
        uint256 snapshot = vm.snapshot();

        // Bad: exxUSD is resolved. xxUSD is resolved. xUSD is resolved. However 2-nesting is disallowed.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(xUSD, true);
        router.govSetResolvedVault(xxUSD, true);
        router.govSetResolvedVault(exxUSD, true);
        externalVaultRegistry.add(xUSD, USD, xUSD);
        externalVaultRegistry.add(xxUSD, xUSD, xxUSD);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), exxUSD, USD);
    }

    /// @dev Scenario 5: EVK vault wraps BTC.
    function test_verifyCollateralPricing_Scenario_5() public {
        // Collateral is eBTC, unitOfAccount is USD.
        address eBTC = address(new StubERC4626(BTC, 1e18));
        vm.startPrank(admin);
        uint256 snapshot = vm.snapshot();

        // Good: eBTC is resolved. There is a BTC -> USD adapter.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(eBTC, true);
        router.govSetConfig(BTC, USD, stubAdapter);
        adapterRegistry.add(stubAdapter, BTC, USD);
        perspective.verifyCollateralPricingHarness(address(router), eBTC, USD);

        // Bad: eBTC is not resolved.
        vm.revertTo(snapshot);
        router.govSetConfig(BTC, USD, stubAdapter);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), eBTC, USD);

        // Bad: eBTC is resolved. There is a BTC -> USD adapter but not valid in registry.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(eBTC, true);
        router.govSetConfig(BTC, USD, stubAdapter);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), eBTC, USD);

        // Bad: eBTC is resolved. There is no BTC -> USD adapter.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(eBTC, true);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), eBTC, USD);

        // Bad: eBTC is resolved. There is an eBTC -> USD adapter in registry.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(eBTC, true);
        router.govSetConfig(eBTC, USD, stubAdapter);
        adapterRegistry.add(stubAdapter, eBTC, USD);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), eBTC, USD);

        // Bad: eBTC is resolved. There is an eBTC -> USD adapter not in registry.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(eBTC, true);
        router.govSetConfig(eBTC, USD, stubAdapter);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), eBTC, USD);
    }

    /// @dev Scenario 6: EVK vault wraps external vault wraps BTC.
    function test_verifyCollateralPricing_Scenario_6() public {
        // Collateral is exBTC, unitOfAccount is USD.
        address xBTC = address(new StubERC4626(BTC, 1e18));
        address exBTC = address(new StubERC4626(xBTC, 1e18));
        vm.startPrank(admin);
        uint256 snapshot = vm.snapshot();

        // Good: exBTC is resolved. xBTC is resolved and in the external vault registry. There is a BTC -> USD adapter.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(exBTC, true);
        router.govSetResolvedVault(xBTC, true);
        router.govSetConfig(BTC, USD, stubAdapter);
        externalVaultRegistry.add(xBTC, BTC, xBTC);
        adapterRegistry.add(stubAdapter, BTC, USD);
        perspective.verifyCollateralPricingHarness(address(router), exBTC, USD);

        // Bad: exBTC is resolved. xBTC is resolved but not in the external vault registry. There is a BTC -> USD
        // adapter.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(exBTC, true);
        router.govSetResolvedVault(xBTC, true);
        router.govSetConfig(BTC, USD, stubAdapter);
        adapterRegistry.add(stubAdapter, BTC, USD);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), exBTC, USD);

        // Bad: exBTC is resolved. xBTC is not resolved. There is a BTC -> USD adapter.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(exBTC, true);
        router.govSetConfig(BTC, USD, stubAdapter);
        externalVaultRegistry.add(xBTC, BTC, xBTC);
        adapterRegistry.add(stubAdapter, BTC, USD);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), exBTC, USD);

        // Bad: exBTC is not resolved. xBTC is resolved. There is a BTC -> USD adapter.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(xBTC, true);
        router.govSetConfig(BTC, USD, stubAdapter);
        externalVaultRegistry.add(xBTC, BTC, xBTC);
        adapterRegistry.add(stubAdapter, BTC, USD);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), exBTC, USD);

        // Bad: exBTC is resolved. xBTC is resolved and in the external vault registry.
        // There is a BTC -> USD adapter but not in registry.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(exBTC, true);
        router.govSetResolvedVault(xBTC, true);
        router.govSetConfig(BTC, USD, stubAdapter);
        externalVaultRegistry.add(xBTC, BTC, xBTC);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), exBTC, USD);

        // Bad: exBTC is resolved. xBTC is resolved and in the external vault registry.
        // There is no adapter.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(exBTC, true);
        router.govSetResolvedVault(xBTC, true);
        externalVaultRegistry.add(xBTC, BTC, xBTC);
        adapterRegistry.add(stubAdapter, BTC, USD);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), exBTC, USD);

        // Bad: exBTC is resolved. xBTC is resolved and in the external vault registry.
        // There is a BTC -> USD adapter. However there is an overriding exBTC -> BTC adapter in registry.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(exBTC, true);
        router.govSetResolvedVault(xBTC, true);
        router.govSetConfig(BTC, USD, stubAdapter);
        router.govSetConfig(exBTC, USD, stubAdapter);
        externalVaultRegistry.add(xBTC, BTC, xBTC);
        externalVaultRegistry.add(exBTC, BTC, xBTC);
        adapterRegistry.add(stubAdapter, exBTC, BTC);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), exBTC, USD);

        // Bad: exBTC is resolved. xBTC is resolved and in the external vault registry.
        // There is a BTC -> USD adapter. However there is an overriding xBTC -> BTC adapter in registry.
        vm.revertTo(snapshot);
        router.govSetResolvedVault(exBTC, true);
        router.govSetResolvedVault(xBTC, true);
        router.govSetConfig(BTC, USD, stubAdapter);
        router.govSetConfig(xBTC, USD, stubAdapter);
        externalVaultRegistry.add(xBTC, BTC, xBTC);
        externalVaultRegistry.add(exBTC, BTC, xBTC);
        adapterRegistry.add(stubAdapter, xBTC, BTC);
        vm.expectRevert();
        perspective.verifyCollateralPricingHarness(address(router), exBTC, USD);
    }
}
