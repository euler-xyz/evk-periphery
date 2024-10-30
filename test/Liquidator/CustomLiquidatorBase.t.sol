// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {CustomLiquidatorBase} from "../../src/Liquidator/CustomLiquidatorBase.sol";
import {IEVault, IBorrowing} from "evk/EVault/IEVault.sol";
import {IEVC} from "evc/interfaces/IEthereumVaultConnector.sol";
import {CustomLiquidatorBaseTestable} from "./CustomLiquidatorBaseTestable.sol";

contract CustomLiquidatorBaseTests is EVaultTestBase {
    CustomLiquidatorBaseTestable public customLiquidator;

    address public liquidator = makeAddr("liquidator");
    address public borrower = makeAddr("borrower");
    address public depositor = makeAddr("depositor");
    address public receiver = makeAddr("receiver");
    address public random = makeAddr("random");

    function setUp() public override {
        super.setUp();

        address[] memory customLiquidationVaults = new address[](1);
        customLiquidationVaults[0] = address(eTST);
        vm.startPrank(admin);
        customLiquidator = new CustomLiquidatorBaseTestable(address(evc), admin, customLiquidationVaults);
        vm.stopPrank();

        // Setup

        oracle.setPrice(address(assetTST), unitOfAccount, 1e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 1e18);

        eTST.setLTV(address(eTST2), 0.9e4, 0.9e4, 0);

        // Depositor

        startHoax(depositor);

        assetTST.mint(depositor, type(uint256).max);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(100e18, depositor);

        // Borrower

        startHoax(borrower);

        assetTST2.mint(borrower, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(100e18, borrower);

        evc.enableCollateral(borrower, address(eTST2));
        evc.enableController(borrower, address(eTST));
        eTST.borrow(89e18, borrower);

        // Liquidator

        startHoax(liquidator);
        // Deposit some collateral to make the liquidation possible
        assetTST2.mint(liquidator, type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(200e18, liquidator);

        evc.enableCollateral(liquidator, address(eTST2));
        evc.enableController(liquidator, address(eTST));
        // Enable the customLiquidator as a operator
        evc.setAccountOperator(liquidator, address(customLiquidator), true);

        // Make position unhealthy
        oracle.setPrice(address(eTST2), unitOfAccount, 0.8e18);
    }

    function test_passThroughLiquidation() public {
        uint256 borrowerCollateralBefore = eTST.balanceOf(borrower);
        uint256 receiverCollateralBefore = eTST.balanceOf(liquidator);
        uint256 borrowerDebtBefore = eTST2.debtOf(borrower);
        uint256 liquidatorDebtBefore = eTST2.debtOf(liquidator);

        vm.startPrank(liquidator);
        customLiquidator.liquidate(liquidator, address(eTST), borrower, address(eTST2), type(uint256).max, 0);
        vm.stopPrank();

        uint256 borrowerCollateralAfter = eTST.balanceOf(borrower);
        uint256 receiverCollateralAfter = eTST.balanceOf(receiver);
        uint256 borrowerDebtAfter = eTST2.debtOf(borrower);
        uint256 liquidatorDebtAfter = eTST2.debtOf(liquidator);

        uint256 amountCollateralSeized = borrowerCollateralBefore - borrowerCollateralAfter;
        uint256 amountDebtAbsorbed = borrowerDebtBefore - borrowerDebtAfter;

        assertEq(
            receiverCollateralAfter,
            receiverCollateralBefore + amountCollateralSeized,
            "Collateral not properly transferred to receiver"
        );
        assertEq(
            liquidatorDebtAfter, liquidatorDebtBefore + amountDebtAbsorbed, "Debt not properly absorbed by liquidator"
        );
        assertEq(evc.isControllerEnabled(address(customLiquidator), address(eTST)), false, "Controller not disabled");
    }

    function test_customLiquidation() public {
        vm.startPrank(admin);
        customLiquidator.setCustomLiquidationVault(address(eTST2), true);
        vm.stopPrank();

        uint256 borrowerCollateralBefore = eTST.balanceOf(borrower);
        uint256 receiverCollateralBefore = eTST.balanceOf(receiver);
        uint256 borrowerDebtBefore = eTST2.debtOf(borrower);
        uint256 liquidatorDebtBefore = eTST2.debtOf(liquidator);

        vm.startPrank(liquidator);
        customLiquidator.liquidate(receiver, address(eTST), borrower, address(eTST2), type(uint256).max, 0);
        vm.stopPrank();

        uint256 borrowerCollateralAfter = eTST.balanceOf(borrower);
        uint256 receiverCollateralAfter = eTST.balanceOf(receiver);
        uint256 borrowerDebtAfter = eTST2.debtOf(borrower);
        uint256 liquidatorDebtAfter = eTST2.debtOf(liquidator);

        uint256 amountCollateralSeized = borrowerCollateralBefore - borrowerCollateralAfter;
        uint256 amountDebtAbsorbed = borrowerDebtBefore - borrowerDebtAfter;

        assertEq(
            receiverCollateralAfter,
            receiverCollateralBefore + amountCollateralSeized,
            "Collateral not properly transferred to receiver"
        );
        assertEq(
            liquidatorDebtAfter, liquidatorDebtBefore + amountDebtAbsorbed, "Debt not properly absorbed by liquidator"
        );
        assertEq(evc.isControllerEnabled(address(customLiquidator), address(eTST)), false, "Controller not disabled");

        CustomLiquidatorBaseTestable.LiquidationParams memory liquidationParams =
            customLiquidator.getLiquidationParams();
        assertEq(liquidationParams.receiver, receiver, "Receiver is not the expected address");
        assertEq(liquidationParams.liability, address(eTST), "Liability is not the expected address");
        assertEq(liquidationParams.collateral, address(eTST2), "Collateral is not the expected address");
    }
}
