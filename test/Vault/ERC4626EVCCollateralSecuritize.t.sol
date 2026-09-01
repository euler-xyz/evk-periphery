// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC4626} from "forge-std/interfaces/IERC4626.sol";
import {ERC4626EVC} from "../../src/Vault/implementation/ERC4626EVC.sol";
import {ERC4626EVCCollateralFreezable} from "../../src/Vault/implementation/ERC4626EVCCollateralFreezable.sol";
import {ERC4626EVCCollateralCapped} from "../../src/Vault/implementation/ERC4626EVCCollateralCapped.sol";
import {
    ERC4626EVCCollateralSecuritizeV2,
    IComplianceServiceRegulated,
    IPerspective
} from "../../src/Vault/deployed/ERC4626EVCCollateralSecuritizeV2.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {MockSecuritizeToken} from "./lib/MockSecuritizeToken.sol";
import {MockController} from "./lib/MockController.sol";
import "forge-std/Vm.sol";
import "forge-std/Test.sol";

contract AttackerController {
    IEVC internal immutable evc;

    constructor(address _evc) {
        evc = IEVC(_evc);
    }

    function checkAccountStatus(address, address[] calldata) external pure returns (bytes4) {
        return this.checkAccountStatus.selector;
    }

    function steal(address collateral, address controlledAccount, address victim, uint256 amount) external {
        evc.controlCollateral(
            collateral,
            controlledAccount,
            0,
            abi.encodeWithSignature("transferFrom(address,address,uint256)", victim, controlledAccount, amount)
        );
    }
}

