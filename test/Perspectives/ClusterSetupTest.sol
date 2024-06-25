// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {TestERC20} from "evk-test/mocks/TestERC20.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

import {EulerDefaultClusterPerspective} from "../../src/Perspectives/deployed/EulerDefaultClusterPerspective.sol";
import {EscrowSingletonPerspective} from "../../src/Perspectives/deployed/EscrowSingletonPerspective.sol";
import {DefaultClusterPerspective} from "../../src/Perspectives/implementation/DefaultClusterPerspective.sol";
import {PerspectiveErrors} from "../../src/Perspectives/implementation/PerspectiveErrors.sol";
import {SnapshotRegistry} from "../../src/OracleFactory/SnapshotRegistry.sol";
import {EulerKinkIRMFactory} from "../../src/IRMFactory/EulerKinkIRMFactory.sol";
import {IEulerRouterFactory} from "../../src/OracleFactory/interfaces/IEulerRouterFactory.sol";
import {IEulerRouter} from "../../src/OracleFactory/interfaces/IEulerRouter.sol";
import {StubPriceOracle} from "../utils/StubPriceOracle.sol";
import {StubERC4626} from "../utils/StubERC4626.sol";

contract DefaultClusterPerspectiveInstance is DefaultClusterPerspective {
    constructor(
        address factory,
        address routerFactory,
        address adapterRegistry,
        address externalVaultRegistry,
        address irmFactory,
        address[] memory recognizedCollateralPerspectives
    )
        DefaultClusterPerspective(
            factory,
            routerFactory,
            adapterRegistry,
            externalVaultRegistry,
            irmFactory,
            recognizedCollateralPerspectives
        )
    {}

    function name() public pure override returns (string memory) {
        return "Default Cluster Perspective Instance";
    }
}

