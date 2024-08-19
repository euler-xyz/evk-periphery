// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {DefaultSetupTest} from "./DefaultSetupTest.sol";
import {GovernedPerspective} from "../../src/Perspectives/deployed/GovernedPerspective.sol";
import {EulerBasePlusPerspective} from "../../src/Perspectives/deployed/EulerBasePlusPerspective.sol";
import {IPerspective} from "../../src/Perspectives/implementation/interfaces/IPerspective.sol";

contract EulerBasePlusPerspectiveTest is DefaultSetupTest {
    GovernedPerspective governedPerspective;
    EulerBasePlusPerspective eulerBasePlusPerspective;

    function setUp() public override {
        super.setUp();

        governedPerspective = new GovernedPerspective(address(this));

        address[] memory recognizedCollateralPerspectives = new address[](1);
        recognizedCollateralPerspectives[0] = address(governedPerspective);
        eulerBasePlusPerspective = new EulerBasePlusPerspective(
            "Euler Base Plus Perspective",
            address(factory),
            address(routerFactory),
            address(adapterRegistry),
            address(externalVaultRegistry),
            address(irmFactory),
            address(irmRegistry),
            recognizedCollateralPerspectives,
            address(governedPerspective)
        );
    }

    function test_Perspective_EulerBasPlusePerspective_name() public view {
        assertEq(eulerBasePlusPerspective.name(), "Euler Base Plus Perspective");
    }

    function test_Perspective_EulerBasePlusPerspective_general() public {
        uint256 snapshot = vm.snapshot();

        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(eulerBasePlusPerspective),
                vaultBase1,
                ERROR__LTV_COLLATERAL_RECOGNITION
            )
        );
        eulerBasePlusPerspective.perspectiveVerify(vaultBase1, true);

        // but this succeeds
        eulerBasePerspective1.perspectiveVerify(vaultBase1, true);

        // revert to the initial state
        vm.revertTo(snapshot);

        // verify vault base 2, which is a collateral of vault base 1, in the governed perspective
        governedPerspective.perspectiveVerify(vaultBase2, true);

        // now succeeds
        vm.expectEmit(true, false, false, false, address(eulerBasePlusPerspective));
        emit IPerspective.PerspectiveVerified(vaultBase1);
        eulerBasePlusPerspective.perspectiveVerify(vaultBase1, true);
        assertTrue(eulerBasePlusPerspective.isVerified(vaultBase1));
        assertEq(eulerBasePlusPerspective.verifiedArray()[0], vaultBase1);
    }
}
