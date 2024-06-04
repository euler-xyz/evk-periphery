// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {ClusterSetupTest} from "./ClusterSetupTest.sol";
import {IEVault} from "euler-vault-kit/EVault/IEVault.sol";
import {IPerspective} from "../../../../../src/Perspectives/interfaces/IPerspective.sol";

import {ClusterConservativePerspective} from
    "../../../../../src/Perspectives/immutable/ungoverned/cluster/ClusterConservativePerspective.sol";

contract ClusterConservativePerspectiveTest is ClusterSetupTest {
    function setUp() public override {
        super.setUp();
    }

    function test_Perspective_ClusterConservativePerspective_constructor() public {
        vm.expectRevert();
        new ClusterConservativePerspective(address(0), address(0), address(0), address(0), address(0));

        vm.expectRevert();
        new ClusterConservativePerspective(
            address(0),
            address(0),
            address(0),
            address(0),
            address(clusterConservativeWithRecognizedCollateralsPerspective1)
        );

        // no revert
        new ClusterConservativePerspective(
            address(0), address(0), address(0), address(0), address(escrowSingletonPerspective)
        );
    }

    function test_Perspective_ClusterConservativePerspective_name() public view {
        assertEq(clusterConservativePerspective.name(), "Immutable.Ungoverned.ClusterConservativePerspective");
    }

    function test_Perspective_ClusterConservativePerspective_general() public {
        uint256 snapshot = vm.snapshot();

        // verifies that the escrow vault will fail right away if verified by the cluster conservative perspective
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(clusterConservativePerspective),
                vaultEscrow,
                ERROR__ORACLE
            )
        );
        clusterConservativePerspective.perspectiveVerify(vaultEscrow, true);

        vm.expectEmit(true, false, false, false, address(clusterConservativePerspective));
        emit IPerspective.PerspectiveVerified(vaultCluster2);
        vm.expectEmit(true, false, false, false, address(clusterConservativePerspective));
        emit IPerspective.PerspectiveVerified(vaultCluster1);
        clusterConservativePerspective.perspectiveVerify(vaultCluster1, true);
        clusterConservativePerspective.perspectiveVerify(vaultCluster2, true);
        assertTrue(clusterConservativePerspective.isVerified(vaultCluster1));
        assertTrue(clusterConservativePerspective.isVerified(vaultCluster2));
        assertEq(clusterConservativePerspective.verifiedArray()[0], vaultCluster2);
        assertEq(clusterConservativePerspective.verifiedArray()[1], vaultCluster1);

        vm.expectEmit(true, false, false, false, address(escrowSingletonPerspective));
        emit IPerspective.PerspectiveVerified(vaultEscrow);
        vm.expectEmit(true, false, false, false, address(clusterConservativePerspective));
        emit IPerspective.PerspectiveVerified(vaultCluster3);
        clusterConservativePerspective.perspectiveVerify(vaultCluster3, true);
        assertTrue(escrowSingletonPerspective.isVerified(vaultEscrow));
        assertTrue(clusterConservativePerspective.isVerified(vaultCluster3));
        assertEq(escrowSingletonPerspective.verifiedArray()[0], vaultEscrow);
        assertEq(clusterConservativePerspective.verifiedArray()[2], vaultCluster3);

        // revert to the initial state
        vm.revertTo(snapshot);

        // impersonate the governor to modify vault cluster 1 by modifying the LTV in a way the cluster conservative
        // perspective will not be able to verify it anymore
        vm.prank(address(0));
        IEVault(vaultCluster1).setLTV(vaultCluster2, 1e4, 1e4, 0);

        // verifies that the vault 3 still belongs to the cluster conservative perspective
        clusterConservativePerspective.perspectiveVerify(vaultCluster3, true);

        // however, the cluster conservative perspective should not be able to verify the vault cluster 1 and 2
        // as they reference each other
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(clusterConservativePerspective),
                vaultCluster1,
                ERROR__LTV_CONFIG
            )
        );
        clusterConservativePerspective.perspectiveVerify(vaultCluster1, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(clusterConservativePerspective),
                vaultCluster2,
                ERROR__LTV_COLLATERAL_RECOGNITION
            )
        );
        clusterConservativePerspective.perspectiveVerify(vaultCluster2, true);
    }
}
