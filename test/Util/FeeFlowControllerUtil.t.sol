// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "../../lib/euler-vault-kit/test/unit/evault/EVaultTestBase.t.sol";
import {IEVault} from "../../lib/euler-vault-kit/src/EVault/IEVault.sol";
import {FeeFlowController} from "fee-flow/FeeFlowController.sol";
import {FeeFlowControllerUtil} from "../../src/Util/FeeFlowControllerUtil.sol";
import {TestERC20} from "evk-test/mocks/TestERC20.sol";
import {IRMTestDefault} from "evk-test/mocks/IRMTestDefault.sol";

contract FeeFlowControllerUtilTest is EVaultTestBase {
    // Constants for FeeFlowController
    uint256 public constant INIT_PRICE = 1e18;
    uint256 public constant MIN_INIT_PRICE = 1e6;
    uint256 public constant EPOCH_PERIOD = 14 days;
    uint256 public constant PRICE_MULTIPLIER = 2e18;

    // Test contracts
    FeeFlowController public feeFlowController;
    FeeFlowControllerUtil public feeFlowControllerUtil;
    TestERC20 public paymentToken;

    // Test users
    address public buyer = makeAddr("buyer");
    address public assetsReceiver = makeAddr("assetsReceiver");
    address public paymentReceiver = makeAddr("paymentReceiver");

    function setUp() public override {
        super.setUp();

        // Deploy payment token
        paymentToken = new TestERC20("Payment Token", "PAY", 18, false);

        // Deploy FeeFlowController
        feeFlowController = new FeeFlowController(
            address(evc),
            INIT_PRICE,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE
        );

        // Deploy FeeFlowControllerUtil
        feeFlowControllerUtil = new FeeFlowControllerUtil(address(feeFlowController));

        // Set up oracle prices
        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(assetTST2), unitOfAccount, 1e18);

        // Set up mutual LTVs for collateralization
        eTST.setLTV(address(eTST2), 0.8e4, 0.8e4, 0);
        eTST2.setLTV(address(eTST), 0.8e4, 0.8e4, 0);

        // Set interest fees to generate fees
        eTST.setInterestFee(0.1e4); // 10% interest fee
        eTST2.setInterestFee(0.1e4);

        // Set FeeFlowController as the fee receiver so converted fees go there
        eTST.setFeeReceiver(address(feeFlowController));
        eTST2.setFeeReceiver(address(feeFlowController));

        // Mint payment tokens to buyer
        paymentToken.mint(buyer, 1000000e18);

        // Approve payment token from buyer to FeeFlowControllerUtil
        vm.startPrank(buyer);
        paymentToken.approve(address(feeFlowControllerUtil), type(uint256).max);
        vm.stopPrank();
    }

    function testConstructor() public view {
        assertEq(address(feeFlowControllerUtil.feeFlowController()), address(feeFlowController));
        assertEq(address(feeFlowControllerUtil.paymentToken()), address(paymentToken));
        assertEq(paymentToken.allowance(address(feeFlowControllerUtil), address(feeFlowController)), type(uint256).max);
    }

    function testBuy_MultipleVaults() public {
        // Set up depositors and borrowers to generate fees in multiple vaults
        address depositor1 = makeAddr("depositor1");
        address depositor2 = makeAddr("depositor2");
        address borrower1 = makeAddr("borrower1");
        address borrower2 = makeAddr("borrower2");

        // Fund depositor1 for eTST
        assetTST.mint(depositor1, 1000e18);
        vm.startPrank(depositor1);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(1000e18, depositor1);
        vm.stopPrank();

        // Fund depositor2 for eTST2
        assetTST2.mint(depositor2, 1000e18);
        vm.startPrank(depositor2);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(1000e18, depositor2);
        vm.stopPrank();

        // Fund borrower1 with collateral and borrow from eTST
        assetTST2.mint(borrower1, 1000e18);
        vm.startPrank(borrower1);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(800e18, borrower1);
        evc.enableCollateral(borrower1, address(eTST2));
        evc.enableController(borrower1, address(eTST));
        eTST.borrow(400e18, borrower1); // Reduced borrow amount
        vm.stopPrank();

        // Fund borrower2 with collateral and borrow from eTST2
        assetTST.mint(borrower2, 1000e18);
        vm.startPrank(borrower2);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(800e18, borrower2);
        evc.enableCollateral(borrower2, address(eTST));
        evc.enableController(borrower2, address(eTST2));
        eTST2.borrow(400e18, borrower2); // Reduced borrow amount
        vm.stopPrank();

        // Let time pass to accumulate fees
        skip(365 days);

        // Check that fees have accumulated
        uint256 accumulatedFees1 = eTST.accumulatedFees();
        uint256 accumulatedFees2 = eTST2.accumulatedFees();
        assertGt(accumulatedFees1, 0);
        assertGt(accumulatedFees2, 0);

        // Get current epoch info
        FeeFlowController.Slot0 memory slot0 = feeFlowController.getSlot0();
        uint256 currentPrice = feeFlowController.getPrice();

        // Prepare assets array
        address[] memory assets = new address[](2);
        assets[0] = address(eTST);
        assets[1] = address(eTST2);

        // Get initial balances
        uint256 buyerPaymentBalanceBefore = paymentToken.balanceOf(buyer);
        uint256 assetsReceiverTSTBalanceBefore = eTST.balanceOf(assetsReceiver);
        uint256 assetsReceiverTST2BalanceBefore = eTST2.balanceOf(assetsReceiver);

        // Execute buy
        vm.startPrank(buyer);
        uint256 paymentAmount = feeFlowControllerUtil.buy(
            assets, assetsReceiver, slot0.epochId, block.timestamp + 1 hours, currentPrice + 1e18
        );
        vm.stopPrank();

        // Verify payment amount
        assertEq(paymentAmount, currentPrice);

        // Verify payment token transfer
        assertEq(paymentToken.balanceOf(buyer), buyerPaymentBalanceBefore - paymentAmount);
        assertEq(paymentToken.balanceOf(paymentReceiver), paymentAmount);

        // Verify assets were transferred to receiver
        // The receiver should have received vault tokens from the FeeFlowController
        assertGt(eTST.balanceOf(assetsReceiver), assetsReceiverTSTBalanceBefore);
        assertGt(eTST2.balanceOf(assetsReceiver), assetsReceiverTST2BalanceBefore);

        // The FeeFlowController should have 0 balance after the buy operation
        // (all vault tokens should have been transferred to the buyer)
        assertEq(eTST.balanceOf(address(feeFlowController)), 0);
        assertEq(eTST2.balanceOf(address(feeFlowController)), 0);

        // Verify fees were converted in both vaults
        assertEq(eTST.accumulatedFees(), 0);
        assertEq(eTST2.accumulatedFees(), 0);
    }
}
