// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {ClusterSetupTest} from "./ClusterSetupTest.sol";
import {IEVault} from "euler-vault-kit/EVault/IEVault.sol";
import {IPerspective} from "../../src/Perspectives/implementation/interfaces/IPerspective.sol";

contract DefaultDefaultClusterPerspectiveInstanceTest is ClusterSetupTest {
    function setUp() public override {
        super.setUp();
    }

    function test_Perspective_DefaultDefaultClusterPerspectiveInstance_name() public view {
        assertEq(defaultClusterPerspectiveInstance1.name(), "Default Cluster Perspective Instance");
        assertEq(defaultClusterPerspectiveInstance2.name(), "Default Cluster Perspective Instance");
        assertEq(defaultClusterPerspectiveInstance3.name(), "Default Cluster Perspective Instance");
    }

    function test_Perspective_DefaultClusterPerspectiveInstance_general() public {
        uint256 snapshot = vm.snapshot();

        // verifies that the escrow vault will fail right away if verified by the cluster perspective 1
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(defaultClusterPerspectiveInstance1),
                vaultEscrow,
                ERROR__INTEREST_RATE_MODEL
            )
        );
        defaultClusterPerspectiveInstance1.perspectiveVerify(vaultEscrow, true);

        // verifies that the vault cluster 3 will fail right away if verified by the escrow perspective
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(escrowPerspective),
                vaultCluster3,
                ERROR__ORACLE_INVALID_ROUTER
            )
        );
        escrowPerspective.perspectiveVerify(vaultCluster3, true);

        // verifies that the vault cluster 1 belongs to the cluster perspective 1.
        // while verifying the vault cluster 1, the cluster perspective 1 will also verify the vault cluster 2 as they
        // reference each other
        vm.expectEmit(true, false, false, false, address(defaultClusterPerspectiveInstance1));
        emit IPerspective.PerspectiveVerified(vaultCluster2);
        vm.expectEmit(true, false, false, false, address(defaultClusterPerspectiveInstance1));
        emit IPerspective.PerspectiveVerified(vaultCluster1);
        defaultClusterPerspectiveInstance1.perspectiveVerify(vaultCluster1, true);
        defaultClusterPerspectiveInstance1.perspectiveVerify(vaultCluster2, true);
        assertTrue(defaultClusterPerspectiveInstance1.isVerified(vaultCluster1));
        assertTrue(defaultClusterPerspectiveInstance1.isVerified(vaultCluster2));
        assertEq(defaultClusterPerspectiveInstance1.verifiedArray()[0], vaultCluster2);
        assertEq(defaultClusterPerspectiveInstance1.verifiedArray()[1], vaultCluster1);

        // verifies that the vault cluster 3 belongs to the cluster perspective 2.
        // while verifying the vault cluster 3, the escrow perspective will also verify the vault escrow
        vm.expectEmit(true, false, false, false, address(escrowPerspective));
        emit IPerspective.PerspectiveVerified(vaultEscrow);
        vm.expectEmit(true, false, false, false, address(defaultClusterPerspectiveInstance2));
        emit IPerspective.PerspectiveVerified(vaultCluster3);
        defaultClusterPerspectiveInstance2.perspectiveVerify(vaultCluster3, true);
        assertTrue(escrowPerspective.isVerified(vaultEscrow));
        assertTrue(defaultClusterPerspectiveInstance2.isVerified(vaultCluster3));
        assertEq(escrowPerspective.verifiedArray()[0], vaultEscrow);
        assertEq(defaultClusterPerspectiveInstance2.verifiedArray()[0], vaultCluster3);

        // verifies that the vault cluster 4 belongs to the cluster perspective 1.
        // while verifying the vault cluster 4, the cluster perspective 1 will also verify the vault cluster 5 as they
        // reference each other
        vm.expectEmit(true, false, false, false, address(defaultClusterPerspectiveInstance1));
        emit IPerspective.PerspectiveVerified(vaultCluster5xv);
        vm.expectEmit(true, false, false, false, address(defaultClusterPerspectiveInstance1));
        emit IPerspective.PerspectiveVerified(vaultCluster4xv);
        defaultClusterPerspectiveInstance1.perspectiveVerify(vaultCluster4xv, true);
        defaultClusterPerspectiveInstance1.perspectiveVerify(vaultCluster5xv, true);
        assertTrue(defaultClusterPerspectiveInstance1.isVerified(vaultCluster4xv));
        assertTrue(defaultClusterPerspectiveInstance1.isVerified(vaultCluster5xv));
        assertEq(defaultClusterPerspectiveInstance1.verifiedArray()[0], vaultCluster2);
        assertEq(defaultClusterPerspectiveInstance1.verifiedArray()[1], vaultCluster1);
        assertEq(defaultClusterPerspectiveInstance1.verifiedArray()[2], vaultCluster5xv);
        assertEq(defaultClusterPerspectiveInstance1.verifiedArray()[3], vaultCluster4xv);

        // verifies that all the cluster vaults cluster belong to the cluster perspective 3
        defaultClusterPerspectiveInstance3.perspectiveVerify(vaultCluster1, true);
        defaultClusterPerspectiveInstance3.perspectiveVerify(vaultCluster2, true);
        defaultClusterPerspectiveInstance3.perspectiveVerify(vaultCluster3, true);
        defaultClusterPerspectiveInstance3.perspectiveVerify(vaultCluster4xv, true);
        defaultClusterPerspectiveInstance3.perspectiveVerify(vaultCluster5xv, true);

        // revert to the initial state
        vm.revertTo(snapshot);

        // impersonate the governor to modify vault cluster 3 by adding a new collateral
        vm.prank(address(0));
        IEVault(vaultCluster3).setLTV(vaultCluster2, 0.7e4, 0.8e4, 0);

        // verifies that the vault cluster 3 still belongs to the cluster perspective 3, even with an additional
        // collateral
        defaultClusterPerspectiveInstance3.perspectiveVerify(vaultCluster3, true);

        // meanwhile, other vaults got verified too
        assertTrue(defaultClusterPerspectiveInstance3.isVerified(vaultCluster3));
        assertTrue(escrowPerspective.isVerified(vaultEscrow));
        assertTrue(defaultClusterPerspectiveInstance1.isVerified(vaultCluster1));
        assertTrue(defaultClusterPerspectiveInstance1.isVerified(vaultCluster2));
    }

    function test_Perspective_DefaultClusterPerspectiveInstance_nesting() public {
        address nestedVault =
            factory.createProxy(address(0), false, abi.encodePacked(address(vaultCluster1), address(0), address(0)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(defaultClusterPerspectiveInstance1),
                nestedVault,
                ERROR__NESTING
            )
        );
        defaultClusterPerspectiveInstance1.perspectiveVerify(nestedVault, true);
    }
}
