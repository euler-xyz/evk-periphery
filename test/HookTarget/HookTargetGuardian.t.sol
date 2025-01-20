// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVault, IERC4626, IERC20} from "evk/EVault/IEVault.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import {HookTargetGuardian} from "../../src/HookTarget/HookTargetGuardian.sol";
import "evk/EVault/shared/Constants.sol";

contract HookTargetGuardianTests is EVaultTestBase {
    HookTargetGuardian hookTarget;
    address guardian;
    address depositor;

    function setUp() public virtual override {
        super.setUp();
        guardian = makeAddr("guardian");
        depositor = makeAddr("depositor");
        hookTarget = new HookTargetGuardian(admin, 100, 200);

        startHoax(admin);
        hookTarget.grantRole(hookTarget.GUARDIAN_ROLE(), guardian);

        startHoax(address(this));
        eTST.setHookConfig(address(hookTarget), OP_DEPOSIT);

        startHoax(depositor);

        assetTST.mint(depositor, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);

        assetTST2.mint(depositor, type(uint256).max);
        assetTST2.approve(address(eTST), type(uint256).max);

        vm.stopPrank();
    }

    function test_HookTargetGuardian_addGuardians() external {
        address guardian2 = makeAddr("guardian2");

        startHoax(guardian2);
        expectAccessControlRevert(guardian2, hookTarget.GUARDIAN_ROLE());
        hookTarget.pause();

        startHoax(admin);
        hookTarget.grantRole(hookTarget.GUARDIAN_ROLE(), guardian2);

        startHoax(guardian2);
        hookTarget.pause();
    }

    function test_HookTargetGuardian_onlyGuardianCanPause() external {
        expectAccessControlRevert(address(this), hookTarget.GUARDIAN_ROLE());
        hookTarget.pause();

        startHoax(depositor);
        expectAccessControlRevert(depositor, hookTarget.GUARDIAN_ROLE());
        hookTarget.pause();

        startHoax(admin);
        expectAccessControlRevert(admin, hookTarget.GUARDIAN_ROLE());
        hookTarget.pause();

        startHoax(guardian);
        hookTarget.pause();
    }

    function test_HookTargetGuardian_onlyGuardianCanUnpause() external {
        expectAccessControlRevert(address(this), hookTarget.GUARDIAN_ROLE());
        hookTarget.unpause();

        startHoax(depositor);
        expectAccessControlRevert(depositor, hookTarget.GUARDIAN_ROLE());
        hookTarget.unpause();

        startHoax(admin);
        expectAccessControlRevert(admin, hookTarget.GUARDIAN_ROLE());
        hookTarget.unpause();

        startHoax(guardian);
        hookTarget.unpause();
    }

    function test_HookTargetGuardian_pauseAndUnpause() external {
        startHoax(depositor);
        eTST.deposit(1e18, depositor);
        assertEq(eTST.balanceOf(depositor), 1e18);

        assertEq(hookTarget.remainingPauseDuration(), 0);
        assertEq(hookTarget.isPaused(), false);
        assertEq(hookTarget.canBePaused(), false);

        skip(200);

        assertEq(hookTarget.remainingPauseDuration(), 0);
        assertEq(hookTarget.isPaused(), false);
        assertEq(hookTarget.canBePaused(), true);

        startHoax(guardian);
        hookTarget.pause();

        assertEq(hookTarget.remainingPauseDuration(), 100);
        assertEq(hookTarget.isPaused(), true);
        assertEq(hookTarget.canBePaused(), false);

        startHoax(depositor);
        vm.expectRevert(HookTargetGuardian.HTG_VaultPaused.selector);
        eTST.deposit(1e18, depositor);

        uint256 snapshot = vm.snapshot();

        //unpause by call function
        startHoax(guardian);
        hookTarget.unpause();

        startHoax(depositor);
        eTST.deposit(1e18, depositor);
        assertEq(eTST.balanceOf(depositor), 2e18);

        assertEq(hookTarget.remainingPauseDuration(), 0);
        assertEq(hookTarget.isPaused(), false);
        assertEq(hookTarget.canBePaused(), false);

        skip(201);

        assertEq(hookTarget.remainingPauseDuration(), 0);
        assertEq(hookTarget.isPaused(), false);
        assertEq(hookTarget.canBePaused(), true);

        vm.revertTo(snapshot);

        //unpause by time
        assertEq(hookTarget.remainingPauseDuration(), 100);

        skip(50);

        assertEq(hookTarget.remainingPauseDuration(), 50);

        skip(51);

        assertEq(hookTarget.remainingPauseDuration(), 0);

        startHoax(depositor);
        eTST.deposit(1e18, depositor);
        assertEq(eTST.balanceOf(depositor), 2e18);

        assertEq(hookTarget.remainingPauseDuration(), 0);
        assertEq(hookTarget.isPaused(), false);
        assertEq(hookTarget.canBePaused(), false);

        skip(100);

        assertEq(hookTarget.remainingPauseDuration(), 0);
        assertEq(hookTarget.isPaused(), false);
        assertEq(hookTarget.canBePaused(), true);
    }

    function expectAccessControlRevert(address account, bytes32 role) internal {
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, account, role));
    }
}
