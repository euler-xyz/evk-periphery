// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

import {EulerDefaultClusterPerspective} from "../../src/Perspectives/deployed/EulerDefaultClusterPerspective.sol";
import {EscrowSingletonPerspective} from "../../src/Perspectives/deployed/EscrowSingletonPerspective.sol";
import {DefaultClusterPerspective} from "../../src/Perspectives/implementation/DefaultClusterPerspective.sol";
import {PerspectiveErrors} from "../../src/Perspectives/implementation/PerspectiveErrors.sol";
import {AdapterRegistry} from "../../src/OracleFactory/AdapterRegistry.sol";
import {EulerKinkIRMFactory} from "../../src/IRMFactory/EulerKinkIRMFactory.sol";
import {EulerRouterFactory} from "../../src/OracleFactory/EulerRouterFactory.sol";
import {StubPriceOracle} from "../utils/StubPriceOracle.sol";

contract DefaultClusterPerspectiveInstance is DefaultClusterPerspective {
    constructor(
        address factory,
        address routerFactory,
        address adapterRegistry,
        address irmFactory,
        address[] memory recognizedCollateralPerspectives
    )
        DefaultClusterPerspective(factory, routerFactory, adapterRegistry, irmFactory, recognizedCollateralPerspectives)
    {}

    function name() public pure override returns (string memory) {
        return "Default Cluster Perspective Instance";
    }
}

