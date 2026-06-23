// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {EthereumVaultConnector} from "ethereum-vault-connector/EthereumVaultConnector.sol";
import {Errors} from "ethereum-vault-connector/Errors.sol";
import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";

import {MigrationHelper, IMorpho} from "../../src/Swaps/MigrationHelper.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock", "MCK") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev ERC20 that reverts on any zero-value transfer (some real tokens do). Used to prove that
///      transferBalanceFromSender short-circuits an empty pull instead of forwarding a 0-value transfer.
contract RevertOnZeroERC20 is ERC20 {
    constructor() ERC20("RevertZero", "RZ") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        require(value != 0, "zero-value transfer");
        super._update(from, to, value);
    }
}

/// @dev Mock Aave V3 pool: records the on-behalf account and (optionally) delivers the borrowed asset to msg.sender,
///      mirroring Aave's behavior of sending the borrow to the caller.
contract MockAavePool {
    address public lastOnBehalf;
    bool public immutable deliver;

    constructor(bool _deliver) {
        deliver = _deliver;
    }

    function borrow(address asset, uint256 amount, uint256, uint16, address onBehalfOf) external {
        lastOnBehalf = onBehalfOf;
        if (deliver) MockERC20(asset).mint(msg.sender, amount);
    }
}

/// @dev Mock Morpho Blue: records the on-behalf account and delivers directly to the receiver.
contract MockMorpho {
    address public lastOnBehalf;
    address public lastReceiver;

    function withdrawCollateral(IMorpho.MarketParams calldata p, uint256 assets, address onBehalf, address receiver)
        external
    {
        lastOnBehalf = onBehalf;
        lastReceiver = receiver;
        MockERC20(p.collateralToken).mint(receiver, assets);
    }

    function borrow(IMorpho.MarketParams calldata p, uint256 assets, uint256, address onBehalf, address receiver)
        external
        returns (uint256, uint256)
    {
        lastOnBehalf = onBehalf;
        lastReceiver = receiver;
        MockERC20(p.loanToken).mint(receiver, assets);
        return (assets, 0);
    }
}

