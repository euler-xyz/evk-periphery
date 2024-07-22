// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {DefaultSetupTest} from "./DefaultSetupTest.sol";
import {IEVault} from "euler-vault-kit/EVault/IEVault.sol";
import {IPerspective} from "../../src/Perspectives/implementation/interfaces/IPerspective.sol";

contract DefaultPerspectiveInstanceTest is DefaultSetupTest {
    function setUp() public override {
        super.setUp();
    }

    function test_Perspective_DefaultPerspectiveInstance_name() public view {
        assertEq(defaultPerspectiveInstance1.name(), "Default Perspective Instance");
        assertEq(defaultPerspectiveInstance2.name(), "Default Perspective Instance");
        assertEq(defaultPerspectiveInstance3.name(), "Default Perspective Instance");
    }

    function test_Perspective_DefaultPerspectiveInstance_general() public {
        uint256 snapshot = vm.snapshot();

        // verifies that the escrow vault will fail right away if verified by the default perspective 1
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(defaultPerspectiveInstance1),
                vaultEscrow,
                ERROR__INTEREST_RATE_MODEL
            )
        );
        defaultPerspectiveInstance1.perspectiveVerify(vaultEscrow, true);

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
        vm.expectEmit(true, false, false, false, address(defaultPerspectiveInstance1));
        emit IPerspective.PerspectiveVerified(vaultBase2);
        vm.expectEmit(true, false, false, false, address(defaultPerspectiveInstance1));
        emit IPerspective.PerspectiveVerified(vaultBase1);
        defaultPerspectiveInstance1.perspectiveVerify(vaultBase1, true);
        defaultPerspectiveInstance1.perspectiveVerify(vaultBase2, true);
        assertTrue(defaultPerspectiveInstance1.isVerified(vaultBase1));
        assertTrue(defaultPerspectiveInstance1.isVerified(vaultBase2));
        assertEq(defaultPerspectiveInstance1.verifiedArray()[0], vaultBase2);
        assertEq(defaultPerspectiveInstance1.verifiedArray()[1], vaultBase1);

        // verifies that the vault base 3 belongs to the default perspective 2.
        // while verifying the vault base 3, the escrow perspective will also verify the vault escrow
        vm.expectEmit(true, false, false, false, address(escrowPerspective));
        emit IPerspective.PerspectiveVerified(vaultEscrow);
        vm.expectEmit(true, false, false, false, address(defaultPerspectiveInstance2));
        emit IPerspective.PerspectiveVerified(vaultBase3);
        defaultPerspectiveInstance2.perspectiveVerify(vaultBase3, true);
        assertTrue(escrowPerspective.isVerified(vaultEscrow));
        assertTrue(defaultPerspectiveInstance2.isVerified(vaultBase3));
        assertEq(escrowPerspective.verifiedArray()[0], vaultEscrow);
        assertEq(defaultPerspectiveInstance2.verifiedArray()[0], vaultBase3);

        // verifies that the vault base 4 belongs to the default perspective 1.
        // while verifying the vault base 4, the default perspective 1 will also verify the vault base 5 as they
        // reference each other
        vm.expectEmit(true, false, false, false, address(defaultPerspectiveInstance1));
        emit IPerspective.PerspectiveVerified(vaultBase5xv);
        vm.expectEmit(true, false, false, false, address(defaultPerspectiveInstance1));
        emit IPerspective.PerspectiveVerified(vaultBase4xv);
        defaultPerspectiveInstance1.perspectiveVerify(vaultBase4xv, true);
        defaultPerspectiveInstance1.perspectiveVerify(vaultBase5xv, true);
        assertTrue(defaultPerspectiveInstance1.isVerified(vaultBase4xv));
        assertTrue(defaultPerspectiveInstance1.isVerified(vaultBase5xv));
        assertEq(defaultPerspectiveInstance1.verifiedArray()[0], vaultBase2);
        assertEq(defaultPerspectiveInstance1.verifiedArray()[1], vaultBase1);
        assertEq(defaultPerspectiveInstance1.verifiedArray()[2], vaultBase5xv);
        assertEq(defaultPerspectiveInstance1.verifiedArray()[3], vaultBase4xv);

        // verifies that all the base vaults base belong to the default perspective 3
        defaultPerspectiveInstance3.perspectiveVerify(vaultBase1, true);
        defaultPerspectiveInstance3.perspectiveVerify(vaultBase2, true);
        defaultPerspectiveInstance3.perspectiveVerify(vaultBase3, true);
        defaultPerspectiveInstance3.perspectiveVerify(vaultBase4xv, true);
        defaultPerspectiveInstance3.perspectiveVerify(vaultBase5xv, true);

        // revert to the initial state
        vm.revertTo(snapshot);

        // impersonate the governor to modify vault base 3 by adding a new collateral
        vm.prank(address(0));
        IEVault(vaultBase3).setLTV(vaultBase2, 0.7e4, 0.8e4, 0);

        // verifies that the vault base 3 still belongs to the default perspective 3, even with an additional
        // collateral
        defaultPerspectiveInstance3.perspectiveVerify(vaultBase3, true);

        // meanwhile, other vaults got verified too
        assertTrue(defaultPerspectiveInstance3.isVerified(vaultBase3));
        assertTrue(escrowPerspective.isVerified(vaultEscrow));
        assertTrue(defaultPerspectiveInstance1.isVerified(vaultBase1));
        assertTrue(defaultPerspectiveInstance1.isVerified(vaultBase2));
    }

    function test_Perspective_DefaultPerspectiveInstance_nesting() public {
        address nestedVault =
            factory.createProxy(address(0), false, abi.encodePacked(address(vaultBase1), address(0), address(0)));
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(defaultPerspectiveInstance1),
                nestedVault,
                ERROR__NESTING
            )
        );
        defaultPerspectiveInstance1.perspectiveVerify(nestedVault, true);
    }
}
