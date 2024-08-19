// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IIRM} from "evk/InterestRateModels/IIRM.sol";
import {IRMAdaptiveRange} from "../../../src/IRM/IRMAdaptiveRange.sol";

contract IRMAdaptiveRangeTest is Test {
    address constant VAULT = address(0x1234);
    uint256 internal constant SECONDS_PER_YEAR = 365 days;
    uint256 internal constant targetUtilizationLower = 0.7e18;
    uint256 internal constant targetUtilizationUpper = 0.9e18;
    uint256 internal constant kink = 0.8e18;
    uint256 internal constant baseRate = 0.01e18 / SECONDS_PER_YEAR;
    uint256 internal constant minFullRate = 100e18 / SECONDS_PER_YEAR;
    uint256 internal constant maxFullRate = 1000e18 / SECONDS_PER_YEAR;
    uint256 internal constant initialFullRate = 200e18 / SECONDS_PER_YEAR;
    uint256 internal constant halfLife = 6 hours;
    uint256 internal constant kinkRatePercent = 0.9e18;

    IRMAdaptiveRange irm;

    function setUp() public {
        irm = new IRMAdaptiveRange(
            targetUtilizationLower,
            targetUtilizationUpper,
            kink,
            baseRate,
            minFullRate,
            maxFullRate,
            initialFullRate,
            halfLife,
            kinkRatePercent
        );
        vm.startPrank(VAULT);
    }

    function test_OnlyVaultCanMutateIRMState() public {
        irm.computeInterestRate(VAULT, 5, 6);

        vm.expectRevert(IIRM.E_IRMUpdateUnauthorized.selector);
        vm.startPrank(address(0x2345));
        irm.computeInterestRate(VAULT, 5, 6);
    }

    function test_IRMCalculation() public {
        // First call initializes the IRM with `initialFullRate`.
        (uint256 rate1, uint256 fullRate1) = computeRateAtUtilization(0.8e18);
        assertEq(fullRate1, initialFullRate);
        assertEq(rate1, 5707794266868);
        computeRateAtUtilization(0.8e18);
        computeRateAtUtilization(0.8e18);

        // Utilization remains at `kink` so rate and full rate remain the same.
        (uint256 rate2, uint256 fullRate2) = computeRateAtUtilization(0.8e18);
        assertEq(rate2, rate1);
        assertEq(fullRate2, fullRate1);

        // Even after time delay, there is no adaptation because the IRM is at kink.
        skip(365 days);
        (uint256 rate3, uint256 fullRate3) = computeRateAtUtilization(0.8e18);
        assertEq(rate3, rate1);
        assertEq(fullRate3, fullRate1);

        // Utilization decreases but within range. No adaptation.
        skip(1 days);
        (, uint256 fullRate4) = computeRateAtUtilization(0.75e18);
        assertEq(fullRate4, fullRate1);

        // Utilization moves to lower bound of range. No adaptation.
        skip(1 days);
        (, uint256 fullRate5) = computeRateAtUtilization(0.7e18 + 1);
        assertEq(fullRate5, fullRate1);

        // Utilization increases but within range. No adaptation.
        skip(1 days);
        (, uint256 fullRate6) = computeRateAtUtilization(0.85e18);
        assertEq(fullRate6, fullRate1);

        // Utilization moves to upper bound of range. No adaptation.
        skip(1 days);
        (, uint256 fullRate7) = computeRateAtUtilization(0.9e18);
        assertEq(fullRate7, fullRate1);

        // Utilization increases above range. Rate and full rate increase.
        skip(1 days);
        (, uint256 fullRate8) = computeRateAtUtilization(0.95e18);
        // deltaUtilization = (0.95 - 0.9) / (1 - 0.9) = 0.5
        // fullrate *= (6 hours + 0.5^2 * 24 hours) / 6 hours
        // fullrate *= 2
        assertEq(fullRate8, 2 * fullRate1);

        // Utilization remains above range. Rate and full rate increase.
        skip(1 days);
        (, uint256 fullRate9) = computeRateAtUtilization(0.95e18);
        // (...) fullrate *= 2
        assertEq(fullRate9, 4 * fullRate1);

        // Utilization remains above range. Rate and full rate increase but they are capped.
        skip(1 days);
        (, uint256 fullRate10) = computeRateAtUtilization(0.95e18);
        assertEq(fullRate10, maxFullRate);

        // Rate and full rate remain capped irrespective of time passed.
        skip(365 days);
        (, uint256 fullRate11) = computeRateAtUtilization(0.95e18);
        assertEq(fullRate11, maxFullRate);

        // Utilization falls to range. Full rate is not adjusted.
        skip(1 days);
        (, uint256 fullRate12) = computeRateAtUtilization(0.9e18);
        assertEq(fullRate12, maxFullRate);

        // Utilization falls to lower bound range. Full rate is not adjusted.
        skip(1 days);
        (, uint256 fullRate13) = computeRateAtUtilization(0.7e18 + 1);
        assertEq(fullRate13, maxFullRate);

        // Utilization falls below range. Full rate decreases.
        skip(1 days);
        (, uint256 fullRate14) = computeRateAtUtilization(0.35e18 + 1);
        assertEq(fullRate14, maxFullRate / 2);

        // Utilization remains below range. Full rate decreases.
        skip(1 days);
        (, uint256 fullRate15) = computeRateAtUtilization(0.35e18 + 1);
        assertEq(fullRate15, maxFullRate / 4);

        // After some time full rate falls to minimum.
        skip(365 days);
        (, uint256 fullRate16) = computeRateAtUtilization(0.35e18 + 1);
        assertEq(fullRate16, minFullRate);
    }

    function computeRateAtUtilization(uint256 utilizationRate) internal returns (uint256 rate, uint256 fullRate) {
        if (utilizationRate == 0) {
            rate = irm.computeInterestRate(VAULT, 0, 0);
        } else if (utilizationRate == 1e18) {
            rate = irm.computeInterestRate(VAULT, 0, 1e18);
        } else {
            uint256 borrows = 1e18 * utilizationRate / (1e18 - utilizationRate);
            rate = irm.computeInterestRate(VAULT, 1e18, borrows);
        }
        (fullRate,) = irm.irState(VAULT);
    }
}
