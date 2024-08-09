// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {DefaultSetupTest} from "./DefaultSetupTest.sol";
import {IEVault} from "euler-vault-kit/EVault/IEVault.sol";
import {IPerspective} from "../../src/Perspectives/implementation/interfaces/IPerspective.sol";

contract EulerBasePerspectiveTest is DefaultSetupTest {
    function setUp() public override {
        super.setUp();
    }

    function test_Perspective_EulerBasePerspective_name() public view {
        assertEq(eulerBasePerspective1.name(), "Euler Base Perspective");
        assertEq(eulerBasePerspective2.name(), "Euler Base Perspective");
        assertEq(eulerBasePerspective3.name(), "Euler Base Perspective");
    }

    function test_Perspective_EulerBasePerspective_general() public {
        uint256 snapshot = vm.snapshot();

        // verifies that the escrow vault will fail right away if verified by the default perspective 1
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(eulerBasePerspective1),
                vaultEscrow,
                ERROR__INTEREST_RATE_MODEL
            )
        );
        eulerBasePerspective1.perspectiveVerify(vaultEscrow, true);

        // verifies that the vault base 3 will fail right away if verified by the escrow perspective
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(escrowPerspective),
                vaultBase3,
                ERROR__ORACLE_INVALID_ROUTER
            )
        );
        escrowPerspective.perspectiveVerify(vaultBase3, true);

        // verifies that the vault base 1 belongs to the default perspective 1.
        // while verifying the vault base 1, the default perspective 1 will also verify the vault base 2 as they
        // reference each other
        vm.expectEmit(true, false, false, false, address(eulerBasePerspective1));
        emit IPerspective.PerspectiveVerified(vaultBase2);
        vm.expectEmit(true, false, false, false, address(eulerBasePerspective1));
        emit IPerspective.PerspectiveVerified(vaultBase1);
        eulerBasePerspective1.perspectiveVerify(vaultBase1, true);
        eulerBasePerspective1.perspectiveVerify(vaultBase2, true);
        assertTrue(eulerBasePerspective1.isVerified(vaultBase1));
        assertTrue(eulerBasePerspective1.isVerified(vaultBase2));
        assertEq(eulerBasePerspective1.verifiedArray()[0], vaultBase2);
        assertEq(eulerBasePerspective1.verifiedArray()[1], vaultBase1);

        // verifies that the vault base 3 belongs to the default perspective 2.
        // while verifying the vault base 3, the escrow perspective will also verify the vault escrow
        vm.expectEmit(true, false, false, false, address(escrowPerspective));
        emit IPerspective.PerspectiveVerified(vaultEscrow);
        vm.expectEmit(true, false, false, false, address(eulerBasePerspective2));
        emit IPerspective.PerspectiveVerified(vaultBase3);
        eulerBasePerspective2.perspectiveVerify(vaultBase3, true);
        assertTrue(escrowPerspective.isVerified(vaultEscrow));
        assertTrue(eulerBasePerspective2.isVerified(vaultBase3));
        assertEq(escrowPerspective.verifiedArray()[0], vaultEscrow);
        assertEq(eulerBasePerspective2.verifiedArray()[0], vaultBase3);

        // verification of the vault base 4 fails
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(eulerBasePerspective2),
                vaultBase4,
                ERROR__UPGRADABILITY | ERROR__INTEREST_RATE_MODEL
            )
        );
        eulerBasePerspective2.perspectiveVerify(vaultBase4, false);

        // verifies that the vault belongs to the default perspective 1.
        // while verifying the vault, the default perspective 1 will also verify the vault base 5 as they
        // reference each other
        vm.expectEmit(true, false, false, false, address(eulerBasePerspective1));
        emit IPerspective.PerspectiveVerified(vaultBase6xv);
        vm.expectEmit(true, false, false, false, address(eulerBasePerspective1));
        emit IPerspective.PerspectiveVerified(vaultBase5xv);
        eulerBasePerspective1.perspectiveVerify(vaultBase5xv, true);
        eulerBasePerspective1.perspectiveVerify(vaultBase6xv, true);
        assertTrue(eulerBasePerspective1.isVerified(vaultBase5xv));
        assertTrue(eulerBasePerspective1.isVerified(vaultBase6xv));
        assertEq(eulerBasePerspective1.verifiedArray()[0], vaultBase2);
        assertEq(eulerBasePerspective1.verifiedArray()[1], vaultBase1);
        assertEq(eulerBasePerspective1.verifiedArray()[2], vaultBase6xv);
        assertEq(eulerBasePerspective1.verifiedArray()[3], vaultBase5xv);

        // verifies that all the base vaults base belong to the default perspective 3
        eulerBasePerspective3.perspectiveVerify(vaultBase1, true);
        eulerBasePerspective3.perspectiveVerify(vaultBase2, true);
        eulerBasePerspective3.perspectiveVerify(vaultBase3, true);
        eulerBasePerspective3.perspectiveVerify(vaultBase5xv, true);
        eulerBasePerspective3.perspectiveVerify(vaultBase6xv, true);

        // revert to the initial state
        vm.revertTo(snapshot);

        // impersonate the governor to modify vault base 3 by adding a new collateral
        vm.prank(address(0));
        IEVault(vaultBase3).setLTV(vaultBase2, 0.7e4, 0.8e4, 0);

        // verifies that the vault base 3 still belongs to the default perspective 3, even with an additional
        // collateral
        eulerBasePerspective3.perspectiveVerify(vaultBase3, true);

        // meanwhile, other vaults got verified too
        assertTrue(eulerBasePerspective3.isVerified(vaultBase3));
        assertTrue(escrowPerspective.isVerified(vaultEscrow));
        assertTrue(eulerBasePerspective1.isVerified(vaultBase1));
        assertTrue(eulerBasePerspective1.isVerified(vaultBase2));
    }

    function test_Perspective_DefaultPerspectiveInstance_nesting() public {
        address nestedVault =
            factory.createProxy(address(0), true, abi.encodePacked(address(vaultBase1), address(0), address(0)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector, address(eulerBasePerspective1), nestedVault, ERROR__NESTING
            )
        );
        eulerBasePerspective1.perspectiveVerify(nestedVault, true);
    }
}
