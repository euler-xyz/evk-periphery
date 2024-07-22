// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {DefaultSetupTest} from "./DefaultSetupTest.sol";
import {IEVault} from "euler-vault-kit/EVault/IEVault.sol";
import {IPerspective} from "../../src/Perspectives/implementation/interfaces/IPerspective.sol";

import {EulerBasePerspective} from "../../src/Perspectives/deployed/EulerBasePerspective.sol";

contract EulerBasePerspectiveTest is DefaultSetupTest {
    function setUp() public override {
        super.setUp();
    }

    function test_Perspective_EulerBasePerspective_constructor() public {
        vm.expectRevert();
        new EulerBasePerspective(address(0), address(0), address(0), address(0), address(0), address(0));

        vm.expectRevert();
        new EulerBasePerspective(
            address(0), address(0), address(0), address(0), address(0), address(defaultPerspectiveInstance1)
        );

        // no revert
        new EulerBasePerspective(address(0), address(0), address(0), address(0), address(0), address(escrowPerspective));
    }

    function test_Perspective_EulerBasePerspective_name() public view {
        assertEq(eulerBasePerspective.name(), "Euler Base Perspective");
    }

    function test_Perspective_EulerBasePerspective_general() public {
        uint256 snapshot = vm.snapshot();

        // verifies that the escrow vault will fail right away if verified by the base perspective
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(eulerBasePerspective),
                vaultEscrow,
                ERROR__INTEREST_RATE_MODEL
            )
        );
        eulerBasePerspective.perspectiveVerify(vaultEscrow, true);

        vm.expectEmit(true, false, false, false, address(eulerBasePerspective));
        emit IPerspective.PerspectiveVerified(vaultBase2);
        vm.expectEmit(true, false, false, false, address(eulerBasePerspective));
        emit IPerspective.PerspectiveVerified(vaultBase1);
        eulerBasePerspective.perspectiveVerify(vaultBase1, true);
        eulerBasePerspective.perspectiveVerify(vaultBase2, true);
        assertTrue(eulerBasePerspective.isVerified(vaultBase1));
        assertTrue(eulerBasePerspective.isVerified(vaultBase2));
        assertEq(eulerBasePerspective.verifiedArray()[0], vaultBase2);
        assertEq(eulerBasePerspective.verifiedArray()[1], vaultBase1);

        vm.expectEmit(true, false, false, false, address(escrowPerspective));
        emit IPerspective.PerspectiveVerified(vaultEscrow);
        vm.expectEmit(true, false, false, false, address(eulerBasePerspective));
        emit IPerspective.PerspectiveVerified(vaultBase3);
        eulerBasePerspective.perspectiveVerify(vaultBase3, true);
        assertTrue(escrowPerspective.isVerified(vaultEscrow));
        assertTrue(eulerBasePerspective.isVerified(vaultBase3));
        assertEq(escrowPerspective.verifiedArray()[0], vaultEscrow);
        assertEq(eulerBasePerspective.verifiedArray()[2], vaultBase3);

        // revert to the initial state
        vm.revertTo(snapshot);

        // impersonate the governor to modify vault base 1 by modifying the LTV in a way the base perspective will not
        // be able to verify it anymore
        vm.prank(address(0));
        IEVault(vaultBase1).setLTV(vaultBase2, 1e4, 1e4, 0);

        // verifies that the vault 3 still belongs to the base perspective
        eulerBasePerspective.perspectiveVerify(vaultBase3, true);

        // however, the base perspective should not be able to verify the vault base 1 and 2
        // as they reference each other
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(eulerBasePerspective),
                vaultBase1,
                ERROR__LTV_COLLATERAL_CONFIG_SEPARATION
            )
        );
        eulerBasePerspective.perspectiveVerify(vaultBase1, true);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(eulerBasePerspective),
                vaultBase2,
                ERROR__LTV_COLLATERAL_RECOGNITION
            )
        );
        eulerBasePerspective.perspectiveVerify(vaultBase2, true);
    }
}
