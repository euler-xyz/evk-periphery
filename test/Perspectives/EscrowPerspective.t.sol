// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVault} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

import {EscrowPerspective} from "../../src/Perspectives/deployed/EscrowPerspective.sol";
import {PerspectiveErrors} from "../../src/Perspectives/implementation/PerspectiveErrors.sol";
import {IPerspective} from "../../src/Perspectives/implementation/interfaces/IPerspective.sol";

contract EscrowPerspectiveTest is EVaultTestBase, PerspectiveErrors {
    event PerspectiveVerified(address indexed vault);

    EscrowPerspective perspective;

    function setUp() public override {
        super.setUp();
        perspective = new EscrowPerspective(address(factory));
    }

    function test_EscrowPerspective_name() public view {
        assertEq(perspective.name(), "Escrow Perspective");
    }

    function test_EscrowPerspective_general() public {
        // deploy and configure the vault
        address vault =
            factory.createProxy(address(0), true, abi.encodePacked(address(assetTST), address(0), address(0)));
        IEVault(vault).setHookConfig(address(0), 0);
        IEVault(vault).setGovernorAdmin(address(0));

        vm.expectEmit(true, false, false, false, address(perspective));
        emit PerspectiveVerified(vault);
        perspective.perspectiveVerify(vault, true);
        assertTrue(perspective.isVerified(vault));
        assertEq(perspective.verifiedArray()[0], vault);
        assertEq(perspective.singletonLookup(address(assetTST)), vault);
    }

    function test_Revert_Perspective_Escrow() public {
        // deploy and configure the vaults
        address vault1 =
            factory.createProxy(address(0), true, abi.encodePacked(address(assetTST), address(0), address(0)));
        address vault2 =
            factory.createProxy(address(0), true, abi.encodePacked(address(assetTST), address(0), address(0)));
        address vault3 =
            factory.createProxy(address(0), false, abi.encodePacked(address(assetTST), address(1), address(2)));
        address vault4 =
            factory.createProxy(address(0), true, abi.encodePacked(address(assetTST), address(0), address(0)));

        IEVault(vault1).setHookConfig(address(0), 0);
        IEVault(vault1).setGovernorAdmin(address(0));

        IEVault(vault2).setHookConfig(address(0), 0);
        IEVault(vault2).setGovernorAdmin(address(0));

        // this vault will violate some rules
        IEVault(vault3).setMaxLiquidationDiscount(1);
        IEVault(vault3).setHookConfig(address(0), 1);
        IEVault(vault3).setLTV(address(0), 0, 0, 0);
        IEVault(vault3).setCaps(1, 0);

        // this vault will be okay because it has greater than zero supply cap, but zero borrow cap
        IEVault(vault4).setCaps(1, 0);
        IEVault(vault4).setHookConfig(address(0), 0);
        IEVault(vault4).setGovernorAdmin(address(0));

        // verification of the first vault is successful
        vm.expectEmit(true, false, false, false, address(perspective));
        emit PerspectiveVerified(vault1);
        perspective.perspectiveVerify(vault1, true);
        assertEq(perspective.singletonLookup(address(assetTST)), vault1);

        // verification of the second vault will fail due to the singleton rule
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector, address(perspective), vault2, ERROR__SINGLETON
            )
        );
        perspective.perspectiveVerify(vault2, true);

        // verification of the third vault will fail right away due to lack of upgradability
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector, address(perspective), vault3, ERROR__UPGRADABILITY
            )
        );
        perspective.perspectiveVerify(vault3, true);

        // verification of the fourth vault is successful
        vm.expectEmit(true, false, false, false, address(perspective));
        emit PerspectiveVerified(vault4);
        perspective.perspectiveVerify(vault4, true);
        assertEq(perspective.singletonLookup(address(assetTST)), vault1); // no override

        // if fail early not requested, the third vault verification will collect all the errors and fail at the end
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector,
                address(perspective),
                vault3,
                ERROR__UPGRADABILITY | ERROR__ORACLE_INVALID_ROUTER | ERROR__UNIT_OF_ACCOUNT | ERROR__GOVERNOR
                    | ERROR__HOOKED_OPS | ERROR__LIQUIDATION_DISCOUNT | ERROR__LTV_COLLATERAL_CONFIG_LENGTH
            )
        );
        perspective.perspectiveVerify(vault3, false);

        // if fail early not requested, the second vault verification will collect all the errors and fail at the end
        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector, address(perspective), vault2, ERROR__SINGLETON
            )
        );
        perspective.perspectiveVerify(vault2, false);
    }
}
