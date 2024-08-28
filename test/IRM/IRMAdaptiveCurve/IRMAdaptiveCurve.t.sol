// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {IIRM} from "evk/InterestRateModels/IIRM.sol";
import {IRMAdaptiveCurve} from "../../../src/IRM/IRMAdaptiveCurve.sol";

contract IRMAdaptiveCurveTest is Test {
    address internal constant VAULT = address(0x1234);
    int256 internal constant YEAR = int256(365.2425 days);
    int256 internal constant WAD = 1e18;
    int256 internal constant TARGET_UTILIZATION = 0.9e18;
    int256 internal constant INITIAL_RATE_AT_TARGET = 0.04e18 / YEAR;
    int256 internal constant MIN_RATE_AT_TARGET = 0.001e18 / YEAR;
    int256 internal constant MAX_RATE_AT_TARGET = 2.0e18 / YEAR;
    int256 internal constant CURVE_STEEPNESS = 4e18;
    int256 internal constant ADJUSTMENT_SPEED = 50e18 / YEAR;

    IRMAdaptiveCurve irm;

    function test_Validation_TargetUtilization(int256 targetUtilization) public {
        vm.expectRevert(IRMAdaptiveCurve.InvalidParams.selector);
        new IRMAdaptiveCurve(
            bound(targetUtilization, type(int256).min, -1),
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );

        vm.expectRevert(IRMAdaptiveCurve.InvalidParams.selector);
        new IRMAdaptiveCurve(
            bound(targetUtilization, 1e18 + 1, type(int256).max),
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );
    }

    function test_Validation_InitialRateAtTarget(int256 initialRateAtTarget) public {
        vm.expectRevert(IRMAdaptiveCurve.InvalidParams.selector);
        new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            bound(initialRateAtTarget, type(int256).min, MIN_RATE_AT_TARGET - 1),
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );

        vm.expectRevert(IRMAdaptiveCurve.InvalidParams.selector);
        new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            bound(initialRateAtTarget, MAX_RATE_AT_TARGET + 1, type(int256).max),
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );
    }

    function test_Validation_MinRateAtTarget(int256 minRateAtTarget) public {
        vm.expectRevert(IRMAdaptiveCurve.InvalidParams.selector);
        new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            bound(minRateAtTarget, type(int256).min, 0.001e18 / YEAR - 1),
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );

        vm.expectRevert(IRMAdaptiveCurve.InvalidParams.selector);
        new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            bound(minRateAtTarget, 10e18 / YEAR + 1, type(int256).max),
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );
    }

    function test_Validation_MaxRateAtTarget(int256 maxRateAtTarget) public {
        vm.expectRevert(IRMAdaptiveCurve.InvalidParams.selector);
        new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            bound(maxRateAtTarget, type(int256).min, 0.001e18 / YEAR - 1),
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );

        vm.expectRevert(IRMAdaptiveCurve.InvalidParams.selector);
        new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            bound(maxRateAtTarget, 10e18 / YEAR + 1, type(int256).max),
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );
    }

    function test_Validation_RateAtTarget_Inequality(int256 minRateAtTarget) public {
        vm.expectRevert(IRMAdaptiveCurve.InvalidParams.selector);
        new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            bound(minRateAtTarget, MAX_RATE_AT_TARGET + 1, type(int256).max),
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );
    }

    function test_Validation_CurveSteepness(int256 curveSteepness) public {
        vm.expectRevert(IRMAdaptiveCurve.InvalidParams.selector);
        new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            bound(curveSteepness, type(int256).min, 1.01e18 - 1),
            ADJUSTMENT_SPEED
        );

        vm.expectRevert(IRMAdaptiveCurve.InvalidParams.selector);
        new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            bound(curveSteepness, 100e18 + 1, type(int256).max),
            ADJUSTMENT_SPEED
        );
    }

    function test_Validation_AdjustmentSpeed(int256 adjustmentSpeed) public {
        vm.expectRevert(IRMAdaptiveCurve.InvalidParams.selector);
        new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            bound(adjustmentSpeed, type(int256).min, 2e18 / YEAR - 1)
        );

        vm.expectRevert(IRMAdaptiveCurve.InvalidParams.selector);
        new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            bound(adjustmentSpeed, 1000e18 / YEAR + 1, type(int256).max)
        );
    }

    function test_OnlyVaultCanMutateIRMState() public {
        irm = new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );

        vm.expectRevert(IIRM.E_IRMUpdateUnauthorized.selector);
        irm.computeInterestRate(VAULT, 5, 6);

        vm.prank(VAULT);
        irm.computeInterestRate(VAULT, 5, 6);
    }

    function test_IRMCalculations() public {
        irm = new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );
        vm.startPrank(VAULT);

        // First call returns `INITIAL_RATE_AT_TARGET.
        uint256 rate1 = computeRateAtUtilization(0.9e18);
        assertEq(rate1, uint256(INITIAL_RATE_AT_TARGET) * 1e9);

        // Utilization remains at `TARGET_UTILIZATION` so the rate remains at `INITIAL_RATE_AT_TARGET`.
        skip(1 minutes);
        uint256 rate2 = computeRateAtUtilization(0.9e18);
        assertEq(rate2, uint256(INITIAL_RATE_AT_TARGET) * 1e9);
        skip(365 days);
        uint256 rate3 = computeRateAtUtilization(0.9e18);
        assertEq(rate3, uint256(INITIAL_RATE_AT_TARGET) * 1e9);

        // Utilization climbs to 100% without time delay. The next rate is 4x larger than initial.
        uint256 rate4 = computeRateAtUtilization(1e18);
        assertEq(rate4, uint256(INITIAL_RATE_AT_TARGET) * 1e9);

        // Utilization goes down to 0% without time delay. The next rate is 4x smaller than initial.
        uint256 rate5 = computeRateAtUtilization(0);
        assertEq(rate5, uint256(CURVE_STEEPNESS * INITIAL_RATE_AT_TARGET / 1e18) * 1e9);

        // Utilization goes back to 90% without time delay. The next rate is back at initial.
        uint256 rate6 = computeRateAtUtilization(0.9e18);
        assertEq(rate6, uint256(1e18 * INITIAL_RATE_AT_TARGET / CURVE_STEEPNESS) * 1e9);
        // assertEq(rate6, uint256(INITIAL_RATE_AT_TARGET) * 1e9);

        // Utilization climbs to 100% after 1 day.
        // The next rate is 4x larger than initial + the whole curve has adjusted up.
        skip(1 days);
        uint256 rate7 = computeRateAtUtilization(1e18);
        assertEq(rate7, uint256(INITIAL_RATE_AT_TARGET) * 1e9);

        skip(1 days);
        uint256 rate8 = computeRateAtUtilization(0.9e18);
        assertGt(rate8, uint256(CURVE_STEEPNESS * INITIAL_RATE_AT_TARGET / 1e18) * 1e9);

        // Utilization goes back to 90%. The next rate is back at initial + adjustment factor.
        skip(1 days);
        uint256 rate9 = computeRateAtUtilization(0.9e18);

        skip(1 days);
        computeRateAtUtilization(0.9e18);
        assertGt(rate9, uint256(INITIAL_RATE_AT_TARGET) * 1e9);
    }

    function computeRateAtUtilization(uint256 utilizationRate) internal returns (uint256) {
        if (utilizationRate == 0) return irm.computeInterestRate(VAULT, 0, 0);
        if (utilizationRate == 1e18) return irm.computeInterestRate(VAULT, 0, 1e18);

        uint256 borrows = 1e18 * utilizationRate / (1e18 - utilizationRate);
        return irm.computeInterestRate(VAULT, 1e18, borrows);
    }
}
