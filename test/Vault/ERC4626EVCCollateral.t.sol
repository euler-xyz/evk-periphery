// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC4626EVCCollateralHarness} from "./lib/VaultHarnesses.sol";
import {ERC4626EVC} from "../../src/Vault/implementation/ERC4626EVC.sol";
import {ERC4626EVCCollateral} from "../../src/Vault/implementation/ERC4626EVCCollateral.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IAllowanceTransfer} from "../../lib/euler-vault-kit/lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import {MockController} from "./lib/MockController.sol";

contract ERC4626EVCCollateralTest is EVaultTestBase {
    ERC4626EVCCollateralHarness vault;
    address depositor;

    function setUp() public virtual override {
        super.setUp();

        vault =
            new ERC4626EVCCollateralHarness(address(evc), address(permit2), address(assetTST), "Collateral TST", "cTST");

        depositor = makeAddr("depositor");
        assetTST.mint(depositor, type(uint256).max);
        vm.prank(depositor);
        assetTST.approve(address(vault), type(uint256).max);
    }

    function testCollateralVault_dependencies() public view {
        assertEq(vault.EVC(), address(evc));
        assertEq(vault.permit2Address(), address(permit2));
    }

    function testCollateralVault_meta() public view {
        assertEq(vault.name(), "Collateral TST");
        assertEq(vault.symbol(), "cTST");
    }

    function testCollateralVault_decimals() public view {
        assertEq(vault.decimals(), 18);
    }

    function testCollateralVault_virtualAmount() public {
        vm.prank(depositor);
        vault.deposit(1e18, depositor);
        vault.mockSetTotalAssets(2e18);
        uint256 VIRTUAL_AMOUNT = 1e6;

        assertEq(vault.convertToAssets(1e18), (2e18 + VIRTUAL_AMOUNT) * 1e18 / (1e18 + VIRTUAL_AMOUNT));
        assertEq(vault.convertToShares(1e18), (1e18 + VIRTUAL_AMOUNT) * 1e18 / (2e18 + VIRTUAL_AMOUNT));
    }

    function testCollateralVault_donation() public {
        vm.prank(depositor);
        vault.deposit(1e18, depositor);
        uint256 exchangeRateBefore = vault.convertToAssets(1e18);
        assertEq(exchangeRateBefore, 1e18);
        assertEq(vault.totalAssets(), 1e18);

        vm.prank(depositor);
        assetTST.transfer(address(vault), 2e18);

        // donation doesn't influence the exchange rate
        assertEq(vault.convertToAssets(1e18), exchangeRateBefore);
        assertEq(vault.totalAssets(), 1e18);
    }

    function testCollateralVault_evcCompatible() public {
        address subAcc = address(uint160(depositor) ^ 1);
        vm.prank(depositor);
        vault.deposit(1e18, subAcc);

        address to = makeAddr("to");
        vm.prank(depositor);
        evc.call(address(vault), subAcc, 0, abi.encodeCall(IERC20.transfer, (to, 1e18)));
        assertEq(vault.balanceOf(to), 1e18);
    }

    function testCollateralVault_depositMax() public {
        address user = makeAddr("user");
        vm.prank(depositor);
        assetTST.transfer(user, 1e18);

        vm.startPrank(user);
        assetTST.approve(address(vault), type(uint256).max);
        vault.deposit(type(uint256).max, user);

        assertEq(vault.balanceOf(user), 1e18);
    }

    function testCollateralVault_redeemMax() public {
        address receiver = makeAddr("receiver");
        vm.prank(depositor);
        vault.deposit(1e18, receiver);

        vm.prank(receiver);
        vault.redeem(type(uint256).max, receiver, receiver);

        assertEq(assetTST.balanceOf(receiver), 1e18);

        // with allowance
        vm.prank(depositor);
        vault.deposit(1e18, receiver);

        address approved = makeAddr("approved");
        vm.prank(receiver);
        vault.approve(approved, type(uint256).max);

        vm.prank(approved);
        vault.redeem(type(uint256).max, approved, receiver);

        assertEq(assetTST.balanceOf(approved), 1e18);
    }

    function testCollateralVault_depositWithPermit2() public {
        vm.startPrank(depositor);
        // remove direct allowance
        assetTST.approve(address(vault), 0);

        vm.expectRevert();
        vault.deposit(1e18, depositor);
        vm.expectRevert();
        vault.mint(1e18, depositor);

        assetTST.approve(permit2, type(uint256).max);
        IAllowanceTransfer(permit2).approve(address(assetTST), address(vault), type(uint160).max, type(uint48).max);

        vault.deposit(1e18, depositor);
        assertEq(vault.balanceOf(depositor), 1e18);

        vault.mint(1e18, depositor);
        assertEq(vault.balanceOf(depositor), 2e18);
    }

    function testCollateralVault_permit2Expired() public {
        vm.startPrank(depositor);
        // remove direct allowance
        assetTST.approve(address(vault), 0);

        vm.expectRevert();
        vault.deposit(1e18, depositor);

        assetTST.approve(permit2, type(uint256).max);
        IAllowanceTransfer(permit2).approve(
            address(assetTST), address(vault), type(uint160).max, uint48(block.timestamp + 1)
        );

        skip(2);

        vm.expectRevert();
        vault.deposit(1e18, depositor);

        // deposit will fall back to token allowance if available
        assetTST.approve(address(vault), type(uint256).max);
        vault.deposit(1e18, depositor);
        assertEq(vault.balanceOf(depositor), 1e18);
    }

    function testCollateralVault_withdrawToSubaccount() public {
        vm.prank(depositor);
        vault.deposit(2e18, depositor);

        address receiver = makeAddr("receiver");
        address subAcc = address(uint160(receiver) ^ 1);

        // receiver is not known in the evc, withdrawal succeeds, but funds are lost
        vm.prank(depositor);
        vault.withdraw(1e18, subAcc, depositor);

        // register owner in evc
        vm.prank(receiver);
        evc.enableCollateral(receiver, address(1));

        vm.expectRevert(ERC4626EVC.InvalidAddress.selector);
        vm.prank(depositor);
        vault.withdraw(1e18, subAcc, depositor);

        vm.expectRevert(ERC4626EVC.InvalidAddress.selector);
        vm.prank(depositor);
        vault.redeem(1e18, subAcc, depositor);
    }

    function testCollateralVault_accountStatusChecks() public {
        MockController mockController = new MockController(address(evc));
        address secondUser = makeAddr("secondUser");

        vm.prank(secondUser);
        evc.enableController(secondUser, address(mockController));

        vm.startPrank(depositor);
        evc.enableController(depositor, address(mockController));
        // deposit/mint doesn't need to check account health
        mockController.setRevertOnCheck(true);
        vault.deposit(10e18, depositor);
        vault.mint(10e18, depositor);

        mockController.setRevertOnCheck(false);
        // functions removing balance need to check account health
        vm.expectCall(
            address(mockController), abi.encodeCall(MockController.checkAccountStatus, (depositor, new address[](0)))
        );
        vault.transfer(secondUser, 1e18);

        vault.approve(secondUser, type(uint256).max);
        vm.startPrank(secondUser);
        vm.expectCall(
            address(mockController), abi.encodeCall(MockController.checkAccountStatus, (depositor, new address[](0)))
        );
        vault.transferFrom(depositor, secondUser, 1e18);

        vm.startPrank(secondUser);
        vm.expectCall(
            address(mockController), abi.encodeCall(MockController.checkAccountStatus, (secondUser, new address[](0)))
        );
        vault.withdraw(1, secondUser, secondUser);

        vm.expectCall(
            address(mockController), abi.encodeCall(MockController.checkAccountStatus, (depositor, new address[](0)))
        );
        vault.withdraw(1, secondUser, depositor);

        vm.expectCall(
            address(mockController), abi.encodeCall(MockController.checkAccountStatus, (secondUser, new address[](0)))
        );
        vault.redeem(1, secondUser, secondUser);

        vm.expectCall(
            address(mockController), abi.encodeCall(MockController.checkAccountStatus, (depositor, new address[](0)))
        );
        vault.redeem(1, secondUser, depositor);
    }

    function testCollateralVault_zeroShares() public {
        vm.startPrank(depositor);
        vault.deposit(1, depositor);
        vault.mockSetTotalAssets(2);

        vm.expectRevert(ERC4626EVCCollateral.ZeroShares.selector);
        vault.deposit(1, depositor);

        // no-op is ok
        vault.deposit(0, depositor);
    }

    function testCollateralVault_zeroAssets() public {
        vm.startPrank(depositor);
        vault.deposit(2, depositor);
        vault.mockSetTotalAssets(1);

        vm.expectRevert(ERC4626EVCCollateral.ZeroAssets.selector);
        vault.redeem(1, depositor, depositor);

        // no-op is ok
        vault.redeem(0, depositor, depositor);
    }
}
