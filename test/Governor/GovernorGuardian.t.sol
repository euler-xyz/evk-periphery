// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVault, IERC4626, IERC20} from "evk/EVault/IEVault.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import {GovernorGuardian} from "../../src/Governor/GovernorGuardian.sol";
import {Errors} from "evk/EVault/shared/Errors.sol";
import "evk/EVault/shared/Constants.sol";

contract MockTargetHook {
    function isHookTarget() external pure returns (bytes4) {
        return this.isHookTarget.selector;
    }
}

contract GovernorGuardianTests is EVaultTestBase {
    GovernorGuardian governorGuardian;
    address guardian;
    address depositor;
    address[] vaults;

    function setUp() public virtual override {
        super.setUp();
        guardian = makeAddr("guardian");
        depositor = makeAddr("depositor");
        governorGuardian = new GovernorGuardian(admin, 100, 200);

        startHoax(admin);
        governorGuardian.grantRole(governorGuardian.GUARDIAN_ROLE(), guardian);

        startHoax(address(this));
        eTST.setGovernorAdmin(address(governorGuardian));

        startHoax(depositor);

        assetTST.mint(depositor, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);

        assetTST2.mint(depositor, type(uint256).max);
        assetTST2.approve(address(eTST), type(uint256).max);

        vaults = new address[](1);
        vaults[0] = address(eTST);

        vm.stopPrank();
    }

    function test_GovernorGuardian_addGuardians() external {
        address guardian2 = makeAddr("guardian2");

        startHoax(guardian2);
        expectAccessControlRevert(guardian2, governorGuardian.GUARDIAN_ROLE());
        governorGuardian.pause(vaults);

        startHoax(admin);
        governorGuardian.grantRole(governorGuardian.GUARDIAN_ROLE(), guardian2);

        startHoax(guardian2);
        governorGuardian.pause(vaults);
    }

    function test_GovernorGuardian_onlyAdminCanDoAdminCall() external {
        expectAccessControlRevert(address(this), governorGuardian.DEFAULT_ADMIN_ROLE());
        governorGuardian.adminCall(vaults[0], abi.encodeWithSelector(IEVault(vaults[0]).convertFees.selector));

        startHoax(depositor);
        expectAccessControlRevert(depositor, governorGuardian.DEFAULT_ADMIN_ROLE());
        governorGuardian.adminCall(vaults[0], abi.encodeWithSelector(IEVault(vaults[0]).convertFees.selector));

        startHoax(guardian);
        expectAccessControlRevert(guardian, governorGuardian.DEFAULT_ADMIN_ROLE());
        governorGuardian.adminCall(vaults[0], abi.encodeWithSelector(IEVault(vaults[0]).convertFees.selector));

        startHoax(admin);
        governorGuardian.adminCall(vaults[0], abi.encodeWithSelector(IEVault(vaults[0]).convertFees.selector));
    }

    function test_GovernorGuardian_adminCall() external {
        assertEq(eTST.governorAdmin(), address(governorGuardian));

        bytes memory data = abi.encodeWithSelector(eTST.setGovernorAdmin.selector, admin);
        startHoax(admin);
        governorGuardian.adminCall(address(eTST), data);

        assertEq(eTST.governorAdmin(), admin);
    }

    function test_GovernorGuardian_adminCallFailed() external {
        assertEq(eTST2.governorAdmin(), address(this));

        bytes memory data = abi.encodeWithSelector(eTST2.setGovernorAdmin.selector, admin);

        startHoax(admin);
        vm.expectRevert(Errors.E_Unauthorized.selector);
        governorGuardian.adminCall(address(eTST2), data);

        assertEq(eTST.governorAdmin(), address(governorGuardian));

        data = abi.encodeWithSelector(eTST.setLTV.selector, address(eTST), 0, 0, 0);

        startHoax(admin);
        vm.expectRevert(Errors.E_InvalidLTVAsset.selector);
        governorGuardian.adminCall(address(eTST), data);
    }

    function test_GovernorGuardian_setHookConfigByAdminCall() external {
        assertEq(IEVault(vaults[0]).governorAdmin(), address(governorGuardian));
        assertEq(governorGuardian.canPauseStatusChange(vaults[0]), true);

        address mockTargetHook = address(new MockTargetHook());
        bytes memory data = abi.encodeWithSelector(IEVault(vaults[0]).setHookConfig.selector, mockTargetHook, 0);

        startHoax(admin);
        governorGuardian.adminCall(vaults[0], data);

        (address hook,) = IEVault(vaults[0]).hookConfig();
        assertEq(hook, address(mockTargetHook));

        assertEq(governorGuardian.canPauseStatusChange(vaults[0]), false);

        data = abi.encodeWithSelector(IEVault(vaults[0]).setHookConfig.selector, address(0), 0);
        governorGuardian.adminCall(vaults[0], data);
        (hook,) = IEVault(vaults[0]).hookConfig();
        assertEq(hook, address(0));

        assertEq(governorGuardian.canPauseStatusChange(vaults[0]), true);
    }

    function test_GovernorGuardian_onlyGuardianCanPause() external {
        assertEq(IEVault(vaults[0]).governorAdmin(), address(governorGuardian));

        expectAccessControlRevert(address(this), governorGuardian.GUARDIAN_ROLE());
        governorGuardian.pause(vaults);

        startHoax(depositor);
        expectAccessControlRevert(depositor, governorGuardian.GUARDIAN_ROLE());
        governorGuardian.pause(vaults);

        startHoax(admin);
        expectAccessControlRevert(admin, governorGuardian.GUARDIAN_ROLE());
        governorGuardian.pause(vaults);

        startHoax(guardian);
        governorGuardian.pause(vaults);
    }

    function test_GovernorGuardian_canBePaused_IfNoSetGovernorAdmin() external {
        assertEq(eTST2.governorAdmin(), address(this));
        assertEq(governorGuardian.canBePaused(address(eTST2)), false);
        skip(200);
        assertEq(governorGuardian.canBePaused(address(eTST2)), false);
    }

    function test_GovernorGuardian_canBePaused_IfSetGovernorAdmin() external {
        assertEq(eTST.governorAdmin(), address(governorGuardian));
        assertEq(governorGuardian.canBePaused(address(eTST)), false);
        skip(200);
        assertEq(governorGuardian.canBePaused(address(eTST)), true);
    }

    function test_GovernorGuardian_canBeUnpaused_IfSetGovernorAdmin() external {
        assertEq(eTST.governorAdmin(), address(governorGuardian));

        assertEq(governorGuardian.canBePaused(address(eTST)), false);

        skip(200);

        assertEq(governorGuardian.remainingPauseDuration(address(eTST)), 0);
        assertEq(governorGuardian.canBePaused(address(eTST)), true);

        startHoax(guardian);
        governorGuardian.pause(vaults);

        assertEq(governorGuardian.remainingPauseDuration(address(eTST)), 100);
        assertEq(governorGuardian.canBeUnpaused(address(eTST), true), true);
        assertEq(governorGuardian.canBeUnpaused(address(eTST), false), false);

        skip(50);
        assertEq(governorGuardian.remainingPauseDuration(address(eTST)), 50);

        skip(51);
        assertEq(governorGuardian.remainingPauseDuration(address(eTST)), 0);
        assertEq(governorGuardian.canBeUnpaused(address(eTST), true), true);
        assertEq(governorGuardian.canBeUnpaused(address(eTST), false), true);
    }

    function test_GovernorGuardian_canBeUnpaused_IfNoSetGovernorAdmin() external {
        assertEq(eTST.governorAdmin(), address(governorGuardian));
        assertEq(governorGuardian.canBePaused(address(eTST)), false);

        skip(200);

        assertEq(governorGuardian.canBePaused(address(eTST)), true);

        startHoax(guardian);
        governorGuardian.pause(vaults);

        bytes memory data = abi.encodeWithSelector(eTST.setGovernorAdmin.selector, admin);
        startHoax(admin);
        governorGuardian.adminCall(address(eTST), data);
        assertEq(eTST.governorAdmin(), admin);

        assertEq(governorGuardian.canBeUnpaused(address(eTST), true), false);
        assertEq(governorGuardian.canBeUnpaused(address(eTST), false), false);

        skip(101);

        assertEq(governorGuardian.canBeUnpaused(address(eTST), true), false);
        assertEq(governorGuardian.canBeUnpaused(address(eTST), false), false);
    }

    function test_GovernorGuardian_pauseUntilCooldown() external {
        assertEq(IEVault(vaults[0]).governorAdmin(), address(governorGuardian));

        assertEq(governorGuardian.canBePaused(vaults[0]), false);

        doDeposit(depositor, vaults[0], 1e18);
        assertEq(IEVault(vaults[0]).balanceOf(depositor), 1e18);

        startHoax(guardian);
        governorGuardian.pause(vaults);

        doDeposit(depositor, vaults[0], 1e18);
        assertEq(IEVault(vaults[0]).balanceOf(depositor), 2e18);

        skip(199);

        assertEq(governorGuardian.canBePaused(vaults[0]), false);

        startHoax(guardian);
        governorGuardian.pause(vaults);

        doDeposit(depositor, vaults[0], 1e18);
        assertEq(IEVault(vaults[0]).balanceOf(depositor), 3e18);
    }

    function test_GovernorGuardian_pauseAfterCooldown() external {
        assertEq(IEVault(vaults[0]).governorAdmin(), address(governorGuardian));

        assertEq(governorGuardian.canBePaused(vaults[0]), false);

        doDeposit(depositor, vaults[0], 1e18);
        assertEq(IEVault(vaults[0]).balanceOf(depositor), 1e18);

        startHoax(guardian);
        governorGuardian.pause(vaults);

        doDeposit(depositor, vaults[0], 1e18);
        assertEq(IEVault(vaults[0]).balanceOf(depositor), 2e18);

        skip(200);

        assertEq(governorGuardian.canBePaused(vaults[0]), true);

        startHoax(guardian);
        governorGuardian.pause(vaults);

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        doDeposit(depositor, vaults[0], 1e18);

        skip(100);

        startHoax(guardian);
        governorGuardian.unpause(vaults);

        assertEq(governorGuardian.canBePaused(vaults[0]), false);

        doDeposit(depositor, vaults[0], 1e18);
        assertEq(IEVault(vaults[0]).balanceOf(depositor), 3e18);

        skip(101);

        assertEq(governorGuardian.canBePaused(vaults[0]), true);

        startHoax(guardian);
        governorGuardian.pause(vaults);

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        doDeposit(depositor, vaults[0], 1e18);
    }

    function test_GovernorGuardian_onlyGuardianCanChangePauseStatus() external {
        expectAccessControlRevert(address(this), governorGuardian.GUARDIAN_ROLE());
        governorGuardian.changePauseStatus(vaults, OP_DEPOSIT);

        startHoax(depositor);
        expectAccessControlRevert(depositor, governorGuardian.GUARDIAN_ROLE());
        governorGuardian.changePauseStatus(vaults, OP_DEPOSIT);

        startHoax(admin);
        expectAccessControlRevert(admin, governorGuardian.GUARDIAN_ROLE());
        governorGuardian.changePauseStatus(vaults, OP_DEPOSIT);

        startHoax(guardian);
        governorGuardian.changePauseStatus(vaults, OP_DEPOSIT);
    }

    function test_GovernorGuardian_unpauseUntilDuration() external {
        assertEq(IEVault(vaults[0]).governorAdmin(), address(governorGuardian));

        skip(200);

        assertEq(governorGuardian.canBePaused(vaults[0]), true);

        startHoax(guardian);
        governorGuardian.pause(vaults);

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        doDeposit(depositor, vaults[0], 1e18);

        assertEq(governorGuardian.canBeUnpaused(vaults[0], false), false);
        assertEq(governorGuardian.canBeUnpaused(vaults[0], true), true);

        vm.stopPrank();
        governorGuardian.unpause(vaults);

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        doDeposit(depositor, vaults[0], 1e18);

        startHoax(guardian);
        governorGuardian.unpause(vaults);

        doDeposit(depositor, vaults[0], 1e18);
    }

    function test_GovernorGuardian_unpauseAfterDuration() external {
        assertEq(IEVault(vaults[0]).governorAdmin(), address(governorGuardian));

        skip(200);

        assertEq(governorGuardian.canBePaused(vaults[0]), true);

        startHoax(guardian);
        governorGuardian.pause(vaults);

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        doDeposit(depositor, vaults[0], 1e18);

        skip(102);

        assertEq(governorGuardian.canBeUnpaused(vaults[0], false), true);
        assertEq(governorGuardian.canBeUnpaused(vaults[0], true), true);

        vm.stopPrank();
        governorGuardian.unpause(vaults);

        doDeposit(depositor, vaults[0], 1e18);
    }

    function test_GovernorGuardian_changePauseStatusUntilDuration() external {
        assertEq(IEVault(vaults[0]).governorAdmin(), address(governorGuardian));

        doDeposit(depositor, vaults[0], 1e18);
        assertEq(IEVault(vaults[0]).balanceOf(depositor), 1e18);

        skip(200);

        assertEq(governorGuardian.remainingPauseDuration(vaults[0]), 0);
        assertEq(governorGuardian.canBePaused(vaults[0]), true);

        (address hook,) = IEVault(vaults[0]).hookConfig();
        assertEq(hook, address(0));

        startHoax(guardian);
        governorGuardian.pause(vaults);
        assertEq(governorGuardian.remainingPauseDuration(vaults[0]), 100);

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        doDeposit(depositor, vaults[0], 1e18);

        startHoax(guardian);
        governorGuardian.changePauseStatus(vaults, OP_WITHDRAW);
        assertEq(governorGuardian.remainingPauseDuration(vaults[0]), 100);

        doDeposit(depositor, vaults[0], 1e18);
        assertEq(IEVault(vaults[0]).balanceOf(depositor), 2e18);

        startHoax(depositor);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        IEVault(vaults[0]).withdraw(1e18, depositor, depositor);
    }

    function test_GovernorGuardian_changePauseStatusAfterDuration() external {
        assertEq(IEVault(vaults[0]).governorAdmin(), address(governorGuardian));

        doDeposit(depositor, vaults[0], 1e18);
        assertEq(IEVault(vaults[0]).balanceOf(depositor), 1e18);

        skip(200);

        assertEq(governorGuardian.canBePaused(vaults[0]), true);

        (address hook,) = IEVault(vaults[0]).hookConfig();
        assertEq(hook, address(0));

        startHoax(guardian);
        governorGuardian.pause(vaults);

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        doDeposit(depositor, vaults[0], 1e18);

        skip(101);

        startHoax(guardian);
        governorGuardian.changePauseStatus(vaults, OP_WITHDRAW);

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        doDeposit(depositor, vaults[0], 1e18);

        startHoax(depositor);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        IEVault(vaults[0]).withdraw(1e18, depositor, depositor);
    }

    function test_GovernorGuardian_changePauseStatusWithNonZeroHook() external {
        assertEq(IEVault(vaults[0]).governorAdmin(), address(governorGuardian));

        doDeposit(depositor, vaults[0], 1e18);
        assertEq(IEVault(vaults[0]).balanceOf(depositor), 1e18);

        skip(200);

        assertEq(governorGuardian.canBePaused(vaults[0]), true);

        address mockTargetHook = address(new MockTargetHook());
        bytes memory data = abi.encodeWithSelector(IEVault(vaults[0]).setHookConfig.selector, mockTargetHook, 0);

        startHoax(admin);
        governorGuardian.adminCall(vaults[0], data);
        (address hook,) = IEVault(vaults[0]).hookConfig();
        assertNotEq(hook, address(0));

        startHoax(guardian);
        governorGuardian.pause(vaults);

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        doDeposit(depositor, vaults[0], 1e18);

        startHoax(guardian);
        governorGuardian.changePauseStatus(vaults, OP_WITHDRAW);

        vm.expectRevert(Errors.E_OperationDisabled.selector);
        doDeposit(depositor, vaults[0], 1e18);

        startHoax(depositor);
        vm.expectRevert(Errors.E_OperationDisabled.selector);
        IEVault(vaults[0]).withdraw(1e18, depositor, depositor);
    }

    function test_GovernorGuardian_hookConfigCaching() external {
        skip(200);

        address mockTargetHook = address(new MockTargetHook());
        vm.prank(address(governorGuardian));
        IEVault(vaults[0]).setHookConfig(mockTargetHook, 1);
        (address hook, uint32 hooked) = IEVault(vaults[0]).hookConfig();
        assertEq(hook, mockTargetHook);
        assertEq(hooked, 1);

        startHoax(guardian);
        assertEq(governorGuardian.canBePaused(vaults[0]), true);
        governorGuardian.pause(vaults);

        (hook, hooked) = IEVault(vaults[0]).hookConfig();
        assertEq(hook, address(0));
        assertEq(hooked, OP_MAX_VALUE - 1);

        // unpausing brings back cached config
        uint256 snapshot = vm.snapshot();
        governorGuardian.unpause(vaults);

        (hook, hooked) = IEVault(vaults[0]).hookConfig();
        assertEq(hook, mockTargetHook);
        assertEq(hooked, 1);

        // pausing and unpausing again brings back cached config too
        skip(201);
        assertEq(governorGuardian.canBePaused(vaults[0]), true);
        governorGuardian.pause(vaults);

        (hook, hooked) = IEVault(vaults[0]).hookConfig();
        assertEq(hook, address(0));
        assertEq(hooked, OP_MAX_VALUE - 1);

        governorGuardian.unpause(vaults);
        (hook, hooked) = IEVault(vaults[0]).hookConfig();
        assertEq(hook, mockTargetHook);
        assertEq(hooked, 1);

        // pausing twice and unpausing brings back cached config correctly
        vm.revertTo(snapshot);
        skip(201);
        assertEq(governorGuardian.canBePaused(vaults[0]), true);
        governorGuardian.pause(vaults);

        (hook, hooked) = IEVault(vaults[0]).hookConfig();
        assertEq(hook, address(0));
        assertEq(hooked, OP_MAX_VALUE - 1);

        governorGuardian.unpause(vaults);
        (hook, hooked) = IEVault(vaults[0]).hookConfig();
        assertEq(hook, mockTargetHook);
        assertEq(hooked, 1);

        // admin config change is equivalent to unpause from the hook config caching standpoint.
        // hence, even if paused twice and unpaused, the cached config is brought back correctly
        vm.revertTo(snapshot);
        mockTargetHook = address(new MockTargetHook());
        bytes memory data = abi.encodeWithSelector(IEVault(vaults[0]).setHookConfig.selector, mockTargetHook, 2);

        startHoax(admin);
        governorGuardian.adminCall(vaults[0], data);
        assertEq(governorGuardian.remainingPauseDuration(vaults[0]), 0);
        (hook, hooked) = IEVault(vaults[0]).hookConfig();
        assertEq(hook, mockTargetHook);
        assertEq(hooked, 2);

        skip(201);
        startHoax(guardian);
        assertEq(governorGuardian.canBePaused(vaults[0]), true);
        governorGuardian.pause(vaults);

        (hook, hooked) = IEVault(vaults[0]).hookConfig();
        assertEq(hook, address(0));
        assertEq(hooked, OP_MAX_VALUE - 1);

        governorGuardian.unpause(vaults);
        (hook, hooked) = IEVault(vaults[0]).hookConfig();
        assertEq(hook, mockTargetHook);
        assertEq(hooked, 2);
    }

    function expectAccessControlRevert(address account, bytes32 role) internal {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, account, role));
    }

    function doDeposit(address account, address vault, uint256 amount) internal {
        startHoax(account);
        IEVault(vault).deposit(amount, account);
        vm.stopPrank();
    }
}