contract ERC4626EVCCollateralSecuritizeV2Test is EVaultTestBase {
    MockSecuritizeToken securitizeToken;
    ERC4626EVCCollateralSecuritizeV2 vault;
    address mockComplianceService;
    address depositor;
    address liquidator;
    address mockPerspective;

    function setUp() public virtual override {
        super.setUp();

        depositor = makeAddr("depositor");
        liquidator = makeAddr("liquidator");
        mockComplianceService = makeAddr("mockComplianceService");
        mockPerspective = makeAddr("mockPerspective");
        securitizeToken = new MockSecuritizeToken(mockComplianceService);
        vault = new ERC4626EVCCollateralSecuritizeV2(
            address(evc), address(permit2), admin, mockPerspective, address(securitizeToken), "Collateral TST", "cTST"
        );

        securitizeToken.mint(depositor, type(uint256).max);
        vm.prank(depositor);
        securitizeToken.approve(address(vault), type(uint256).max);
        vm.prank(depositor);
        evc.call(address(0), depositor, 0, ""); // register on evc
    }

    function testCollateralSecuritize_pause() public {
        vm.prank(admin);
        vault.pause();

        vm.startPrank(depositor);
        address to = makeAddr("to");
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.deposit(1, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.mint(1, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.transfer(depositor, 1);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.transferFrom(depositor, to, 1);

        vm.startPrank(admin);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Paused.selector);
        vault.seize(depositor, to, 1);
    }

    function testCollateralSecuritizeVault_freeze() public {
        address otherDepositor = makeAddr("otherDepositor");
        securitizeToken.mint(otherDepositor, type(uint256).max);
        vm.startPrank(otherDepositor);
        evc.call(address(0), otherDepositor, 0, ""); // register on evc
        securitizeToken.approve(address(vault), type(uint256).max);
        vault.deposit(1e18, otherDepositor);
        vault.approve(depositor, type(uint256).max);
        vm.stopPrank();

        bytes19 depositorPrefix = _getAddressPrefix(depositor);
        vm.prank(admin);
        vault.freeze(depositorPrefix);

        vm.startPrank(depositor);
        address to = makeAddr("to");

        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.deposit(3, depositor);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.mint(1, depositor);
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
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.transfer(depositor, 1);

        vm.startPrank(admin);
        vm.expectRevert(ERC4626EVCCollateralFreezable.Frozen.selector);
        vault.seize(otherDepositor, depositor, 1);
    }

    function testCollateralSecuritizeVault_callThroughEVC() public {
        expectCallThroughEVC(abi.encodeCall(IERC20.transfer, (depositor, 0)));
        expectCallThroughEVC(abi.encodeCall(IERC20.transferFrom, (depositor, address(uint160(depositor) ^ 1), 0)));
        expectCallThroughEVC(abi.encodeCall(IERC4626.deposit, (0, depositor)));
        expectCallThroughEVC(abi.encodeCall(IERC4626.mint, (0, depositor)));

        vm.prank(liquidator);
        evc.call(address(0), liquidator, 0, ""); // register on evc
        vm.startPrank(admin);
        evc.call(address(0), admin, 0, ""); // register on evc
        vm.mockCall(
            mockComplianceService,
            0,
            abi.encodeCall(IComplianceServiceRegulated.preTransferCheck, (address(vault), liquidator, 0)),
            abi.encode(uint256(0), string(""))
        );
        bytes memory call = abi.encodeCall(ERC4626EVCCollateralSecuritizeV2.seize, (depositor, liquidator, 0));
        vm.expectCall(address(evc), 0, abi.encodeCall(IEVC.call, (address(vault), admin, 0, call)));
        (bool success,) = address(vault).call(call);
        assertTrue(success);
    }

    function testCollateralSecuritizeVault_reentrancy() public {
        reenter(abi.encodeCall(IERC20.transfer, (depositor, 1)));
        reenter(abi.encodeCall(IERC20.transferFrom, (depositor, makeAddr("to"), 1)));
        reenter(abi.encodeCall(IERC4626.deposit, (1, depositor)));
        reenter(abi.encodeCall(IERC4626.mint, (1, depositor)));
        reenter(abi.encodeCall(ERC4626EVCCollateralSecuritizeV2.seize, (depositor, liquidator, 1)));

        reenter(abi.encodeWithSignature("balanceOfAddressPrefix(bytes19)", (_getAddressPrefix(depositor))));
        reenter(abi.encodeWithSignature("balanceOfAddressPrefix(address)", (depositor)));
        reenter(abi.encodeCall(ERC4626EVCCollateralSecuritizeV2.isTransferCompliant, (depositor, 0)));
    }

    function testCollateralSecuritizeVault_supplyCap_basic() public {
        uint16 CAP_RAW = 64018; // resolves to 10e18
        vm.prank(admin);
        vault.setSupplyCap(CAP_RAW);

        vm.startPrank(depositor);
        uint256 snapshot = vm.snapshotState();

        // can deposit up to cap
        vault.deposit(10e18, depositor);
        vm.expectRevert(ERC4626EVCCollateralCapped.SupplyCapExceeded.selector);
        vault.deposit(1, depositor);

        vm.revertTo(snapshot);
        vault.mint(10e18, depositor);
        vm.expectRevert(ERC4626EVCCollateralCapped.SupplyCapExceeded.selector);
        vault.mint(1, depositor);
    }

    function testCollateralSecuritizeVault_liquidate() public {
        MockController mockController = new MockController(address(evc));
        vm.startPrank(depositor);
        // enable mock controller as a simulated borrow vault
        evc.enableController(depositor, address(mockController));
        // enable vault with secuirize asset as collateral
        evc.enableCollateral(depositor, address(vault));
        // deposit collateral
        vault.deposit(1e18, depositor);
        vm.stopPrank();

        vm.startPrank(liquidator);
        evc.call(address(0), liquidator, 0, ""); // register liquidator in EVC
        // simulate liquidation
        // The mock controller, through EVC, will enforce a transfer of collateral to the liquidator account
        // The liquidation function signature is the same as in real Euler vaults, but the mock contract will transfer
        // amount
        // of collateral equal to `repayAssets`. `minYieldBalance` is ignored.
        // https://github.com/euler-xyz/euler-vault-kit/blob/master/src/EVault/IEVault.sol#L295

        uint256 amountToSeize = 0.5e18;

        // unverified controller
        vm.mockCall(
            mockPerspective, abi.encodeCall(IPerspective.isVerified, (address(mockController))), abi.encode(false)
        );
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        mockController.liquidate(depositor, address(vault), amountToSeize, 0);
        vm.clearMockedCalls();

        // not compliant
        vm.mockCall(
            mockPerspective, abi.encodeCall(IPerspective.isVerified, (address(mockController))), abi.encode(true)
        );
        vm.mockCall(
            mockComplianceService,
            abi.encodeCall(IComplianceServiceRegulated.preTransferCheck, (address(vault), liquidator, amountToSeize)),
            abi.encode(uint256(1), string(""))
        );
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        mockController.liquidate(depositor, address(vault), amountToSeize, 0);
        vm.clearMockedCalls();

        // success finally
        vm.mockCall(
            mockPerspective, abi.encodeCall(IPerspective.isVerified, (address(mockController))), abi.encode(true)
        );
        vm.mockCall(
            mockComplianceService,
            abi.encodeCall(IComplianceServiceRegulated.preTransferCheck, (address(vault), liquidator, amountToSeize)),
            abi.encode(uint256(0), string(""))
        );
        mockController.liquidate(depositor, address(vault), amountToSeize, 0);

        // 0.5e18 of collateral vault shares are transfered to the liquidator
        assertEq(vault.balanceOf(depositor), 0.5e18);
        assertEq(vault.balanceOf(liquidator), 0.5e18);
    }

    function testCollateralSecuritizeVault_perspective() public {
        address newPerspective = makeAddr("newPerspective");
        vm.prank(depositor);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        vault.setControllerPerspective(newPerspective);

        // not an admin sub-account
        vm.startPrank(admin);
        address subAdmin = address(uint160(admin) ^ 1);
        evc.enableCollateral(admin, makeAddr("collateral")); // register owner
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        evc.call(address(vault), subAdmin, 0, abi.encodeCall(vault.setControllerPerspective, (newPerspective)));

        vm.expectEmit();
        emit ERC4626EVCCollateralSecuritizeV2.GovSetControllerPerspective(newPerspective);
        vault.setControllerPerspective(newPerspective);

        assertEq(vault.controllerPerspective(), newPerspective);
    }

    function testCollateralSecuritizeVault_controlCollateralCrossFrameStealBlocked() public {
        address victim = makeAddr("victim");
        address attacker = makeAddr("attacker");
        uint256 amount = 1e18;

        MockController victimController = new MockController(address(evc)); // genuine, perspective-verified
        AttackerController attackerController = new AttackerController(address(evc)); // attacker's own, unverified

        // Victim: real collateral position with a verified controller.
        securitizeToken.mint(victim, amount);
        vm.startPrank(victim);
        securitizeToken.approve(address(vault), type(uint256).max);
        evc.enableCollateral(victim, address(vault));
        vault.deposit(amount, victim);
        evc.enableController(victim, address(victimController));
        vm.stopPrank();

        // Attacker: only its own account + an unverified self-controller.
        vm.startPrank(attacker);
        evc.enableCollateral(attacker, address(vault));
        evc.enableController(attacker, address(attackerController));
        vm.stopPrank();

        vm.mockCall(
            mockPerspective, abi.encodeCall(IPerspective.isVerified, (address(victimController))), abi.encode(true)
        );
        vm.mockCall(
            mockPerspective, abi.encodeCall(IPerspective.isVerified, (address(attackerController))), abi.encode(false)
        );
        vm.mockCall(
            mockComplianceService,
            abi.encodeWithSelector(IComplianceServiceRegulated.preTransferCheck.selector),
            abi.encode(uint256(0), string(""))
        );

        // Victim grants an ordinary (same-owner-scoped) allowance to the attacker.
        vm.prank(victim);
        vault.approve(attacker, amount);

        // A direct cross-owner transferFrom is rejected outside a control-collateral frame.
        vm.prank(attacker);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        vault.transferFrom(victim, attacker, amount);

        // The cross-frame steal (frame opened for attacker, transferFrom source = victim) is now blocked.
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        attackerController.steal(address(vault), attacker, victim, amount);

        // Nothing moved.
        assertEq(vault.balanceOf(victim), amount);
        assertEq(vault.balanceOf(attacker), 0);
        assertEq(vault.allowance(victim, attacker), amount);
    }

    function testCollateralSecuritizeVault_redeemToUnrelatedReceiverReverts() public {
        address unrelated = makeAddr("unrelated");
        vm.startPrank(depositor);
        uint256 shares = vault.deposit(1e18, depositor);

        // Self-redemption (same EVC family) is allowed.
        vault.redeem(shares / 2, depositor, depositor);

        // Redemption whose underlying receiver is an unrelated account is blocked.
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        vault.redeem(shares / 2, unrelated, depositor);
        vm.stopPrank();
    }

    function testCollateralSecuritizeVault_withdrawToUnrelatedReceiverReverts() public {
        address unrelated = makeAddr("unrelated");
        vm.startPrank(depositor);
        vault.deposit(1e18, depositor);

        // Self-withdrawal (same EVC family) is allowed.
        vault.withdraw(1, depositor, depositor);

        // Withdrawal whose underlying receiver is an unrelated account is blocked.
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        vault.withdraw(1, unrelated, depositor);
        vm.stopPrank();
    }

    function testCollateralSecuritizeVault_liquidateThenLiquidatorRedeemsToSelf() public {
        uint256 amountToSeize = 0.5e18;
        _liquidateDepositorCollateral(amountToSeize);

        // The liquidation transfer runs in a controlCollateral frame where from == onBehalfOf == depositor
        // == _msgSender(), so the cross-owner transfer guard does not block it.
        assertEq(vault.balanceOf(depositor), 0.5e18);
        assertEq(vault.balanceOf(liquidator), amountToSeize);

        // The liquidator can redeem its seized shares to its own EVC account family.
        uint256 balanceBefore = securitizeToken.balanceOf(liquidator);
        vm.prank(liquidator);
        uint256 assets = vault.redeem(amountToSeize, liquidator, liquidator);

        assertGt(assets, 0);
        assertEq(securitizeToken.balanceOf(liquidator), balanceBefore + assets);
        assertEq(vault.balanceOf(liquidator), 0);
    }

    function testCollateralSecuritizeVault_liquidateThenRedeemToUnrelatedReceiverReverts() public {
        address unrelated = makeAddr("unrelated");
        uint256 amountToSeize = 0.5e18;
        _liquidateDepositorCollateral(amountToSeize);
        assertEq(vault.balanceOf(liquidator), amountToSeize);

        // The receiver restriction applies uniformly: the liquidator cannot redeem to an unrelated account.
        vm.prank(liquidator);
        vm.expectRevert(EVCUtil.NotAuthorized.selector);
        vault.redeem(amountToSeize, unrelated, liquidator);
    }

    function testCollateralSecuritizeVault_seizeThenRecipientRedeemsToSelf() public {
        address recipient = makeAddr("recipient");
        uint256 amount = 0.5e18;

        vm.prank(depositor);
        vault.deposit(1e18, depositor);

        vm.prank(recipient);
        evc.call(address(0), recipient, 0, ""); // register recipient in EVC
        vm.prank(admin);
        evc.call(address(0), admin, 0, ""); // register admin in EVC

        vm.mockCall(
            mockComplianceService,
            abi.encodeWithSelector(IComplianceServiceRegulated.preTransferCheck.selector),
            abi.encode(uint256(0), string(""))
        );

        // Governor seizure calls ERC4626EVCCollateral.transferFrom directly, bypassing the cross-owner
        // transfer guard, so it is unaffected by the authorization fix.
        vm.prank(admin);
        vault.seize(depositor, recipient, amount);

        assertEq(vault.balanceOf(depositor), 0.5e18);
        assertEq(vault.balanceOf(recipient), amount);

        // The seizure recipient can redeem its shares to its own EVC account family.
        uint256 balanceBefore = securitizeToken.balanceOf(recipient);
        vm.prank(recipient);
        uint256 assets = vault.redeem(amount, recipient, recipient);

        assertGt(assets, 0);
        assertEq(securitizeToken.balanceOf(recipient), balanceBefore + assets);
        assertEq(vault.balanceOf(recipient), 0);
    }

    /// @dev Sets up a collateral position for `depositor` with a perspective-verified mock controller and runs a
    /// successful liquidation that transfers `amountToSeize` of vault shares from `depositor` to `liquidator`.
    function _liquidateDepositorCollateral(uint256 amountToSeize) internal {
        MockController mockController = new MockController(address(evc));
        vm.startPrank(depositor);
        // enable mock controller as a simulated borrow vault
        evc.enableController(depositor, address(mockController));
        // enable vault with securitize asset as collateral
        evc.enableCollateral(depositor, address(vault));
        // deposit collateral
        vault.deposit(1e18, depositor);
        vm.stopPrank();

        vm.prank(liquidator);
        evc.call(address(0), liquidator, 0, ""); // register liquidator in EVC

        vm.mockCall(
            mockPerspective, abi.encodeCall(IPerspective.isVerified, (address(mockController))), abi.encode(true)
        );
        vm.mockCall(
            mockComplianceService,
            abi.encodeWithSelector(IComplianceServiceRegulated.preTransferCheck.selector),
            abi.encode(uint256(0), string(""))
        );

        // Simulate liquidation: the mock controller, through
        // evc.controlCollateral(vault, depositor, transfer(liquidator, amountToSeize)),
        // enforces a transfer of collateral shares to the liquidator account.
        vm.prank(liquidator);
        mockController.liquidate(depositor, address(vault), amountToSeize, 0);
    }

    function _getAddressPrefix(address account) internal pure returns (bytes19) {
        uint160 ACCOUNT_ID_OFFSET = 8;
        return bytes19(uint152(uint160(account) >> ACCOUNT_ID_OFFSET));
    }

    function expectCallThroughEVC(bytes memory call) internal {
        vm.expectCall(address(evc), 0, abi.encodeCall(IEVC.call, (address(vault), depositor, 0, call)));
        vm.prank(depositor);
        (bool success,) = address(vault).call(call);
        assertTrue(success);
    }

    function reenter(bytes memory call) internal {
        uint256 snapshot = vm.snapshotState();
        securitizeToken.configure("transfer-from/call", abi.encode(address(vault), call));

        vm.expectRevert(ERC4626EVCCollateralCapped.Reentrancy.selector);
        vm.prank(depositor);
        vault.deposit(1e18, depositor);
        vm.revertTo(snapshot);
    }
}