contract MigrationHelperTest is Test {
    EthereumVaultConnector internal evc;
    MigrationHelper internal helper;
    MockERC20 internal token;
    MockERC20 internal collateral;

    address internal owner = makeAddr("owner");
    address internal operator = makeAddr("operator");
    address internal recipient = makeAddr("recipient");
    address internal attacker = makeAddr("attacker");

    function setUp() public {
        evc = new EthereumVaultConnector();
        // permit2 = address(0) routes transferFromSender through the standard ERC20 allowance path
        helper = new MigrationHelper(address(evc), address(0));
        token = new MockERC20();
        collateral = new MockERC20();
    }

    function _marketParams() internal view returns (IMorpho.MarketParams memory) {
        return IMorpho.MarketParams({
            loanToken: address(token),
            collateralToken: address(collateral),
            oracle: address(0),
            irm: address(0),
            lltv: 0
        });
    }

    // --- transferFromSender: source bound to _msgSender() -------------------------------------------------

    function test_transferFromSender_directCall_pullsFromCaller() public {
        token.mint(owner, 100e18);
        vm.prank(owner);
        token.approve(address(helper), type(uint256).max);

        vm.prank(owner);
        helper.transferFromSender(address(token), 60e18, recipient);

        assertEq(token.balanceOf(recipient), 60e18);
        assertEq(token.balanceOf(owner), 40e18);
    }

    function test_transferFromSender_viaEVC_bindsToOnBehalfAccount() public {
        token.mint(owner, 100e18);
        vm.prank(owner);
        token.approve(address(helper), type(uint256).max);

        vm.prank(owner);
        evc.call(
            address(helper), owner, 0, abi.encodeCall(MigrationHelper.transferFromSender, (address(token), 60e18, recipient))
        );

        assertEq(token.balanceOf(recipient), 60e18);
    }

    /// @dev Every from-sender primitive permits EVC operator context, not just this pull: an operator the owner
    ///      authorized runs the call on the owner's behalf, with `_msgSender()` — and thus the bound token source /
    ///      external-protocol on-behalf account — resolving to the owner, never the operator. Consistent with the
    ///      rest of the swap periphery. The operator-context tests for the borrow/withdraw primitives below assert
    ///      the same property for the credit-delegation / Morpho-authorization legs.
    function test_transferFromSender_allowsOperatorContext_byDesign() public {
        token.mint(owner, 100e18);
        vm.prank(owner);
        token.approve(address(helper), type(uint256).max);
        vm.prank(owner);
        evc.setAccountOperator(owner, operator, true);

        vm.prank(operator);
        evc.call(
            address(helper), owner, 0, abi.encodeCall(MigrationHelper.transferFromSender, (address(token), 60e18, recipient))
        );

        assertEq(token.balanceOf(recipient), 60e18);
    }

    // --- transferBalanceFromSender: drain-with-cap -------------------------------------------------------

    function test_transferBalanceFromSender_drainsFullBalanceUnderCap() public {
        token.mint(owner, 100e18);
        vm.prank(owner);
        token.approve(address(helper), type(uint256).max);

        // maxAmount above the live balance (off-chain read + accrual buffer): drains everything, no dust.
        vm.prank(owner);
        uint256 moved = helper.transferBalanceFromSender(address(token), 120e18, recipient);

        assertEq(moved, 100e18);
        assertEq(token.balanceOf(recipient), 100e18);
        assertEq(token.balanceOf(owner), 0);
    }

    function test_transferBalanceFromSender_capsAtMaxAmount() public {
        token.mint(owner, 100e18);
        vm.prank(owner);
        token.approve(address(helper), type(uint256).max);

        // Live balance exceeds the cap (e.g. unexpectedly large balance / oversized allowance): only maxAmount moves.
        vm.prank(owner);
        uint256 moved = helper.transferBalanceFromSender(address(token), 80e18, recipient);

        assertEq(moved, 80e18);
        assertEq(token.balanceOf(recipient), 80e18);
        assertEq(token.balanceOf(owner), 20e18);
    }

    /// @dev A zero live balance short-circuits: the function returns 0 without forwarding a 0-value transfer.
    ///      With a token that reverts on zero-value transfers, the absence of the short-circuit would revert here.
    function test_transferBalanceFromSender_zeroBalance_shortCircuits() public {
        RevertOnZeroERC20 rz = new RevertOnZeroERC20();
        vm.prank(owner);
        rz.approve(address(helper), type(uint256).max);

        vm.prank(owner);
        uint256 moved = helper.transferBalanceFromSender(address(rz), 50e18, recipient);

        assertEq(moved, 0);
        assertEq(rz.balanceOf(recipient), 0);
    }

    /// @dev Routed through the EVC, both `_msgSender()` reads (the balance read and the inner pull) resolve to
    ///      the same on-behalf account, so the full balance drains to the recipient.
    function test_transferBalanceFromSender_viaEVC_bindsToOnBehalfAccount() public {
        token.mint(owner, 100e18);
        vm.prank(owner);
        token.approve(address(helper), type(uint256).max);

        vm.prank(owner);
        evc.call(
            address(helper),
            owner,
            0,
            abi.encodeCall(MigrationHelper.transferBalanceFromSender, (address(token), 120e18, recipient))
        );

        assertEq(token.balanceOf(recipient), 100e18);
        assertEq(token.balanceOf(owner), 0);
    }

    /// @dev An EVC operator the owner authorized can drain the owner's balance on their behalf; both internal
    ///      `_msgSender()` reads still bind to the owner, not the operator.
    function test_transferBalanceFromSender_allowsOperatorContext() public {
        token.mint(owner, 100e18);
        vm.prank(owner);
        token.approve(address(helper), type(uint256).max);
        _authorizeOperator();

        vm.prank(operator);
        evc.call(
            address(helper),
            owner,
            0,
            abi.encodeCall(MigrationHelper.transferBalanceFromSender, (address(token), 120e18, recipient))
        );

        assertEq(token.balanceOf(recipient), 100e18);
        assertEq(token.balanceOf(owner), 0);
    }

    // --- aaveBorrowForSender: delta-forward + onBehalf binding -------------------------------------------

    function test_aaveBorrowForSender_forwardsBorrowDelta() public {
        MockAavePool pool = new MockAavePool(true);

        vm.prank(owner);
        helper.aaveBorrowForSender(address(pool), address(token), 10e18, recipient);

        assertEq(token.balanceOf(recipient), 10e18);
        assertEq(token.balanceOf(address(helper)), 0);
        assertEq(pool.lastOnBehalf(), owner);
    }

    /// @dev With a no-op `pool` that delivers nothing, only the (zero) delta is forwarded — a pre-existing balance
    ///      resting on the contract is never paid out. This is the audit hardening for aaveBorrowForSender.
    function test_aaveBorrowForSender_noopPool_forwardsZero_keepsPreexisting() public {
        MockAavePool noop = new MockAavePool(false);
        token.mint(address(helper), 5e18); // pre-existing dust resting on the singleton

        vm.prank(owner);
        helper.aaveBorrowForSender(address(noop), address(token), 10e18, recipient);

        assertEq(token.balanceOf(recipient), 0);
        assertEq(token.balanceOf(address(helper)), 5e18); // untouched
    }

    function test_aaveBorrowForSender_ownerViaEVC_succeeds() public {
        MockAavePool pool = new MockAavePool(true);

        vm.prank(owner);
        evc.call(
            address(helper),
            owner,
            0,
            abi.encodeCall(MigrationHelper.aaveBorrowForSender, (address(pool), address(token), 10e18, recipient))
        );

        assertEq(token.balanceOf(recipient), 10e18);
        assertEq(pool.lastOnBehalf(), owner);
    }

    // --- morpho functions: onBehalf binding -------------------------------------------------------------

    function test_morphoWithdrawCollateralForSender_bindsOnBehalfAndForwards() public {
        MockMorpho morpho = new MockMorpho();

        vm.prank(owner);
        helper.morphoWithdrawCollateralForSender(address(morpho), _marketParams(), 7e18, recipient);

        assertEq(morpho.lastOnBehalf(), owner);
        assertEq(morpho.lastReceiver(), recipient);
        assertEq(collateral.balanceOf(recipient), 7e18);
    }

    function test_morphoBorrowForSender_bindsOnBehalfAndForwards() public {
        MockMorpho morpho = new MockMorpho();

        vm.prank(owner);
        helper.morphoBorrowForSender(address(morpho), _marketParams(), 9e18, recipient);

        assertEq(morpho.lastOnBehalf(), owner);
        assertEq(morpho.lastReceiver(), recipient);
        assertEq(token.balanceOf(recipient), 9e18);
    }

    // --- operator context is permitted; on-behalf still binds to the owner ------------------------------

    function _authorizeOperator() internal {
        vm.prank(owner);
        evc.setAccountOperator(owner, operator, true);
    }

    /// @dev With plain _msgSender(), an EVC operator the owner authorized can run a migration on the
    ///      owner's behalf; the protocol-side on-behalf account still binds to the owner, not the operator.
    function test_aaveBorrowForSender_allowsOperatorContext() public {
        MockAavePool pool = new MockAavePool(true);
        _authorizeOperator();

        vm.prank(operator);
        evc.call(
            address(helper),
            owner,
            0,
            abi.encodeCall(MigrationHelper.aaveBorrowForSender, (address(pool), address(token), 10e18, recipient))
        );

        assertEq(pool.lastOnBehalf(), owner);
        assertEq(token.balanceOf(recipient), 10e18);
    }

    function test_morphoBorrowForSender_allowsOperatorContext() public {
        MockMorpho morpho = new MockMorpho();
        _authorizeOperator();

        vm.prank(operator);
        evc.call(
            address(helper),
            owner,
            0,
            abi.encodeCall(MigrationHelper.morphoBorrowForSender, (address(morpho), _marketParams(), 9e18, recipient))
        );

        assertEq(morpho.lastOnBehalf(), owner);
        assertEq(token.balanceOf(recipient), 9e18);
    }

    function test_morphoWithdrawCollateralForSender_allowsOperatorContext() public {
        MockMorpho morpho = new MockMorpho();
        _authorizeOperator();

        vm.prank(operator);
        evc.call(
            address(helper),
            owner,
            0,
            abi.encodeCall(MigrationHelper.morphoWithdrawCollateralForSender, (address(morpho), _marketParams(), 7e18, recipient))
        );

        assertEq(morpho.lastOnBehalf(), owner);
        assertEq(collateral.balanceOf(recipient), 7e18);
    }

    // --- adversarial: the binding cannot be steered to a victim ------------------------------------------
    // These lock in the core security claim: a front-runner / replayer who holds neither ownership nor an
    // operator authorization over the victim's account can never make `_msgSender()` resolve to the victim.
    // The EVC enforces it for the on-behalf path (revert), and direct calls bind to the caller's own account.

    /// @dev A standing allowance the victim granted the trusted helper cannot be redirected: routing through
    ///      the EVC with onBehalfOfAccount = victim reverts, because the attacker is neither owner nor operator.
    function test_transferFromSender_frontRunnerCannotDrainVictim_reverts() public {
        token.mint(owner, 100e18);
        vm.prank(owner);
        token.approve(address(helper), type(uint256).max);

        vm.prank(attacker);
        vm.expectRevert(Errors.EVC_NotAuthorized.selector);
        evc.call(
            address(helper),
            owner,
            0,
            abi.encodeCall(MigrationHelper.transferFromSender, (address(token), 100e18, attacker))
        );

        assertEq(token.balanceOf(owner), 100e18); // untouched
        assertEq(token.balanceOf(attacker), 0);
    }

    /// @dev Calling the helper directly resolves `_msgSender()` to the attacker, so the pull targets the
    ///      attacker's own (empty, unapproved) balance — never the victim's, who keeps every token.
    function test_transferFromSender_directCallBindsToCallerNotVictim() public {
        token.mint(owner, 100e18);
        vm.prank(owner);
        token.approve(address(helper), type(uint256).max);

        vm.prank(attacker);
        vm.expectRevert(); // attacker has neither balance nor allowance of their own
        helper.transferFromSender(address(token), 100e18, attacker);

        assertEq(token.balanceOf(owner), 100e18);
    }

    function test_aaveBorrowForSender_attackerCannotTargetVictim_reverts() public {
        MockAavePool pool = new MockAavePool(true);

        vm.prank(attacker);
        vm.expectRevert(Errors.EVC_NotAuthorized.selector);
        evc.call(
            address(helper),
            owner,
            0,
            abi.encodeCall(MigrationHelper.aaveBorrowForSender, (address(pool), address(token), 10e18, attacker))
        );
    }

    /// @dev A replayer borrowing directly binds the Aave debt to their OWN account (onBehalf = attacker); the
    ///      arbitrary `to` only ever receives the attacker's own borrow proceeds, so it is not a leak.
    function test_aaveBorrowForSender_directCallBindsToCallerNotVictim() public {
        MockAavePool pool = new MockAavePool(true);

        vm.prank(attacker);
        helper.aaveBorrowForSender(address(pool), address(token), 10e18, attacker);

        assertEq(pool.lastOnBehalf(), attacker); // never the victim
        assertEq(token.balanceOf(attacker), 10e18);
    }

    function test_morphoBorrowForSender_attackerCannotTargetVictim_reverts() public {
        MockMorpho morpho = new MockMorpho();

        vm.prank(attacker);
        vm.expectRevert(Errors.EVC_NotAuthorized.selector);
        evc.call(
            address(helper),
            owner,
            0,
            abi.encodeCall(MigrationHelper.morphoBorrowForSender, (address(morpho), _marketParams(), 9e18, attacker))
        );
    }

    function test_morphoWithdrawCollateralForSender_attackerCannotTargetVictim_reverts() public {
        MockMorpho morpho = new MockMorpho();

        vm.prank(attacker);
        vm.expectRevert(Errors.EVC_NotAuthorized.selector);
        evc.call(
            address(helper),
            owner,
            0,
            abi.encodeCall(MigrationHelper.morphoWithdrawCollateralForSender, (address(morpho), _marketParams(), 7e18, attacker))
        );
    }

    /// @dev A direct Morpho borrow binds onBehalf to the caller's own position, never the victim's.
    function test_morphoBorrowForSender_directCallBindsToCallerNotVictim() public {
        MockMorpho morpho = new MockMorpho();

        vm.prank(attacker);
        helper.morphoBorrowForSender(address(morpho), _marketParams(), 9e18, attacker);

        assertEq(morpho.lastOnBehalf(), attacker);
        assertEq(token.balanceOf(attacker), 9e18);
    }
}