contract ClusterSetupTest is EVaultTestBase, PerspectiveErrors {
    address internal constant USD = address(840);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address registryOwner = makeAddr("registryOwner");
    address routerGovernor = makeAddr("routerGovernor");

    IEulerRouterFactory routerFactory;
    IEulerRouter router;
    SnapshotRegistry adapterRegistry;
    SnapshotRegistry externalVaultRegistry;
    EulerKinkIRMFactory irmFactory;

    EscrowSingletonPerspective escrowSingletonPerspective;
    EulerDefaultClusterPerspective eulerDefaultClusterPerspective;
    DefaultClusterPerspectiveInstance defaultClusterPerspectiveInstance1;
    DefaultClusterPerspectiveInstance defaultClusterPerspectiveInstance2;
    DefaultClusterPerspectiveInstance defaultClusterPerspectiveInstance3;

    TestERC20 assetTST3;
    TestERC20 assetTST4;
    StubERC4626 xvTST3; // xv stands for external vault
    StubERC4626 xvTST4;

    address vaultEscrow;
    address vaultCluster1;
    address vaultCluster2;
    address vaultCluster3;
    address vaultCluster4xv;
    address vaultCluster5xv;

    function setUp() public virtual override {
        super.setUp();

        // set up external erc4626 vaults
        assetTST3 = new TestERC20("Test Token 3", "TST3", 18, false);
        assetTST4 = new TestERC20("Test Token 4", "TST4", 18, false);
        xvTST3 = new StubERC4626(address(assetTST3), 1.1e18);
        xvTST4 = new StubERC4626(address(assetTST4), 1.05e18);

        // deploy the oracle-related contracts
        bytes memory initcode = vm.getCode("EulerRouterFactory.sol");
        address deployed;
        assembly {
            deployed := create(0, add(initcode, 0x20), mload(initcode))
        }
        routerFactory = IEulerRouterFactory(deployed);
        router = IEulerRouter(routerFactory.deploy(routerGovernor));
        adapterRegistry = new SnapshotRegistry(registryOwner);
        externalVaultRegistry = new SnapshotRegistry(registryOwner);
        irmFactory = new EulerKinkIRMFactory();

        address irmZero = irmFactory.deploy(0, 0, 0, 0);
        address irmDefault = irmFactory.deploy(0, 1406417851, 19050045013, 2147483648);

        // deploy different perspectives
        escrowSingletonPerspective = new EscrowSingletonPerspective(address(factory));

        eulerDefaultClusterPerspective = new EulerDefaultClusterPerspective(
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(externalVaultRegistry),
            address(irmFactory),
            address(escrowSingletonPerspective)
        );

        address[] memory recognizedCollateralPerspectives = new address[](1);
        recognizedCollateralPerspectives[0] = address(0);
        defaultClusterPerspectiveInstance1 = new DefaultClusterPerspectiveInstance(
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(externalVaultRegistry),
            address(irmFactory),
            recognizedCollateralPerspectives
        );

        recognizedCollateralPerspectives[0] = address(escrowSingletonPerspective);
        defaultClusterPerspectiveInstance2 = new DefaultClusterPerspectiveInstance(
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(externalVaultRegistry),
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
            address(externalVaultRegistry),
            address(irmFactory),
            recognizedCollateralPerspectives
        );

        // deploy example vaults and configure them
        vaultEscrow =
            factory.createProxy(address(0), false, abi.encodePacked(address(assetTST), address(0), address(0)));
        vaultCluster1 = factory.createProxy(address(0), false, abi.encodePacked(address(assetTST), router, USD));
        vaultCluster2 = factory.createProxy(address(0), false, abi.encodePacked(address(assetTST2), router, USD));
        vaultCluster3 = factory.createProxy(address(0), false, abi.encodePacked(address(assetTST2), router, WETH));
        vaultCluster4xv = factory.createProxy(address(0), false, abi.encodePacked(address(xvTST3), router, WETH));
        vaultCluster5xv = factory.createProxy(address(0), false, abi.encodePacked(address(xvTST4), router, USD));

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
        IEVault(vaultCluster3).setGovernorAdmin(address(0));

        IEVault(vaultCluster4xv).setInterestRateModel(irmDefault);
        IEVault(vaultCluster4xv).setMaxLiquidationDiscount(0.2e4);
        IEVault(vaultCluster4xv).setLiquidationCoolOffTime(1);
        IEVault(vaultCluster4xv).setLTV(vaultCluster5xv, 0.3e4, 0.4e4, 0);
        IEVault(vaultCluster4xv).setGovernorAdmin(address(0));

        IEVault(vaultCluster5xv).setInterestRateModel(irmZero);
        IEVault(vaultCluster5xv).setMaxLiquidationDiscount(0.1e4);
        IEVault(vaultCluster5xv).setLiquidationCoolOffTime(1);
        IEVault(vaultCluster5xv).setLTV(vaultCluster4xv, 0.1e4, 0.2e4, 0);
        IEVault(vaultCluster5xv).setCaps(1, 2);
        IEVault(vaultCluster5xv).setGovernorAdmin(address(0));

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
        router.govSetResolvedVault(vaultCluster1, true);
        router.govSetResolvedVault(vaultCluster2, true);
        router.govSetResolvedVault(vaultCluster3, true);
        router.govSetResolvedVault(vaultCluster4xv, true);
        router.govSetResolvedVault(vaultCluster5xv, true);
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

        vm.label(address(escrowSingletonPerspective), "escrowSingletonPerspective");
        vm.label(address(eulerDefaultClusterPerspective), "eulerDefaultClusterPerspective");
        vm.label(address(defaultClusterPerspectiveInstance1), "defaultClusterPerspectiveInstance1");
        vm.label(address(defaultClusterPerspectiveInstance2), "defaultClusterPerspectiveInstance2");
        vm.label(address(defaultClusterPerspectiveInstance3), "defaultClusterPerspectiveInstance3");
        vm.label(vaultEscrow, "vaultEscrow");
        vm.label(vaultCluster1, "vaultCluster1");
        vm.label(vaultCluster2, "vaultCluster2");
        vm.label(vaultCluster3, "vaultCluster3");
        vm.label(vaultCluster4xv, "vaultCluster4xv");
        vm.label(vaultCluster5xv, "vaultCluster5xv");
        vm.label(address(assetTST3), "assetTST3");
        vm.label(address(assetTST4), "assetTST4");
        vm.label(address(xvTST3), "xvTST3");
        vm.label(address(xvTST4), "xvTST4");
    }
}
