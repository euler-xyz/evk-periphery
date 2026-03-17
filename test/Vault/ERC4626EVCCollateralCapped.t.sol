// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {ERC4626EVCCollateralCappedHarness} from "./lib/VaultHarnesses.sol";
import {ERC4626EVC} from "../../src/Vault/implementation/ERC4626EVC.sol";
import {ERC4626EVCCollateralCapped} from "../../src/Vault/implementation/ERC4626EVCCollateralCapped.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {ERC4626} from "openzeppelin-contracts/token/ERC20/extensions/ERC4626.sol";
import "forge-std/Vm.sol";

contract ERC4626EVCCollateralCappedTest is EVaultTestBase {
    uint16 constant CAP_RAW = 64018; // resolves to 10e18
    uint8 internal constant REENTRANCY = 0;
    uint8 internal constant SNAPSHOT = 1;
    uint8 internal constant MAX_FEATURE_INDEX = 15;

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
        vault.mockInitializeFeature(REENTRANCY);
        vm.expectRevert(ERC4626EVCCollateralCapped.AlreadyInitialized.selector);
        vault.mockInitializeFeature(SNAPSHOT);
        vm.expectRevert(ERC4626EVCCollateralCapped.AlreadyInitialized.selector);
        vault.mockInitializeFeature(MAX_FEATURE_INDEX);

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

        // can set when already over cap
        vm.prank(depositor);
        vault.deposit(20e18, depositor);

        vm.prank(admin);
        vault.setSupplyCap(CAP_RAW);

        vm.prank(depositor);
        vm.expectRevert(ERC4626EVCCollateralCapped.SupplyCapExceeded.selector);
        vault.deposit(1, depositor);
    }

    function testCollateralCappedVault_supplyCap_noCap() public {
        // no supply cap, can deposit max uint
        vm.prank(depositor);
        vault.deposit(type(uint256).max, depositor);
        assertEq(vault.balanceOf(depositor), type(uint256).max);
    }

    function testCollateralCappedVault_supplyCap_basic() public {
        vm.prank(admin);
        vault.setSupplyCap(CAP_RAW);
        assertEq(vault.maxDeposit(depositor), 10e18);
        assertEq(vault.maxMint(depositor), 10e18);

        vm.startPrank(depositor);
        uint256 snapshot = vm.snapshotState();

        // can deposit up to cap
        vault.deposit(10e18, depositor);
        assertEq(vault.maxDeposit(depositor), 0);
        assertEq(vault.maxMint(depositor), 0);

        vm.expectRevert(ERC4626EVCCollateralCapped.SupplyCapExceeded.selector);
        vault.deposit(1, depositor);

        vm.revertTo(snapshot);
        vault.mint(10e18, depositor);
        assertEq(vault.maxDeposit(depositor), 0);
        assertEq(vault.maxMint(depositor), 0);

        vm.expectRevert(ERC4626EVCCollateralCapped.SupplyCapExceeded.selector);
        vault.mint(1, depositor);

        vm.revertTo(snapshot);
        vault.deposit(5e18, depositor);

        assertEq(vault.maxDeposit(depositor), 5e18);
        assertEq(vault.maxMint(depositor), 5e18);
    }

    function testCollateralCappedVault_supplyCap_transientlyExceedStartUnderCap() public {
        vm.prank(admin);
        vault.setSupplyCap(CAP_RAW);

        vm.startPrank(depositor);
        uint256 snapshot = vm.snapshotState();
        // deposit/mint can transiently exceed cap if followed by withdraw - starting under cap

        IEVC.BatchItem[] memory batchItems = new IEVC.BatchItem[](2);
        batchItems[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: depositor,
            value: 0,
            data: abi.encodeCall(vault.deposit, (20e18, depositor))
        });
        batchItems[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: depositor,
            value: 0,
            data: abi.encodeCall(vault.withdraw, (10e18, depositor, depositor))
        });
        evc.batch(batchItems);
        vm.expectRevert(ERC4626EVCCollateralCapped.SupplyCapExceeded.selector);
        vault.mint(1, depositor);

        vm.revertTo(snapshot);

        batchItems = new IEVC.BatchItem[](2);
        batchItems[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: depositor,
            value: 0,
            data: abi.encodeCall(vault.mint, (20e18, depositor))
        });
        batchItems[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: depositor,
            value: 0,
            data: abi.encodeCall(vault.withdraw, (10e18, depositor, depositor))
        });
        evc.batch(batchItems);
        vm.expectRevert(ERC4626EVCCollateralCapped.SupplyCapExceeded.selector);
        vault.mint(1, depositor);
    }

    function testCollateralCappedVault_supplyCap_canWithdrawWhenOverCap() public {
        // set cap when already over it
        vm.prank(depositor);
        vault.deposit(20e18, depositor);

        vm.prank(admin);
        vault.setSupplyCap(CAP_RAW);

        vm.startPrank(depositor);
        address receiver = makeAddr("receiver");
        uint256 snapshot = vm.snapshotState();

        // can always withdraw / redeem

        vault.withdraw(100, receiver, depositor);
        assertEq(vault.totalAssets(), 20e18 - 100);
        assertEq(assetTST.balanceOf(receiver), 100);

        vault.redeem(100, receiver, depositor);
        assertEq(vault.totalAssets(), 20e18 - 200);
        assertEq(assetTST.balanceOf(receiver), 200);

        // can deposit after withdrawal in a batch as long as overall supply is the same

        IEVC.BatchItem[] memory batchItems = new IEVC.BatchItem[](2);
        batchItems[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: depositor,
            value: 0,
            data: abi.encodeCall(vault.withdraw, (10e18, depositor, depositor))
        });
        batchItems[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: depositor,
            value: 0,
            data: abi.encodeCall(vault.deposit, (10e18, depositor))
        });
        evc.batch(batchItems);
        vm.expectRevert(ERC4626EVCCollateralCapped.SupplyCapExceeded.selector);
        vault.mint(1, depositor);

        vm.revertTo(snapshot);

        // ... or lower

        batchItems = new IEVC.BatchItem[](2);
        batchItems[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: depositor,
            value: 0,
            data: abi.encodeCall(vault.withdraw, (10e18, depositor, depositor))
        });
        batchItems[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: depositor,
            value: 0,
            data: abi.encodeCall(vault.deposit, (10e18 - 1, depositor))
        });
        evc.batch(batchItems);
        vm.expectRevert(ERC4626EVCCollateralCapped.SupplyCapExceeded.selector);
        vault.mint(1, depositor);

        vm.revertTo(snapshot);

        // ... but not higher

        batchItems = new IEVC.BatchItem[](2);
        batchItems[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: depositor,
            value: 0,
            data: abi.encodeCall(vault.withdraw, (10e18, depositor, depositor))
        });
        batchItems[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: depositor,
            value: 0,
            data: abi.encodeCall(vault.deposit, (10e18 + 1, depositor))
        });
        vm.expectRevert(ERC4626EVCCollateralCapped.SupplyCapExceeded.selector);
        evc.batch(batchItems);
    }

    function testCollateralCappedVault_supplyCap_transientlyIncreaseSupplyStartOverCap() public {
        // set cap when already over it
        vm.prank(depositor);
        vault.deposit(20e18, depositor);

        vm.prank(admin);
        vault.setSupplyCap(CAP_RAW);

        vm.startPrank(depositor);
        uint256 snapshot = vm.snapshotState();

        // deposit/mint can transiently increase supply when over cap, if overall the supply is lowered

        IEVC.BatchItem[] memory batchItems = new IEVC.BatchItem[](2);
        batchItems[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: depositor,
            value: 0,
            data: abi.encodeCall(vault.deposit, (10e18, depositor))
        });
        batchItems[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: depositor,
            value: 0,
            data: abi.encodeCall(vault.withdraw, (10e18 + 1, depositor, depositor))
        });
        evc.batch(batchItems);
        vm.expectRevert(ERC4626EVCCollateralCapped.SupplyCapExceeded.selector);
        vault.mint(1, depositor);

        vm.revertTo(snapshot);

        batchItems = new IEVC.BatchItem[](2);
        batchItems[0] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: depositor,
            value: 0,
            data: abi.encodeCall(vault.mint, (10e18, depositor))
        });
        batchItems[1] = IEVC.BatchItem({
            targetContract: address(vault),
            onBehalfOfAccount: depositor,
            value: 0,
            data: abi.encodeCall(vault.withdraw, (10e18 + 1, depositor, depositor))
        });
        evc.batch(batchItems);
        vm.expectRevert(ERC4626EVCCollateralCapped.SupplyCapExceeded.selector);
        vault.mint(1, depositor);
    }

    function testCollateralCappedVault_snapshotIsCleared() public {
        vm.prank(admin);
        vault.setSupplyCap(CAP_RAW);

        vm.startPrank(depositor);
        // snapshot flag is cleared after every call
        assertFalse(vault.mockIsEnabled(SNAPSHOT));
        vault.deposit(2e18, depositor);
        assertFalse(vault.mockIsEnabled(SNAPSHOT));
        vault.mint(2e18, depositor);
        assertFalse(vault.mockIsEnabled(SNAPSHOT));
        vault.withdraw(1e18, depositor, depositor);
        assertFalse(vault.mockIsEnabled(SNAPSHOT));
        vault.redeem(1e18, depositor, depositor);
        assertFalse(vault.mockIsEnabled(SNAPSHOT));
    }

    // ------ internal helpers -------

    function reenter(bytes memory call) internal {
        uint256 snapshot = vm.snapshotState();
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
