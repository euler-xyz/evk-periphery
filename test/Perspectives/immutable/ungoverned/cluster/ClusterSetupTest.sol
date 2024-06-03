// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

import {ClusterConservativePerspective} from
    "../../../../../src/Perspectives/immutable/ungoverned/cluster/ClusterConservativePerspective.sol";
import {ClusterConservativeWithRecognizedCollateralsPerspective} from
    "../../../../../src/Perspectives/immutable/ungoverned/cluster/ClusterConservativeWithRecognizedCollateralsPerspective.sol";
import {EscrowSingletonPerspective} from
    "../../../../../src/Perspectives/immutable/ungoverned/escrow/EscrowSingletonPerspective.sol";
import {PerspectiveErrors} from "../../../../../src/Perspectives/PerspectiveErrors.sol";
import {AdapterRegistry} from "../../../../../src/OracleFactory/AdapterRegistry.sol";
import {EulerKinkIRMFactory} from "../../../../../src/IRMFactory/EulerKinkIRMFactory.sol";
import {IEulerRouterFactory} from "../../../../../src/OracleFactory/interfaces/IEulerRouterFactory.sol";
import {IEulerRouter} from "../../../../../src/OracleFactory/interfaces/IEulerRouter.sol";
import {StubPriceOracle} from "../../../../utils/StubPriceOracle.sol";

contract ClusterSetupTest is EVaultTestBase, PerspectiveErrors {
    address internal constant USD = address(840);
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint32 internal constant ESCROW_DISABLED_OPS =
        OP_BORROW | OP_REPAY | OP_REPAY_WITH_SHARES | OP_PULL_DEBT | OP_CONVERT_FEES | OP_LIQUIDATE | OP_TOUCH;

    address adapterRegistryOwner = makeAddr("adapterRegistryOwner");
    address routerGovernor = makeAddr("routerGovernor");

    IEulerRouterFactory routerFactory;
    IEulerRouter router;
    AdapterRegistry adapterRegistry;
    EulerKinkIRMFactory irmFactory;

    EscrowSingletonPerspective escrowSingletonPerspective;
    ClusterConservativePerspective clusterConservativePerspective;
    ClusterConservativeWithRecognizedCollateralsPerspective clusterConservativeWithRecognizedCollateralsPerspective1;
    ClusterConservativeWithRecognizedCollateralsPerspective clusterConservativeWithRecognizedCollateralsPerspective2;
    ClusterConservativeWithRecognizedCollateralsPerspective clusterConservativeWithRecognizedCollateralsPerspective3;

    address vaultEscrow;
    address vaultCluster1;
    address vaultCluster2;
    address vaultCluster3;

    function setUp() public virtual override {
        super.setUp();

        // deploy the oracle-related contracts
        bytes memory initcode = vm.getCode("EulerRouterFactory.sol");
        address deployed;
        assembly {
            deployed := create(0, add(initcode, 0x20), mload(initcode))
        }
        routerFactory = IEulerRouterFactory(deployed);
        router = IEulerRouter(routerFactory.deploy(routerGovernor));
        adapterRegistry = new AdapterRegistry(adapterRegistryOwner);
        irmFactory = new EulerKinkIRMFactory();

        address irmZero = irmFactory.deploy(0, 0, 0, 0);
        address irmDefault = irmFactory.deploy(0, 1406417851, 19050045013, 2147483648);

        // deploy different perspectives
        escrowSingletonPerspective = new EscrowSingletonPerspective(address(factory));

        clusterConservativePerspective = new ClusterConservativePerspective(
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(irmFactory),
            address(escrowSingletonPerspective)
        );

        address[] memory recognizedCollateralPerspectives = new address[](1);
        recognizedCollateralPerspectives[0] = address(0);
        clusterConservativeWithRecognizedCollateralsPerspective1 = new ClusterConservativeWithRecognizedCollateralsPerspective(
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(irmFactory),
            recognizedCollateralPerspectives
        );

        recognizedCollateralPerspectives[0] = address(escrowSingletonPerspective);
        clusterConservativeWithRecognizedCollateralsPerspective2 = new ClusterConservativeWithRecognizedCollateralsPerspective(
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(irmFactory),
            recognizedCollateralPerspectives
        );

        recognizedCollateralPerspectives = new address[](2);
        recognizedCollateralPerspectives[0] = address(escrowSingletonPerspective);
        recognizedCollateralPerspectives[1] = address(clusterConservativeWithRecognizedCollateralsPerspective1);
        clusterConservativeWithRecognizedCollateralsPerspective3 = new ClusterConservativeWithRecognizedCollateralsPerspective(
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

        IEVault(vaultEscrow).setHookConfig(address(0), ESCROW_DISABLED_OPS);
        IEVault(vaultEscrow).setGovernorAdmin(address(0));

        IEVault(vaultCluster1).setInterestRateModel(irmZero);
        IEVault(vaultCluster1).setMaxLiquidationDiscount(0.1e4);
        IEVault(vaultCluster1).setLiquidationCoolOffTime(1);
        IEVault(vaultCluster1).setLTV(vaultCluster2, 0.1e4, 0.2e4, 0);
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

        // configure the oracle
        address stubAdapter = address(new StubPriceOracle());
        vm.prank(adapterRegistryOwner);
        adapterRegistry.addAdapter(stubAdapter);

        vm.startPrank(routerGovernor);
        router.govSetResolvedVault(vaultEscrow, true);
        router.govSetResolvedVault(vaultCluster1, true);
        router.govSetResolvedVault(vaultCluster2, true);
        router.govSetResolvedVault(vaultCluster3, true);
        router.govSetConfig(address(assetTST), USD, stubAdapter);
        router.govSetConfig(address(assetTST), WETH, stubAdapter);
        router.govSetConfig(address(assetTST2), USD, stubAdapter);
        router.govSetConfig(address(assetTST2), WETH, stubAdapter);
        vm.stopPrank();

        vm.label(address(escrowSingletonPerspective), "escrowSingletonPerspective");
        vm.label(address(clusterConservativePerspective), "clusterConservativePerspective");
        vm.label(
            address(clusterConservativeWithRecognizedCollateralsPerspective1),
            "clusterConservativeWithRecognizedCollateralsPerspective1"
        );
        vm.label(
            address(clusterConservativeWithRecognizedCollateralsPerspective2),
            "clusterConservativeWithRecognizedCollateralsPerspective2"
        );
        vm.label(
            address(clusterConservativeWithRecognizedCollateralsPerspective3),
            "clusterConservativeWithRecognizedCollateralsPerspective3"
        );
        vm.label(vaultEscrow, "vaultEscrow");
        vm.label(vaultCluster1, "vaultCluster1");
        vm.label(vaultCluster2, "vaultCluster2");
        vm.label(vaultCluster3, "vaultCluster3");
    }
}