contract ClusterSetupTest is EVaultTestBase, PerspectiveErrors {
    address internal constant USD = address(840);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address adapterRegistryOwner = makeAddr("adapterRegistryOwner");
    address routerGovernor = makeAddr("routerGovernor");

    EulerRouterFactory routerFactory;
    EulerRouter router;
    AdapterRegistry adapterRegistry;
    EulerKinkIRMFactory irmFactory;

    EscrowSingletonPerspective escrowSingletonPerspective;
    EulerDefaultClusterPerspective eulerDefaultClusterPerspective;
    DefaultClusterPerspectiveInstance defaultClusterPerspectiveInstance1;
    DefaultClusterPerspectiveInstance defaultClusterPerspectiveInstance2;
    DefaultClusterPerspectiveInstance defaultClusterPerspectiveInstance3;

    address vaultEscrow;
    address vaultCluster1;
    address vaultCluster2;
    address vaultCluster3;

    function setUp() public virtual override {
        super.setUp();

        // deploy the oracle-related contracts
        routerFactory = new EulerRouterFactory();
        router = EulerRouter(routerFactory.deploy(routerGovernor));
        adapterRegistry = new AdapterRegistry(adapterRegistryOwner);
        irmFactory = new EulerKinkIRMFactory();

        address irmZero = irmFactory.deploy(0, 0, 0, 0);
        address irmDefault = irmFactory.deploy(0, 1406417851, 19050045013, 2147483648);

        // deploy different perspectives
        escrowSingletonPerspective = new EscrowSingletonPerspective(address(factory));

        eulerDefaultClusterPerspective = new EulerDefaultClusterPerspective(
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(irmFactory),
            address(escrowSingletonPerspective)
        );

        address[] memory recognizedCollateralPerspectives = new address[](1);
        recognizedCollateralPerspectives[0] = address(0);
        defaultClusterPerspectiveInstance1 = new DefaultClusterPerspectiveInstance(
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(irmFactory),
            recognizedCollateralPerspectives
        );

        recognizedCollateralPerspectives[0] = address(escrowSingletonPerspective);
        defaultClusterPerspectiveInstance2 = new DefaultClusterPerspectiveInstance(
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(irmFactory),
            recognizedCollateralPerspectives
        );

        recognizedCollateralPerspectives = new address[](2);
        recognizedCollateralPerspectives[0] = address(escrowSingletonPerspective);
        recognizedCollateralPerspectives[1] = address(defaultClusterPerspectiveInstance1);
        defaultClusterPerspectiveInstance3 = new DefaultClusterPerspectiveInstance(
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(irmFactory),
            recognizedCollateralPerspectives
        );

        // deploy example vaults and configure them
        vaultEscrow =
            factory.createProxy(address(0), false, abi.encodePacked(address(assetTST), address(0), address(0)));
        vaultCluster1 = factory.createProxy(address(0), false, abi.encodePacked(address(assetTST), router, USD));
        vaultCluster2 = factory.createProxy(address(0), false, abi.encodePacked(address(assetTST2), router, USD));
        vaultCluster3 = factory.createProxy(address(0), false, abi.encodePacked(address(assetTST2), router, WETH));

        IEVault(vaultEscrow).setGovernorAdmin(address(0));

        IEVault(vaultCluster1).setInterestRateModel(irmZero);
        IEVault(vaultCluster1).setMaxLiquidationDiscount(0.1e4);
        IEVault(vaultCluster1).setLiquidationCoolOffTime(1);
        IEVault(vaultCluster1).setLTV(vaultCluster2, 0.1e4, 0.2e4, 0);
        IEVault(vaultCluster1).setCaps(1, 2);
        IEVault(vaultCluster1).setGovernorAdmin(address(0));

        IEVault(vaultCluster2).setInterestRateModel(irmDefault);
        IEVault(vaultCluster2).setMaxLiquidationDiscount(0.2e4);
        IEVault(vaultCluster2).setLiquidationCoolOffTime(1);
        IEVault(vaultCluster2).setLTV(vaultCluster1, 0.3e4, 0.4e4, 0);
        IEVault(vaultCluster2).setGovernorAdmin(address(0));

        IEVault(vaultCluster3).setInterestRateModel(irmDefault);
        IEVault(vaultCluster3).setMaxLiquidationDiscount(0.2e4);
        IEVault(vaultCluster3).setLiquidationCoolOffTime(1);
        IEVault(vaultCluster3).setLTV(vaultEscrow, 0.5e4, 0.6e4, 0);
        IEVault(vaultCluster3).setCaps(3, 4);
        IEVault(vaultCluster3).setGovernorAdmin(address(0));

        // configure the oracle
        address stubAdapter_assetTST_USD = address(new StubPriceOracle());
        address stubAdapter_assetTST_WETH = address(new StubPriceOracle());
        address stubAdapter_assetTST2_USD = address(new StubPriceOracle());
        address stubAdapter_assetTST2_WETH = address(new StubPriceOracle());
        vm.startPrank(adapterRegistryOwner);
        adapterRegistry.addAdapter(stubAdapter_assetTST_USD, address(assetTST), USD);
        adapterRegistry.addAdapter(stubAdapter_assetTST_WETH, address(assetTST), WETH);
        adapterRegistry.addAdapter(stubAdapter_assetTST2_USD, address(assetTST2), USD);
        adapterRegistry.addAdapter(stubAdapter_assetTST2_WETH, address(assetTST2), WETH);
        vm.stopPrank();

        vm.startPrank(routerGovernor);
        router.govSetResolvedVault(vaultEscrow, true);
        router.govSetResolvedVault(vaultCluster1, true);
        router.govSetResolvedVault(vaultCluster2, true);
        router.govSetResolvedVault(vaultCluster3, true);
        router.govSetConfig(address(assetTST), USD, stubAdapter_assetTST_USD);
        router.govSetConfig(address(assetTST), WETH, stubAdapter_assetTST_WETH);
        router.govSetConfig(address(assetTST2), USD, stubAdapter_assetTST2_USD);
        router.govSetConfig(address(assetTST2), WETH, stubAdapter_assetTST2_WETH);
        router.transferGovernance(address(0));
        vm.stopPrank();

        vm.label(address(escrowSingletonPerspective), "escrowSingletonPerspective");
        vm.label(address(eulerDefaultClusterPerspective), "eulerDefaultClusterPerspective");
        vm.label(address(defaultClusterPerspectiveInstance1), "defaultClusterPerspectiveInstance1");
        vm.label(address(defaultClusterPerspectiveInstance2), "defaultClusterPerspectiveInstance2");
        vm.label(address(defaultClusterPerspectiveInstance3), "defaultClusterPerspectiveInstance3");
        vm.label(vaultEscrow, "vaultEscrow");
        vm.label(vaultCluster1, "vaultCluster1");
        vm.label(vaultCluster2, "vaultCluster2");
        vm.label(vaultCluster3, "vaultCluster3");
    }
}
