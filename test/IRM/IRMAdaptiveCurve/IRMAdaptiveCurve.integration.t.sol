// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IRMAdaptiveCurve} from "../../../src/IRM/IRMAdaptiveCurve.sol";

contract IRMAdaptiveCurveIntegrationTest is EVaultTestBase {
    int256 internal constant YEAR = int256(365.2425 days);
    int256 internal constant TARGET_UTILIZATION = 0.9e18;
    int256 internal constant INITIAL_RATE_AT_TARGET = 0.04e18 / YEAR;
    int256 internal constant MIN_RATE_AT_TARGET = 0.001e18 / YEAR;
    int256 internal constant MAX_RATE_AT_TARGET = 2.0e18 / YEAR;
    int256 internal constant CURVE_STEEPNESS = 4e18;
    int256 internal constant ADJUSTMENT_SPEED = 50e18 / YEAR;

    IRMAdaptiveCurve irm;
    address depositor;
    address borrower;

    function setUp() public virtual override {
        super.setUp();

        irm = new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );

        eTST.setInterestRateModel(address(irm));
        eTST2.setInterestRateModel(address(irm));

        depositor = makeAddr("depositor");
        borrower = makeAddr("borrower");

        assetTST.mint(depositor, 100e18);
        assetTST.mint(borrower, 100e18);
        assetTST2.mint(borrower, 100e18);

        startHoax(depositor);
        assetTST.approve(address(eTST), type(uint256).max);
        eTST.deposit(1e18, depositor);

        startHoax(borrower);
        assetTST.approve(address(eTST), type(uint256).max);
        assetTST2.approve(address(eTST2), type(uint256).max);
        eTST2.deposit(50e18, borrower);
        evc.enableCollateral(borrower, address(eTST2));

        oracle.setPrice(address(assetTST), unitOfAccount, 0.01e18);
        oracle.setPrice(address(eTST2), unitOfAccount, 0.05e18);

        startHoax(address(this));
        eTST.setLTV(address(eTST2), 0.21e4, 0.21e4, 0);
    }

    function test_BorrowInterest() public {
        startHoax(borrower);
        evc.enableController(borrower, address(eTST));

        assertEq(eTST.interestAccumulator(), 1e27);

        // Mint some extra so we can pay interest
        assetTST.mint(borrower, 0.1e18);
        skip(1);
        assertEq(eTST.interestAccumulator(), 1.000000000316887385e27);

        eTST.borrow(0.5e18, borrower);
        assertEq(eTST.debtOf(borrower), 0.5e18);

        skip(1);
        assertEq(eTST.interestAccumulator(), 1.000000000633774267100417455e27);

        // 1 block later, notice amount owed is rounded up:
        assertEq(eTST.debtOf(borrower), 0.500000000158443441e18);

        // Use max uint to actually pay off full amount:
        eTST.repay(type(uint256).max, borrower);

        assertEq(eTST.debtOf(borrower), 0);
        assertEq(eTST.debtOfExact(borrower), 0);

        assertEq(eTST.totalBorrows(), 0);
        assertEq(eTST.totalBorrowsExact(), 0);
    }
}
