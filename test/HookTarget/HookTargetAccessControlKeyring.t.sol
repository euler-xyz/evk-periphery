// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.12;

import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVaultTestBase, TestERC20} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IEVault, IERC4626, IERC20} from "evk/EVault/IEVault.sol";
import {IRMTestZero} from "euler-vault-kit/test/mocks/IRMTestZero.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import "evk/EVault/shared/Constants.sol";
import {HookTargetAccessControlKeyring} from "../../src/HookTarget/HookTargetAccessControlKeyring.sol";
import "forge-std/console.sol";

contract MockKeyring {
    mapping(address => bool) public allowedAddresses;
    uint32 public constant POLICY_ID = 1;

    function setAllowed(address addr, bool allowed) external {
        allowedAddresses[addr] = allowed;
    }

    function checkCredential(address addr, uint32 policyId) external view returns (bool) {
        require(policyId == POLICY_ID, "Invalid policy ID");
        return allowedAddresses[addr];
    }
}

contract HookTargetAccessControlKeyringTest is EVaultTestBase {
    HookTargetAccessControlKeyring public hookTarget;
    MockKeyring public keyring;
    address public user1;
    address public user2;
    address public liquidator;

    error NotAuthorized();

    function setUp() public override {
        super.setUp();
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        liquidator = makeAddr("liquidator");

        keyring = new MockKeyring();
        hookTarget = new HookTargetAccessControlKeyring(
            address(evc), admin, address(factory), address(keyring), keyring.POLICY_ID()
        );

        keyring.setAllowed(user1, true);
        keyring.setAllowed(user2, true);

        startHoax(address(this));
        eTST.setHookConfig(
            address(hookTarget),
            OP_DEPOSIT | OP_MINT | OP_REDEEM | OP_WITHDRAW | OP_BORROW | OP_REPAY | OP_LIQUIDATE | OP_SKIM
                | OP_REPAY_WITH_SHARES | OP_PULL_DEBT
        );
        eTST2.setHookConfig(
            address(hookTarget),
            OP_DEPOSIT | OP_MINT | OP_REDEEM | OP_WITHDRAW | OP_BORROW | OP_REPAY | OP_LIQUIDATE | OP_SKIM
                | OP_REPAY_WITH_SHARES | OP_PULL_DEBT
        );

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(assetTST2), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 1e18);

        eTST.setLTV(address(eTST2), 0.9e4, 0.9e4, 0);
        eTST2.setLTV(address(eTST), 0.5e4, 0.5e4, 0);

        startHoax(user1);
        evc.enableCollateral(user1, address(eTST));
        evc.enableController(user1, address(eTST2));

        startHoax(user1);
        assetTST.mint(user1, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        assetTST2.mint(user1, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);

        startHoax(user2);
        assetTST.mint(user2, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        assetTST2.mint(user2, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
    }

    function swap(address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOut, address recipient) public {
        TestERC20(tokenIn).transfer(address(0), amountIn);
        TestERC20(tokenOut).mint(recipient, amountOut);
    }

    ///////////////////////////////
    /// 1. Deposit tests
    ///////////////////////////////

    function test_deposit_WithReceiverHasValidCredentials() public {
        startHoax(user1);
        eTST.deposit(1e18, user1);
        assertEq(eTST.balanceOf(user1), 1e18);
    }

    function test_deposit_WithMsgSenderAndReceiverHasValidCredentials() public {
        startHoax(user1);
        eTST.deposit(1e18, user2);
        assertEq(eTST.balanceOf(user2), 1e18);
    }

    function test_deposit_WithReceiverHasInvalidCredentials() public {
        keyring.setAllowed(user1, false);
        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST.deposit(1e18, user1);
    }

    function test_deposit_WithMsgSenderAndReceiverHasInvalidCredentials() public {
        keyring.setAllowed(user1, false);
        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST.deposit(1e18, user2);
    }

    function test_deposit_WithMsgSenderHasInvalidCredentials() public {
        keyring.setAllowed(user1, false);
        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST.deposit(1e18, user1);
    }

    ///////////////////////////////
    /// 2. Withdraw tests
    ///////////////////////////////

    function test_withdraw_WithOwnerHasValidCredentials() public {
        startHoax(user1);
        eTST.deposit(1e18, user1);
        eTST.withdraw(0.5e18, user1, user1);
        assertEq(eTST.balanceOf(user1), 0.5e18);
    }

    function test_withdraw_WithOwnerHasInvalidCredentials() public {
        startHoax(user1);
        eTST.deposit(1e18, user1);
        keyring.setAllowed(user1, false);
        vm.expectRevert(NotAuthorized.selector);
        eTST.withdraw(0.5e18, user1, user1);
    }

    function test_withdraw_WithMsgSenderHasInvalidCredentials() public {
        keyring.setAllowed(user1, false);
        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST.withdraw(0.5e18, user1, user1);
    }

    function test_withdraw_WithMsgSenderAndReceiverHasInvalidCredentials() public {
        keyring.setAllowed(user1, false);
        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST.withdraw(0.5e18, user2, user1);
    }

    ///////////////////////////////
    /// 3. Borrow tests
    ///////////////////////////////

    function test_borrow_WithReceiverHasValidCredentials() public {
        startHoax(user1);
        eTST.deposit(100e18, user1);

        startHoax(user2);
        eTST2.deposit(100e18, user2);

        startHoax(user1);
        eTST2.borrow(1e18, user1);
        assertEq(eTST2.debtOf(user1), 1e18);
    }

    function test_borrow_WithReceiverHasInvalidCredentials() public {
        startHoax(user1);
        eTST.deposit(100e18, user1);

        startHoax(user2);
        eTST2.deposit(100e18, user2);

        keyring.setAllowed(user1, false);
        vm.expectRevert(NotAuthorized.selector);
        startHoax(user1);
        eTST2.borrow(1e18, user1);
    }

    function test_borrow_WithMsgSenderHasInvalidCredentials() public {
        keyring.setAllowed(user1, false);
        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST2.borrow(1e18, user1);
    }

    function test_borrow_WithOwnerHasInvalidCredentials() public {
        keyring.setAllowed(user1, false);
        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST2.borrow(1e18, user2);
    }

    ///////////////////////////////
    /// 4. Repay tests
    ///////////////////////////////

    function test_repay_WithValidCredentials() public {
        startHoax(user2);
        eTST2.deposit(100e18, user2);
        startHoax(user1);
        eTST.deposit(100e18, user1);
        eTST2.borrow(0.5e18, user1);
        eTST2.repay(0.4e18, user1);
        assertEq(eTST2.debtOf(user1), 0.1e18);
    }

    function test_repay_WithInvalidCredentials() public {
        startHoax(user2);
        eTST2.deposit(100e18, user2);
        startHoax(user1);
        eTST.deposit(100e18, user1);
        eTST2.borrow(0.5e18, user1);
        keyring.setAllowed(user1, false);
        vm.expectRevert(NotAuthorized.selector);
        eTST2.repay(0.4e18, user1);
    }

    function test_repay_WithMsgSenderAndReceiverHasInvalidCredentials() public {
        keyring.setAllowed(user1, false);
        keyring.setAllowed(user2, false);
        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST2.repay(0.5e18, user2);
    }

    function test_repay_WithMsgSenderHasInvalidCredentials() public {
        keyring.setAllowed(user1, false);
        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST2.repay(0.5e18, user2);
    }

    function test_repay_WithOwnerHasInvalidCredentials() public {
        keyring.setAllowed(user1, false);
        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST2.repay(0.5e18, user2);
    }

    ///////////////////////////////
    /// 5. Mint tests
    ///////////////////////////////

    function test_mint_WithValidCredentials() public {
        startHoax(user1);
        eTST.mint(0.5e18, user1);
        assertEq(eTST.balanceOf(user1), 0.5e18);
    }

    function test_mint_WithInvalidCredentials() public {
        keyring.setAllowed(user1, false);
        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST.mint(0.5e18, user1);
    }

    function test_mint_WithMsgSenderHasInvalidCredentials() public {
        keyring.setAllowed(user2, false);
        startHoax(user2);
        vm.expectRevert(NotAuthorized.selector);
        eTST.mint(0.5e18, user1);
    }

    function test_mint_WithOwnerHasInvalidCredentials() public {
        keyring.setAllowed(user1, false);
        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST.mint(0.5e18, user2);
    }

    ///////////////////////////////
    /// 6. Redeem tests
    ///////////////////////////////

    function test_redeem_WithValidCredentials() public {
        startHoax(user1);
        eTST.mint(0.5e18, user1);
        eTST.redeem(0.5e18, user1, user1);
        assertEq(eTST.balanceOf(user1), 0);
    }

    function test_redeem_WithInvalidCredentials() public {
        startHoax(user1);
        eTST.deposit(1e18, user1);
        keyring.setAllowed(user1, false);
        vm.expectRevert(NotAuthorized.selector);
        eTST.redeem(0.5e18, user1, user1);
    }

    function test_redeem_WithMsgSenderHasInvalidCredentials() public {
        startHoax(user1);
        eTST.deposit(1e18, user1);
        keyring.setAllowed(user2, false);
        eTST.approve(user2, type(uint256).max);

        startHoax(user2);
        vm.expectRevert(NotAuthorized.selector);
        eTST.redeem(0.5e18, user1, user1);
    }

    function test_redeem_WithMsgSenderAndReceiverHasInvalidCredentials() public {
        startHoax(user1);
        eTST.deposit(1e18, user1);
        eTST.deposit(1e18, user2);
        keyring.setAllowed(user1, false);
        keyring.setAllowed(user2, false);

        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST.redeem(0.5e18, user2, user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST.redeem(0.5e18, user1, user2);

        startHoax(user2);
        vm.expectRevert(NotAuthorized.selector);
        eTST.redeem(0.5e18, user2, user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST.redeem(0.5e18, user1, user2);
    }

    function test_redeem_WithOwnerHasInvalidCredentials() public {
        startHoax(user1);
        eTST.deposit(1e18, user1);
        keyring.setAllowed(user1, false);
        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST.redeem(0.5e18, user2, user1);
    }

    ///////////////////////////////
    /// 7. Skim tests
    ///////////////////////////////

    function test_skim_WithValidCredentials() public {
        startHoax(user1);
        assetTST.transfer(address(eTST), 2e18);

        startHoax(user2);
        evc.enableController(user2, address(eTST));

        startHoax(user2);
        eTST.skim(0.5e18, user2);
        assertEq(eTST.balanceOf(user2), 0.5e18);
    }

    function test_skim_WithInvalidCredentials() public {
        startHoax(user1);
        assetTST.transfer(address(eTST), 2e18);

        startHoax(user2);
        evc.enableController(user2, address(eTST));

        keyring.setAllowed(user2, false);
        startHoax(user2);
        vm.expectRevert(NotAuthorized.selector);
        eTST.skim(0.5e18, user2);
    }

    function test_skim_WithMsgSenderHasInvalidCredentials() public {
        startHoax(user1);
        assetTST.transfer(address(eTST), 2e18);

        startHoax(user2);
        evc.enableController(user2, address(eTST));

        keyring.setAllowed(user2, false);
        startHoax(user2);
        vm.expectRevert(NotAuthorized.selector);
        eTST.skim(0.5e18, user1);
    }

    function test_skim_WithOwnerHasInvalidCredentials() public {
        startHoax(user1);
        assetTST.transfer(address(eTST), 2e18);

        startHoax(user2);
        evc.enableController(user2, address(eTST));

        keyring.setAllowed(user1, false);
        startHoax(user2);
        vm.expectRevert(NotAuthorized.selector);
        eTST.skim(0.5e18, user1);
    }

    ///////////////////////////////
    /// 8. repayWithShares tests
    ///////////////////////////////

    function test_repayWithShares_WithValidCredentials() public {
        startHoax(user2);
        eTST2.deposit(1e18, user2);

        startHoax(user1);
        eTST.deposit(100e18, user1);
        eTST2.borrow(0.5e18, user1);
        startHoax(user2);
        eTST2.repayWithShares(type(uint256).max, user1);
        assertEq(eTST2.debtOf(user1), 0);
    }

    function test_repayWithShares_WithInvalidCredentials() public {
        startHoax(user2);
        eTST2.deposit(1e18, user2);
        startHoax(user1);
        eTST.deposit(100e18, user1);
        eTST2.borrow(0.5e18, user1);
        keyring.setAllowed(user1, false);
        startHoax(user2);
        vm.expectRevert(NotAuthorized.selector);
        eTST2.repayWithShares(0.1e1, user1);
    }

    function test_repayWithShares_WithMsgSenderHasInvalidCredentials() public {
        startHoax(user2);
        eTST2.deposit(1e18, user2);
        startHoax(user1);
        eTST.deposit(100e18, user1);
        eTST2.borrow(0.5e18, user1);
        keyring.setAllowed(user2, false);
        startHoax(user2);
        vm.expectRevert(NotAuthorized.selector);
        eTST2.repayWithShares(0.5e18, user1);
    }

    function test_repayWithShares_WithOwnerHasInvalidCredentials() public {
        startHoax(user2);
        eTST2.deposit(1e18, user2);
        startHoax(user1);
        eTST.deposit(100e18, user1);
        eTST2.borrow(0.5e18, user1);
        keyring.setAllowed(user1, false);
        startHoax(user2);
        vm.expectRevert(NotAuthorized.selector);
        eTST2.repayWithShares(0.5e18, user1);
    }

    function test_repayWithShares_WithMsgSenderAndReceiverHasInvalidCredentials() public {
        startHoax(user2);
        eTST2.deposit(1e18, user2);

        startHoax(user1);
        eTST.deposit(100e18, user1);
        eTST2.borrow(0.5e18, user1);
        keyring.setAllowed(user1, false);
        keyring.setAllowed(user2, false);

        startHoax(user2);
        vm.expectRevert(NotAuthorized.selector);
        eTST2.repayWithShares(0.5e18, user2);
    }

    ///////////////////////////////
    /// 9. pullDebt tests
    ///////////////////////////////

    function test_pullDebt_WithValidCredentials() public {
        startHoax(user2);
        eTST2.deposit(100e18, user2);
        eTST.deposit(100e18, user2);
        startHoax(user1);
        eTST.deposit(100e18, user1);
        eTST2.borrow(0.5e18, user1);

        startHoax(user2);
        evc.enableController(user2, address(eTST2));
        evc.enableCollateral(user2, address(eTST));
        eTST2.pullDebt(type(uint256).max, user1);

        assertEq(eTST2.debtOf(user1), 0);
        assertEq(eTST2.debtOf(user2), 0.5e18);
    }

    function test_pullDebt_WithInvalidCredentials() public {
        startHoax(user2);
        eTST2.deposit(100e18, user2);
        eTST.deposit(100e18, user2);
        startHoax(user1);
        eTST.deposit(100e18, user1);
        eTST2.borrow(0.5e18, user1);
        keyring.setAllowed(user1, false);
        startHoax(user2);
        evc.enableController(user2, address(eTST2));
        evc.enableCollateral(user2, address(eTST));
        vm.expectRevert(NotAuthorized.selector);
        eTST2.pullDebt(type(uint256).max, user1);
    }

    ///////////////////////////////
    /// 10. liquidation tests
    ///////////////////////////////

    function _buildLiquidationBatch() internal returns (IEVC.BatchItem[] memory) {
        startHoax(address(this));
        oracle.setPrice(address(eTST), unitOfAccount, 5e17);

        startHoax(liquidator);
        IEVC.BatchItem[] memory batchItems = new IEVC.BatchItem[](9);
        batchItems[0] = IEVC.BatchItem({
            targetContract: address(evc),
            onBehalfOfAccount: address(0),
            value: 0,
            data: abi.encodeCall(IEVC.enableCollateral, (liquidator, address(eTST)))
        });
        batchItems[1] = IEVC.BatchItem({
            targetContract: address(evc),
            onBehalfOfAccount: address(0),
            value: 0,
            data: abi.encodeCall(IEVC.enableController, (liquidator, address(eTST2)))
        });
        batchItems[2] = IEVC.BatchItem({
            targetContract: address(eTST2),
            onBehalfOfAccount: liquidator,
            value: 0,
            data: abi.encodeCall(eTST2.liquidate, (user1, address(eTST), type(uint256).max, 0))
        });
        batchItems[3] = IEVC.BatchItem({
            targetContract: address(eTST),
            onBehalfOfAccount: liquidator,
            value: 0,
            data: abi.encodeCall(eTST.redeem, (type(uint256).max, address(this), liquidator))
        });
        batchItems[4] = IEVC.BatchItem({
            targetContract: address(this),
            onBehalfOfAccount: liquidator,
            value: 0,
            data: abi.encodeCall(this.swap, (address(assetTST), 10e18, address(assetTST2), 4e18, address(eTST2)))
        });
        batchItems[5] = IEVC.BatchItem({
            targetContract: address(eTST2),
            onBehalfOfAccount: liquidator,
            value: 0,
            data: abi.encodeCall(eTST2.skim, (type(uint256).max, liquidator))
        });
        batchItems[6] = IEVC.BatchItem({
            targetContract: address(eTST2),
            onBehalfOfAccount: liquidator,
            value: 0,
            data: abi.encodeCall(eTST2.repayWithShares, (type(uint256).max, liquidator))
        });
        batchItems[7] = IEVC.BatchItem({
            targetContract: address(eTST2),
            onBehalfOfAccount: liquidator,
            value: 0,
            data: abi.encodeCall(eTST2.disableController, ())
        });
        batchItems[8] = IEVC.BatchItem({
            targetContract: address(evc),
            onBehalfOfAccount: address(0),
            value: 0,
            data: abi.encodeCall(IEVC.disableCollateral, (liquidator, address(eTST)))
        });

        return batchItems;
    }

    function test_liquidate_WithLiquidatorHasWildCardPermissions() public {
        startHoax(user2);
        eTST2.deposit(100e18, user2);
        startHoax(user1);
        eTST.deposit(10e18, user1);
        eTST2.borrow(4e18, user1);
        assertEq(eTST2.debtOf(user1), 4e18);
        startHoax(admin);
        hookTarget.grantRole(hookTarget.WILD_CARD(), liquidator);
        IEVC.BatchItem[] memory batchItems = _buildLiquidationBatch();
        evc.batch(batchItems);
        assertEq(eTST2.debtOf(user1), 0);
        assertEq(eTST2.debtOf(liquidator), 0);
    }

    function test_liquidate_WithLiquidatorWithoutWildCardPermissions() public {
        startHoax(user2);
        eTST2.deposit(100e18, user2);
        startHoax(user1);
        eTST.deposit(10e18, user1);
        eTST2.borrow(4e18, user1);
        assertEq(eTST2.debtOf(user1), 4e18);
        IEVC.BatchItem[] memory batchItems = _buildLiquidationBatch();
        vm.expectRevert(NotAuthorized.selector);
        evc.batch(batchItems);
    }

    function test_liquidate_WithLiquidatorHasWildCardPermissionsButUserNotPermitted() public {
        startHoax(user2);
        eTST2.deposit(100e18, user2);
        startHoax(user1);
        eTST.deposit(10e18, user1);
        eTST2.borrow(4e18, user1);
        assertEq(eTST2.debtOf(user1), 4e18);
        keyring.setAllowed(user1, false);
        keyring.setAllowed(user2, false);
        startHoax(admin);
        hookTarget.grantRole(hookTarget.WILD_CARD(), liquidator);
        IEVC.BatchItem[] memory batchItems = _buildLiquidationBatch();
        evc.batch(batchItems);
        assertEq(eTST2.debtOf(user1), 0);
        assertEq(eTST2.debtOf(liquidator), 0);
    }

    function test_liquidate_WithLiquidatorIsKeyringPermitted() public {
        startHoax(user2);
        eTST2.deposit(100e18, user2);
        startHoax(user1);
        eTST.deposit(10e18, user1);
        eTST2.borrow(4e18, user1);
        assertEq(eTST2.debtOf(user1), 4e18);
        keyring.setAllowed(liquidator, true);
        IEVC.BatchItem[] memory batchItems = _buildLiquidationBatch();
        vm.expectRevert(NotAuthorized.selector);
        evc.batch(batchItems);
    }

    ///////////////////////////////
    /// 11. Privileged Account Role tests
    ///////////////////////////////

    function test_privilegedAccount_CanOperateOnOtherAccounts() public {
        // Setup: user1 is privileged but has no credentials
        startHoax(admin);
        hookTarget.grantRole(hookTarget.PRIVILEGED_ACCOUNT_ROLE(), user1);
        keyring.setAllowed(user1, false);
        keyring.setAllowed(user2, true);

        // user1 can deposit to user2's account
        startHoax(user1);
        eTST.deposit(1e18, user2);
        assertEq(eTST.balanceOf(user2), 1e18);

        // user1 can withdraw from user2's account after approval
        startHoax(user2);
        eTST.approve(user1, type(uint256).max);
        startHoax(user1);
        eTST.withdraw(0.5e18, user1, user2);
        assertEq(eTST.balanceOf(user2), 0.5e18);
    }

    function test_privilegedAccount_CannotOperateOnOwnAccount() public {
        // Setup: user1 is privileged but has no credentials
        startHoax(admin);
        hookTarget.grantRole(hookTarget.PRIVILEGED_ACCOUNT_ROLE(), user1);
        keyring.setAllowed(user1, false);

        // user1 cannot deposit to their own account
        startHoax(user1);
        vm.expectRevert(NotAuthorized.selector);
        eTST.deposit(1e18, user1);

        // user1 cannot withdraw from their own account
        vm.expectRevert(NotAuthorized.selector);
        eTST.withdraw(1e18, user1, user1);
    }

    function test_privilegedAccount_WithPrivilegedReceiver() public {
        // Setup: both user1 and user2 are privileged but have no credentials
        startHoax(admin);
        hookTarget.grantRole(hookTarget.PRIVILEGED_ACCOUNT_ROLE(), user1);
        hookTarget.grantRole(hookTarget.PRIVILEGED_ACCOUNT_ROLE(), user2);
        keyring.setAllowed(user1, false);
        keyring.setAllowed(user2, false);

        // user1 can deposit to user2's account
        startHoax(user1);
        eTST.deposit(1e18, user2);
        assertEq(eTST.balanceOf(user2), 1e18);

        // Transfer shares from user2 to user1
        startHoax(user2);
        eTST.transfer(user1, 0.5e18);
        assertEq(eTST.balanceOf(user1), 0.5e18);

        // user2 can withdraw from user1's account after approval
        startHoax(user1);
        eTST.approve(user2, type(uint256).max);
        startHoax(user2);
        eTST.withdraw(0.5e18, user2, user1);
        assertEq(eTST.balanceOf(user1), 0);
    }

    function test_privilegedAccount_WithCredentials() public {
        // Setup: user1 is privileged and has credentials
        startHoax(admin);
        hookTarget.grantRole(hookTarget.PRIVILEGED_ACCOUNT_ROLE(), user1);
        keyring.setAllowed(user1, true);

        // user1 can deposit to their own account (because they have credentials)
        startHoax(user1);
        eTST.deposit(1e18, user1);
        assertEq(eTST.balanceOf(user1), 1e18);

        // user1 can withdraw from their own account (because they have credentials)
        eTST.withdraw(0.5e18, user1, user1);
        assertEq(eTST.balanceOf(user1), 0.5e18);
    }
}
