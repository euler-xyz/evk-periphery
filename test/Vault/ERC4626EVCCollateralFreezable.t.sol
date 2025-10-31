// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {ERC4626EVCCollateralFreezableHarness} from "./lib/VaultHarnesses.sol";
import {ERC4626EVC} from "../../src/Vault/implementation/ERC4626EVC.sol";
import {ERC4626EVCCollateralFreezable} from "../../src/Vault/implementation/ERC4626EVCCollateralFreezable.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import "forge-std/Vm.sol";

contract ERC4626EVCCollateralFreezableTest is EVaultTestBase {
    uint8 internal constant PAUSE = 2;

    ERC4626EVCCollateralFreezableHarness vault;
    address depositor;

    function setUp() public virtual override {
        super.setUp();

        vault = new ERC4626EVCCollateralFreezableHarness(
            admin, address(evc), address(permit2), address(assetTST), "Collateral TST", "cTST"
        );

        depositor = makeAddr("depositor");
        assetTST.mint(depositor, type(uint256).max);
        vm.prank(depositor);
        assetTST.approve(address(vault), type(uint256).max);
    }

    function testCollateralFreezableVault_pause() public {
        // only admin can pause
        vm.prank(depositor);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        vault.pause();

        // not a sub-account
        address sub = address(uint160(admin) ^ 1);
        vm.prank(admin);
        evc.enableCollateral(admin, makeAddr("collateral")); // register owner
        vm.prank(admin);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        evc.call(address(vault), sub, 0, abi.encodeCall(ERC4626EVCCollateralFreezable.pause, ()));

        vm.prank(admin);
        vm.expectEmit();
        emit ERC4626EVCCollateralFreezable.GovPaused();
        vault.pause();
        assertTrue(vault.isPaused());
        // indempotent
        vm.prank(admin);
        vault.pause();
        assertTrue(vault.isPaused());

        // no value transfer when paused

        vm.startPrank(depositor);
        address to = makeAddr("to");
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.deposit(3, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.deposit(1, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.mint(1, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.withdraw(1, depositor, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.redeem(1, depositor, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.transfer(depositor, 1);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.transferFrom(depositor, to, 1);

        vm.stopPrank();

        // only admin can unpause
        vm.prank(depositor);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        vault.unpause();

        // not a sub-account
        vm.prank(admin);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        evc.call(address(vault), sub, 0, abi.encodeCall(ERC4626EVCCollateralFreezable.unpause, ()));

        vm.prank(admin);
        vm.expectEmit();
        emit ERC4626EVCCollateralFreezable.GovUnpaused();
        vault.unpause();
        assertFalse(vault.isPaused());
        vm.prank(admin);
        vault.unpause();
        assertFalse(vault.isPaused());

        // value transfer is allowed after unpusing

        vm.startPrank(depositor);

        vault.deposit(3, depositor);
        vault.mint(1, depositor);
        vault.withdraw(1, depositor, depositor);
        vault.redeem(1, depositor, depositor);
        vault.transfer(to, 1);
        vault.approve(depositor, 1);
        vault.transferFrom(depositor, to, 1);
    }

    function testCollateralFreezableVault_freeze() public {
        address otherDepositor = makeAddr("otherDepositor");
        assetTST.mint(otherDepositor, type(uint256).max);
        vm.prank(otherDepositor);
        assetTST.approve(address(vault), type(uint256).max);
        vm.prank(otherDepositor);
        vault.deposit(1e18, otherDepositor);
        vm.prank(otherDepositor);
        vault.approve(depositor, type(uint256).max);

        address subAdmin = address(uint160(admin) ^ 1);
        address subDepositor = address(uint160(depositor) ^ 1);
        bytes19 depositorPrefix = _getAddressPrefix(depositor);

        vm.prank(depositor);
        evc.enableCollateral(depositor, address(1));
        // only admin can freeze an account
        vm.prank(depositor);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        vault.freeze(depositorPrefix);

        // not an admin sub-account
        vm.prank(admin);
        evc.enableCollateral(admin, makeAddr("collateral")); // register owner
        vm.prank(admin);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        evc.call(address(vault), subAdmin, 0, abi.encodeCall(ERC4626EVCCollateralFreezable.freeze, (depositorPrefix)));

        vm.prank(admin);
        vm.expectEmit();
        emit ERC4626EVCCollateralFreezable.GovFrozen(depositorPrefix);
        vault.freeze(depositorPrefix);
        assertTrue(vault.isFrozen(depositor));
        assertTrue(vault.isFrozen(subDepositor));
        // indempotent
        vm.prank(admin);
        vault.freeze(depositorPrefix);
        assertTrue(vault.isFrozen(depositor));
        assertTrue(vault.isFrozen(subDepositor));

        // no value transfer when frozen on owner account

        vm.startPrank(depositor);
        address to = makeAddr("to");

        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.deposit(3, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.mint(1, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.withdraw(1, otherDepositor, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.redeem(1, otherDepositor, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.transfer(otherDepositor, 1);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.transferFrom(depositor, to, 1);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.transferFrom(otherDepositor, depositor, 1);

        vm.startPrank(otherDepositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.withdraw(1, depositor, otherDepositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.redeem(1, depositor, otherDepositor);

        vm.stopPrank();

        // only admin can unfreeze
        vm.prank(depositor);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        vault.unfreeze(depositorPrefix);

        // not a sub-account
        vm.prank(admin);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        evc.call(address(vault), subAdmin, 0, abi.encodeCall(ERC4626EVCCollateralFreezable.unfreeze, (depositorPrefix)));

        vm.prank(admin);
        vm.expectEmit();
        emit ERC4626EVCCollateralFreezable.GovUnfrozen(depositorPrefix);
        vault.unfreeze(depositorPrefix);
        assertFalse(vault.isFrozen(depositor));
        assertFalse(vault.isFrozen(subDepositor));
        vm.prank(admin);
        assertFalse(vault.isFrozen(depositor));
        assertFalse(vault.isFrozen(subDepositor));

        // value transfer is allowed after unpusing
        vm.startPrank(depositor);

        vault.deposit(3, depositor);
        vault.mint(1, depositor);
        vault.withdraw(1, otherDepositor, depositor);
        vault.redeem(1, otherDepositor, depositor);
        vault.transfer(otherDepositor, 1);
        vault.approve(depositor, 1);
        vault.transferFrom(depositor, to, 1);
        vault.transferFrom(otherDepositor, depositor, 1);

        vm.startPrank(otherDepositor);
        vault.withdraw(1, depositor, otherDepositor);
        vault.redeem(1, depositor, otherDepositor);
    }

    function _getAddressPrefix(address account) internal pure returns (bytes19) {
        uint160 ACCOUNT_ID_OFFSET = 8;
        return bytes19(uint152(uint160(account) >> ACCOUNT_ID_OFFSET));
    }

}
