// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {IGovernance} from "evk/EVault/IEVault.sol";
import {Errors} from "evk/EVault/shared/Errors.sol";
import {GovernorAccessControlEmergency} from "../../src/Governor/GovernorAccessControlEmergency.sol";
import {EMERGENCY_HOOKED_OPS} from "../../script/production/ManageClusterBase.s.sol";

contract ManageClusterEmergencyOperationsTest is EVaultTestBase {
    GovernorAccessControlEmergency internal governor;
    address internal guardian;

    function setUp() public override {
        super.setUp();
        guardian = makeAddr("guardian");
        governor = new GovernorAccessControlEmergency(address(evc), admin);
        bytes32 hookEmergencyRole = governor.HOOK_EMERGENCY_ROLE();

        vm.prank(admin);
        governor.grantRole(hookEmergencyRole, guardian);
    }

    function test_emergencyHookedOps_hookEmergencyRoleDisablesVaultThroughGovernor() public {
        eTST.setGovernorAdmin(address(governor));

        IEVC.BatchItem[] memory items = new IEVC.BatchItem[](1);
        items[0] = IEVC.BatchItem({
            targetContract: address(governor),
            onBehalfOfAccount: guardian,
            value: 0,
            data: abi.encodePacked(
                abi.encodeCall(IGovernance.setHookConfig, (address(0), EMERGENCY_HOOKED_OPS)), address(eTST)
            )
        });

        vm.prank(guardian);
        evc.batch(items);

        assertOperationsDisabled();
    }

    function test_emergencyHookedOps_governorAdminDisablesVault() public {
        eTST.setHookConfig(address(0), EMERGENCY_HOOKED_OPS);

        assertOperationsDisabled();
    }

    function assertOperationsDisabled() internal {
        (address hookTarget, uint32 hookedOps) = eTST.hookConfig();
        assertEq(hookTarget, address(0));
        assertEq(hookedOps, EMERGENCY_HOOKED_OPS);

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        eTST.deposit(1, address(this));
    }
}
