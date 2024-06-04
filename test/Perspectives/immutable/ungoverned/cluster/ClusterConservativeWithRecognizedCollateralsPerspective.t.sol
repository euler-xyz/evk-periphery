// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {ClusterSetupTest} from "./ClusterSetupTest.sol";
import {IEVault} from "euler-vault-kit/EVault/IEVault.sol";
import {IPerspective} from "../../../../../src/Perspectives/interfaces/IPerspective.sol";

contract ClusterConservativeWithRecognizedCollateralsPerspectiveTest is ClusterSetupTest {
    function setUp() public override {
        super.setUp();
    }

    function test_Perspective_ClusterConservativeWithRecognizedCollateralsPerspective_name() public view {
        assertEq(
            clusterConservativeWithRecognizedCollateralsPerspective1.name(),
            "Immutable.Ungoverned.ClusterConservativeWithRecognizedCollateralsPerspective"
        );
        assertEq(
            clusterConservativeWithRecognizedCollateralsPerspective2.name(),
            "Immutable.Ungoverned.ClusterConservativeWithRecognizedCollateralsPerspective"
        );
        assertEq(
            clusterConservativeWithRecognizedCollateralsPerspective3.name(),
            "Immutable.Ungoverned.ClusterConservativeWithRecognizedCollateralsPerspective"
        );
    }

    function test_Perspective_ClusterConservativeWithRecognizedCollateralsPerspective_general() public {
        uint256 snapshot = vm.snapshot();

        // verifies that the escrow vault will fail right away if verified by the cluster perspective 1
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(clusterConservativeWithRecognizedCollateralsPerspective1),
                vaultEscrow,
                ERROR__ORACLE
            )
        );
        clusterConservativeWithRecognizedCollateralsPerspective1.perspectiveVerify(vaultEscrow, true);

        // verifies that the vault cluster 3 will fail right away if verified by the escrow perspective
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(escrowSingletonPerspective),
                vaultCluster3,
                ERROR__ORACLE
            )
        );
        escrowSingletonPerspective.perspectiveVerify(vaultCluster3, true);

        // verifies that the vault cluster 1 belongs to the cluster perspective 1.
        // while verifying the vault cluster 1, the cluster perspective 1 will also verify the vault cluster 2 as they
        // reference each other
        vm.expectEmit(true, false, false, false, address(clusterConservativeWithRecognizedCollateralsPerspective1));
        emit IPerspective.PerspectiveVerified(vaultCluster2);
        vm.expectEmit(true, false, false, false, address(clusterConservativeWithRecognizedCollateralsPerspective1));
        emit IPerspective.PerspectiveVerified(vaultCluster1);
        clusterConservativeWithRecognizedCollateralsPerspective1.perspectiveVerify(vaultCluster1, true);
        clusterConservativeWithRecognizedCollateralsPerspective1.perspectiveVerify(vaultCluster2, true);
        assertTrue(clusterConservativeWithRecognizedCollateralsPerspective1.isVerified(vaultCluster1));
        assertTrue(clusterConservativeWithRecognizedCollateralsPerspective1.isVerified(vaultCluster2));
        assertEq(clusterConservativeWithRecognizedCollateralsPerspective1.verifiedArray()[0], vaultCluster2);
        assertEq(clusterConservativeWithRecognizedCollateralsPerspective1.verifiedArray()[1], vaultCluster1);

        // verifies that the vault cluster 3 belongs to the cluster perspective 2.
        // while verifying the vault cluster 3, the escrow perspective will also verify the vault escrow
        vm.expectEmit(true, false, false, false, address(escrowSingletonPerspective));
        emit IPerspective.PerspectiveVerified(vaultEscrow);
        vm.expectEmit(true, false, false, false, address(clusterConservativeWithRecognizedCollateralsPerspective2));
        emit IPerspective.PerspectiveVerified(vaultCluster3);
        clusterConservativeWithRecognizedCollateralsPerspective2.perspectiveVerify(vaultCluster3, true);
        assertTrue(escrowSingletonPerspective.isVerified(vaultEscrow));
        assertTrue(clusterConservativeWithRecognizedCollateralsPerspective2.isVerified(vaultCluster3));
        assertEq(escrowSingletonPerspective.verifiedArray()[0], vaultEscrow);
        assertEq(clusterConservativeWithRecognizedCollateralsPerspective2.verifiedArray()[0], vaultCluster3);
        assertEq(escrowSingletonPerspective.assetLookup(address(assetTST)), vaultEscrow);

        // verifies that all the cluster vaults cluster belong to the cluster perspective 3
        clusterConservativeWithRecognizedCollateralsPerspective3.perspectiveVerify(vaultCluster1, true);
        clusterConservativeWithRecognizedCollateralsPerspective3.perspectiveVerify(vaultCluster2, true);
        clusterConservativeWithRecognizedCollateralsPerspective3.perspectiveVerify(vaultCluster3, true);

        // revert to the initial state
        vm.revertTo(snapshot);

        // impersonate the governor to modify vault cluster 3 by adding a new collateral
        vm.prank(address(0));
        IEVault(vaultCluster3).setLTV(vaultCluster2, 0.7e4, 0.8e4, 0);

        // verifies that the vault cluster 3 still belongs to the cluster perspective 3, even with an additional
        // collateral
        clusterConservativeWithRecognizedCollateralsPerspective3.perspectiveVerify(vaultCluster3, true);

        // meanwhile, other vaults got verified too
        assertTrue(clusterConservativeWithRecognizedCollateralsPerspective3.isVerified(vaultCluster3));
        assertTrue(escrowSingletonPerspective.isVerified(vaultEscrow));
        assertTrue(clusterConservativeWithRecognizedCollateralsPerspective1.isVerified(vaultCluster1));
        assertTrue(clusterConservativeWithRecognizedCollateralsPerspective1.isVerified(vaultCluster2));
    }
}
