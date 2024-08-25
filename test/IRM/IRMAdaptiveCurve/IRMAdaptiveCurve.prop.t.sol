// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IRMLinearKink} from "evk/InterestRateModels/IRMLinearKink.sol";
import {IRMAdaptiveCurve} from "../../../src/IRM/IRMAdaptiveCurve.sol";

/// forge-config: default.fuzz.runs = 100
contract IRMAdaptiveCurvePropTest is Test {
    address internal constant VAULT = address(0x1234);
    int256 internal constant YEAR = int256(365.2425 days);
    uint256 internal constant NUM_INTERACTIONS = 50;
    uint256 internal constant NUM_SAMPLES = 20;

    /// @dev Given an IRMAdaptiveCurve in any state we can create an equivalent LinearKinkIRM that replicates its
    /// interest rate function at that point in time (i.e. returns the same rates across the entire utilization range).
    /// Verifies that: 1) The instantaneous interest rate function of IRMAdaptiveCurve is isomorphic to LinearKinkIRM.
    /// 2) The adjustments made by IRMAdaptiveCurve preserve this isomorphism (i.e. we can find another equivalent
    /// LinearKinkIRM after any number of adjustments).
    function test_AdaptiveCurveIsEquivalentToLinearKinkIgnoringTime(
        int256 TARGET_UTILIZATION,
        int256 INITIAL_RATE_AT_TARGET,
        int256 MIN_RATE_AT_TARGET,
        int256 MAX_RATE_AT_TARGET,
        int256 CURVE_STEEPNESS,
        int256 ADJUSTMENT_SPEED,
        uint256 seed
    ) public {
        // Bound params.
        TARGET_UTILIZATION = bound(TARGET_UTILIZATION, 0.001e18, 0.999e18);
        MIN_RATE_AT_TARGET = bound(MIN_RATE_AT_TARGET, 0.001e18 / YEAR, 10e18 / YEAR);
        MAX_RATE_AT_TARGET = bound(MAX_RATE_AT_TARGET, MIN_RATE_AT_TARGET, 10e18 / YEAR);
        INITIAL_RATE_AT_TARGET = bound(INITIAL_RATE_AT_TARGET, MIN_RATE_AT_TARGET, MAX_RATE_AT_TARGET);
        CURVE_STEEPNESS = bound(CURVE_STEEPNESS, 1.01e18, 100e18);
        ADJUSTMENT_SPEED = bound(ADJUSTMENT_SPEED, 2e18 / YEAR, 1000e18 / YEAR);

        // Deploy adaptive IRM.
        IRMAdaptiveCurve irmAdaptive = new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );

        // Simulate interactions.
        vm.startPrank(VAULT);
        for (uint256 i = 0; i < NUM_INTERACTIONS; ++i) {
            // Randomize utilization rate and time passed.
            (uint256 cash, uint256 borrows) = getCashAndBorrowsAtUtilizationRate(
                bound(uint256(keccak256(abi.encodePacked("utilizationRate", seed, i))), 0, 1e18)
            );
            uint256 timeDelta = bound(uint256(keccak256(abi.encodePacked("timeDelta", seed, i))), 0, 30 days);

            // We update the IRMAdaptiveCurve with a random utilization and random delta time.
            skip(timeDelta);
            irmAdaptive.computeInterestRate(VAULT, cash, borrows);
            uint256 rateAtTarget = irmAdaptive.computeRateAtTargetView(VAULT, cash, borrows);

            // Deploy an equivalent IRMLinearKink to the IRMAdaptiveCurve at current rateAtTarget.
            IRMLinearKink irmStatic = deployEquivalentIRMLinearKink(rateAtTarget, TARGET_UTILIZATION, CURVE_STEEPNESS);

            // Now that we have the IRMLinearKink, we sweep the utilization range to assert they are equivalent.
            for (uint256 j = 0; j <= NUM_SAMPLES; ++j) {
                // [0%, 5%, ..., 100%]
                uint256 sampleUtilizationRate = j * 1e18 / NUM_SAMPLES;
                (uint256 sampleCash, uint256 sampleBorrows) = getCashAndBorrowsAtUtilizationRate(sampleUtilizationRate);
                uint256 rateAdaptive = irmAdaptive.computeInterestRateView(VAULT, sampleCash, sampleBorrows);
                uint256 rateStatic = irmStatic.computeInterestRateView(VAULT, sampleCash, sampleBorrows);
                assertApproxEqAbs(rateAdaptive, rateStatic, 1e15); // within 1e-12 of each other
            }
        }
    }

    function deployEquivalentIRMLinearKink(uint256 rateAtTarget, int256 targetUtilization, int256 curveSteepness)
        internal
        returns (IRMLinearKink)
    {
        uint256 baseRate = rateAtTarget * 1e18 / uint256(curveSteepness);
        uint256 maxRate = rateAtTarget * uint256(curveSteepness) / 1e18;
        uint32 kink = uint32(uint256(targetUtilization) * type(uint32).max / 1e18);

        uint256 slope1 = (uint256(rateAtTarget) - baseRate) / kink;
        uint256 slope2 = (maxRate - baseRate - kink * slope1) / (type(uint32).max - kink);
        return new IRMLinearKink(baseRate, slope1, slope2, kink);
    }

    function getCashAndBorrowsAtUtilizationRate(uint256 utilizationRate) internal pure returns (uint256, uint256) {
        if (utilizationRate == 0) return (0, 0);
        if (utilizationRate == 1e18) return (0, 1e18);

        uint256 borrows = 1e18 * utilizationRate / (1e18 - utilizationRate);
        return (1e18, borrows);
    }
}
