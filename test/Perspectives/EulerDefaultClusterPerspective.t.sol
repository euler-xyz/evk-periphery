// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {ClusterSetupTest} from "./ClusterSetupTest.sol";
import {IEVault} from "euler-vault-kit/EVault/IEVault.sol";
import {IPerspective} from "../../src/Perspectives/implementation/interfaces/IPerspective.sol";

import {EulerDefaultClusterPerspective} from "../../src/Perspectives/deployed/EulerDefaultClusterPerspective.sol";

contract EulerDefaultClusterPerspectiveTest is ClusterSetupTest {
    function setUp() public override {
        super.setUp();
    }

    function test_Perspective_EulerDefaultClusterPerspective_constructor() public {
        vm.expectRevert();
        new EulerDefaultClusterPerspective(address(0), address(0), address(0), address(0), address(0));

        vm.expectRevert();
        new EulerDefaultClusterPerspective(
            address(0), address(0), address(0), address(0), address(defaultClusterPerspectiveInstance1)
        );

        // no revert
        new EulerDefaultClusterPerspective(
            address(0), address(0), address(0), address(0), address(escrowSingletonPerspective)
        );
    }

    function test_Perspective_EulerDefaultClusterPerspective_name() public view {
        assertEq(eulerDefaultClusterPerspective.name(), "Euler Default Cluster Perspective");
    }

    function test_Perspective_EulerDefaultClusterPerspective_general() public {
        uint256 snapshot = vm.snapshot();

        // verifies that the escrow vault will fail right away if verified by the cluster conservative perspective
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(eulerDefaultClusterPerspective),
                vaultEscrow,
                ERROR__INTEREST_RATE_MODEL
            )
        );
        eulerDefaultClusterPerspective.perspectiveVerify(vaultEscrow, true);

        vm.expectEmit(true, false, false, false, address(eulerDefaultClusterPerspective));
        emit IPerspective.PerspectiveVerified(vaultCluster2);
        vm.expectEmit(true, false, false, false, address(eulerDefaultClusterPerspective));
        emit IPerspective.PerspectiveVerified(vaultCluster1);
        eulerDefaultClusterPerspective.perspectiveVerify(vaultCluster1, true);
        eulerDefaultClusterPerspective.perspectiveVerify(vaultCluster2, true);
        assertTrue(eulerDefaultClusterPerspective.isVerified(vaultCluster1));
        assertTrue(eulerDefaultClusterPerspective.isVerified(vaultCluster2));
        assertEq(eulerDefaultClusterPerspective.verifiedArray()[0], vaultCluster2);
        assertEq(eulerDefaultClusterPerspective.verifiedArray()[1], vaultCluster1);

        vm.expectEmit(true, false, false, false, address(escrowSingletonPerspective));
        emit IPerspective.PerspectiveVerified(vaultEscrow);
        vm.expectEmit(true, false, false, false, address(eulerDefaultClusterPerspective));
        emit IPerspective.PerspectiveVerified(vaultCluster3);
        eulerDefaultClusterPerspective.perspectiveVerify(vaultCluster3, true);
        assertTrue(escrowSingletonPerspective.isVerified(vaultEscrow));
        assertTrue(eulerDefaultClusterPerspective.isVerified(vaultCluster3));
        assertEq(escrowSingletonPerspective.verifiedArray()[0], vaultEscrow);
        assertEq(eulerDefaultClusterPerspective.verifiedArray()[2], vaultCluster3);

        // revert to the initial state
        vm.revertTo(snapshot);

        // impersonate the governor to modify vault cluster 1 by modifying the LTV in a way the cluster conservative
        // perspective will not be able to verify it anymore
        vm.prank(address(0));
        IEVault(vaultCluster1).setLTV(vaultCluster2, 1e4, 1e4, 0);

        // verifies that the vault 3 still belongs to the cluster conservative perspective
        eulerDefaultClusterPerspective.perspectiveVerify(vaultCluster3, true);

        // however, the cluster conservative perspective should not be able to verify the vault cluster 1 and 2
        // as they reference each other
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(eulerDefaultClusterPerspective),
                vaultCluster1,
                ERROR__LTV_CONFIG
            )
        );
        eulerDefaultClusterPerspective.perspectiveVerify(vaultCluster1, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(eulerDefaultClusterPerspective),
                vaultCluster2,
                ERROR__LTV_COLLATERAL_RECOGNITION
            )
        );
        eulerDefaultClusterPerspective.perspectiveVerify(vaultCluster2, true);
    }
}
