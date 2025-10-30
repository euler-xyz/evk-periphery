// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {ERC4626EVCCollateralCappedHarness} from "./lib/VaultMocks.sol";
import {ERC4626EVC} from "../../src/Vault/implementation/ERC4626EVC.sol";
import {ERC4626EVCCollateralCapped} from "../../src/Vault/implementation/ERC4626EVCCollateralCapped.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import "forge-std/Vm.sol";

contract ERC4626EVCCollateralCappedTest is EVaultTestBase {
    ERC4626EVCCollateralCappedHarness vault;
    address depositor;

    function setUp() public virtual override {
        super.setUp();

        vault = new ERC4626EVCCollateralCappedHarness(
            admin, address(evc), address(permit2), address(assetTST), "Collateral TST", "cTST"
        );

        depositor = makeAddr("depositor");
        assetTST.mint(depositor, type(uint256).max);
        vm.prank(depositor);
        assetTST.approve(address(vault), type(uint256).max);
    }

    function testCollateralCappedVault_reentrancy() public {
        reenter(abi.encodeCall(IERC20.totalSupply, ()));
        reenter(abi.encodeCall(IERC20.balanceOf, (depositor)));
        reenter(abi.encodeCall(IERC20.allowance, (depositor, makeAddr("spender"))));
        reenter(abi.encodeCall(IERC4626.totalAssets, ()));
        reenter(abi.encodeCall(IERC4626.convertToAssets, (1)));
        reenter(abi.encodeCall(IERC4626.convertToShares, (1)));
        reenter(abi.encodeCall(IERC4626.maxDeposit, (depositor)));
        reenter(abi.encodeCall(IERC4626.previewDeposit, (1)));
        reenter(abi.encodeCall(IERC4626.maxMint, (depositor)));
        reenter(abi.encodeCall(IERC4626.previewMint, (1)));
        reenter(abi.encodeCall(IERC4626.maxWithdraw, (depositor)));
        reenter(abi.encodeCall(IERC4626.previewWithdraw, (1)));
        reenter(abi.encodeCall(IERC4626.maxRedeem, (depositor)));
        reenter(abi.encodeCall(IERC4626.previewRedeem, (1)));
        reenter(abi.encodeCall(IERC4626.maxRedeem, (depositor)));

        reenter(abi.encodeCall(IERC20.transfer, (depositor, 1)));
        reenter(abi.encodeCall(IERC20.transferFrom, (depositor, makeAddr("to"), 1)));
        reenter(abi.encodeCall(IERC20.approve, (makeAddr("spender"), 1)));
        reenter(abi.encodeCall(IERC4626.deposit, (1, depositor)));
        reenter(abi.encodeCall(IERC4626.mint, (1, depositor)));
        reenter(abi.encodeCall(IERC4626.withdraw, (1, depositor, depositor)));
        reenter(abi.encodeCall(IERC4626.redeem, (1, depositor, depositor)));
    }

    function testCollateralCappedVault_callThroughEVC() public {
        expectCallThroughEVC(abi.encodeCall(IERC20.transfer, (depositor, 0)));
        expectCallThroughEVC(abi.encodeCall(IERC20.transferFrom, (depositor, makeAddr("to"), 0)));
        expectCallThroughEVC(abi.encodeCall(IERC4626.deposit, (0, depositor)));
        expectCallThroughEVC(abi.encodeCall(IERC4626.mint, (0, depositor)));
        expectCallThroughEVC(abi.encodeCall(IERC4626.withdraw, (0, depositor, depositor)));
        expectCallThroughEVC(abi.encodeCall(IERC4626.redeem, (0, depositor, depositor)));
    }

    function testCollateralCappedVault_featuresBitmap() public {
        // reinitializing features is not possible
        vm.expectRevert(ERC4626EVCCollateralCapped.AlreadyInitialized.selector);
        vault.mockInitializeFeature(0); // REENTRANCY
        vm.expectRevert(ERC4626EVCCollateralCapped.AlreadyInitialized.selector);
        vault.mockInitializeFeature(1); // SNAPHOST
        vm.expectRevert(ERC4626EVCCollateralCapped.AlreadyInitialized.selector);
        vault.mockInitializeFeature(15); // MAX_FEATURE_INDEX

        uint8 SOME_FEATURE = 2;
        vault.mockInitializeFeature(SOME_FEATURE);
        vm.expectRevert(ERC4626EVCCollateralCapped.AlreadyInitialized.selector);
        vault.mockInitializeFeature(SOME_FEATURE);

        assertTrue(!vault.mockIsEnabled(SOME_FEATURE));
        vault.mockDisableFeature(SOME_FEATURE); // no-op
        assertTrue(!vault.mockIsEnabled(SOME_FEATURE));
        vault.mockEnableFeature(SOME_FEATURE);
        assertTrue(vault.mockIsEnabled(SOME_FEATURE));
        vault.mockEnableFeature(SOME_FEATURE); // no-op
        assertTrue(vault.mockIsEnabled(SOME_FEATURE));
        vault.mockDisableFeature(SOME_FEATURE);
        assertTrue(!vault.mockIsEnabled(SOME_FEATURE));
    }

    function testCollateralCappedVault_admin() public {
        // admin set at construction
        vm.expectEmit();
        emit ERC4626EVCCollateralCapped.GovSetGovernorAdmin(admin);
        ERC4626EVCCollateralCappedHarness newVault = new ERC4626EVCCollateralCappedHarness(
            admin, address(evc), address(permit2), address(assetTST), "Collateral TST", "cTST"
        );
        assertEq(newVault.governorAdmin(), admin);

        // only admin can set new admin
        vm.prank(depositor);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        vault.setGovernorAdmin(depositor);

        // not a sub-account
        address sub = address(uint160(admin) ^ 1);
        vm.prank(admin);
        evc.enableCollateral(admin, makeAddr("collateral")); // register owner
        vm.prank(admin);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        evc.call(address(vault), sub, 0, abi.encodeCall(ERC4626EVCCollateralCapped.setGovernorAdmin, (depositor)));

        vm.prank(admin);
        vm.expectEmit();
        emit ERC4626EVCCollateralCapped.GovSetGovernorAdmin(depositor);
        vault.setGovernorAdmin(depositor);
        assertEq(vault.governorAdmin(), depositor);

        // setting existing admin is no-op
        vm.recordLogs();
        vm.prank(depositor);
        vault.setGovernorAdmin(depositor);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertEq(entries.length, 0);
        assertEq(vault.governorAdmin(), depositor);
    }

    function testCollateralCappedVault_supplyCap_setting() public {
        // only admin can set new admin
        vm.prank(depositor);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        vault.setSupplyCap(0);

        // not a sub-account
        address sub = address(uint160(admin) ^ 1);
        vm.prank(admin);
        evc.enableCollateral(admin, makeAddr("collateral")); // register owner
        vm.prank(admin);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        evc.call(address(vault), sub, 0, abi.encodeCall(ERC4626EVCCollateralCapped.setSupplyCap, (0)));

        vm.prank(admin);
        vm.expectEmit();
        emit ERC4626EVCCollateralCapped.GovSetSupplyCap(0);
        vault.setSupplyCap(0);
        assertEq(vault.supplyCap(), 0);

        // 0 supply cap resolves to unlimited cap
        assertEq(vault.supplyCapResolved(), type(uint256).max);

        // there's a limit to supply cap
        vm.prank(admin);
        vm.expectRevert(ERC4626EVCCollateralCapped.BadSupplyCap.selector);
        vault.setSupplyCap(type(uint16).max);
    }

    // ------ internal helpers -------

    function reenter(bytes memory call) internal {
        uint256 snapshot = vm.snapshot();
        assetTST.configure("transfer-from/call", abi.encode(address(vault), call));

        vm.expectRevert(ERC4626EVCCollateralCapped.Reentrancy.selector);
        vm.prank(depositor);
        vault.deposit(1e18, depositor);
        vm.revertTo(snapshot);
    }

    function expectCallThroughEVC(bytes memory call) internal {
        vm.expectCall(address(evc), 0, abi.encodeCall(IEVC.call, (address(vault), depositor, 0, call)));
        vm.prank(depositor);
        (bool success,) = address(vault).call(call);
        assertTrue(success);
    }
}
