// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IRMAdaptiveCurve} from "../../../src/IRM/IRMAdaptiveCurve.sol";
import {IRMAdaptiveCurveHarness} from "./IRMAdaptiveCurveHarness.sol";

/// forge-config: default.invariant.runs = 100
/// forge-config: default.invariant.depth = 100
contract IRMAdaptiveCurveInvariantTest is Test {
    int256 internal constant SECONDS_PER_YEAR = int256(365 days);
    int256 internal constant TARGET_UTILIZATION = 0.9e18;
    int256 internal constant INITIAL_RATE_AT_TARGET = 0.04e18 / SECONDS_PER_YEAR;
    int256 internal constant MIN_RATE_AT_TARGET = 0.001e18 / SECONDS_PER_YEAR;
    int256 internal constant MAX_RATE_AT_TARGET = 2.0e18 / SECONDS_PER_YEAR;
    int256 internal constant CURVE_STEEPNESS = 4e18;
    int256 internal constant ADJUSTMENT_SPEED = 50e18 / SECONDS_PER_YEAR;

    IRMAdaptiveCurve internal irm;
    IRMAdaptiveCurve internal irmSteeper;
    IRMAdaptiveCurve internal irmFlatter;
    IRMAdaptiveCurve internal irmSlower;
    IRMAdaptiveCurve internal irmFaster;
    IRMAdaptiveCurveHarness internal harness;

    function setUp() public {
        irm = new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED
        );
        irmSteeper = new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS * 10,
            ADJUSTMENT_SPEED
        );
        irmFlatter = new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS / 2,
            ADJUSTMENT_SPEED
        );
        irmSlower = new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED / 10
        );
        irmFaster = new IRMAdaptiveCurve(
            TARGET_UTILIZATION,
            INITIAL_RATE_AT_TARGET,
            MIN_RATE_AT_TARGET,
            MAX_RATE_AT_TARGET,
            CURVE_STEEPNESS,
            ADJUSTMENT_SPEED * 10
        );
        harness = new IRMAdaptiveCurveHarness();
        harness.addIrm(irm);
        harness.addIrm(irmSteeper);
        harness.addIrm(irmFlatter);
        harness.addIrm(irmSlower);
        harness.addIrm(irmFaster);

        vm.label(address(irm), "irm");
        vm.label(address(irmSteeper), "irmSteeper");
        vm.label(address(irmFlatter), "irmFlatter");
        vm.label(address(irmSlower), "irmSlower");
        vm.label(address(irmFaster), "irmFaster");
        vm.label(address(harness), "harness");

        // Only let the vault call the harness computeInterestRate method
        bytes4[] memory targetSelectors = new bytes4[](1);
        targetSelectors[0] = IRMAdaptiveCurveHarness.computeInterestRate.selector;
        targetSelector(FuzzSelector(address(harness), targetSelectors));
        targetContract(address(harness));
    }

    function invariant_KinkRateBetweenMinAndMax() public view {
        uint256 numCalls = harness.numCalls();
        if (numCalls == 0) return;
        IRMAdaptiveCurve[] memory irms = harness.getIrms();

        for (uint256 i = 0; i < irms.length; ++i) {
            IRMAdaptiveCurve _irm = irms[i];
            IRMAdaptiveCurveHarness.StateHistory memory lastCall = harness.nthCall(_irm, numCalls - 1);
            assertGe(lastCall.rateAtTarget, uint256(_irm.MIN_RATE_AT_TARGET()));
            assertLe(lastCall.rateAtTarget, uint256(_irm.MAX_RATE_AT_TARGET()));
        }
    }

    function invariant_SteepnessAffectsRatesCorrectly() public view {
        uint256 numCalls = harness.numCalls();
        if (numCalls == 0) return;

        IRMAdaptiveCurveHarness.StateHistory memory lastCallIrm = harness.nthCall(irm, numCalls - 1);
        IRMAdaptiveCurveHarness.StateHistory memory lastCallIrmSteeper = harness.nthCall(irmSteeper, numCalls - 1);
        IRMAdaptiveCurveHarness.StateHistory memory lastCallIrmFlatter = harness.nthCall(irmFlatter, numCalls - 1);

        if (lastCallIrm.utilization > uint256(irm.TARGET_UTILIZATION())) {
            // Above TARGET_UTILIZATION steeper CURVE_STEEPNESS = higher rate
            assertGe(lastCallIrmSteeper.rate, lastCallIrm.rate);
            assertLe(lastCallIrmFlatter.rate, lastCallIrm.rate);
        } else if (lastCallIrm.utilization < uint256(irm.TARGET_UTILIZATION())) {
            assertLe(lastCallIrmSteeper.rate, lastCallIrm.rate);
            assertGe(lastCallIrmFlatter.rate, lastCallIrm.rate);
        }

        // Steepness does not change rate at target.
        assertEq(lastCallIrmSteeper.rateAtTarget, lastCallIrm.rateAtTarget);
        assertEq(lastCallIrmFlatter.rateAtTarget, lastCallIrm.rateAtTarget);
    }

    function invariant_SteepnessDoesNotAffectRatesAtKink() public {
        harness.computeInterestRate(3600, 1e18, 9e18);
        uint256 numCalls = harness.numCalls();

        IRMAdaptiveCurveHarness.StateHistory memory lastCallIrm = harness.nthCall(irm, numCalls - 1);
        IRMAdaptiveCurveHarness.StateHistory memory lastCallIrmSteeper = harness.nthCall(irmSteeper, numCalls - 1);
        IRMAdaptiveCurveHarness.StateHistory memory lastCallIrmFlatter = harness.nthCall(irmFlatter, numCalls - 1);

        assertEq(lastCallIrmSteeper.rate, lastCallIrm.rate);
        assertEq(lastCallIrmFlatter.rate, lastCallIrm.rate);
    }

    function invariant_AdaptiveMechanismMovesKinkRateInCorrectDirection() public view {
        uint256 numCalls = harness.numCalls();
        if (numCalls < 2) return;

        IRMAdaptiveCurve[] memory irms = harness.getIrms();
        for (uint256 i = 0; i < irms.length; ++i) {
            IRMAdaptiveCurve _irm = irms[i];
            IRMAdaptiveCurveHarness.StateHistory memory lastCall = harness.nthCall(_irm, numCalls - 1);
            IRMAdaptiveCurveHarness.StateHistory memory secondToLastCall = harness.nthCall(_irm, numCalls - 2);

            if (lastCall.delay == 0) {
                // if time has not passed then the model should not adapt
                assertEq(lastCall.rateAtTarget, secondToLastCall.rateAtTarget);
            } else if (lastCall.utilization > uint256(_irm.TARGET_UTILIZATION())) {
                // must have translated the model up
                if (lastCall.rateAtTarget == uint256(irm.MAX_RATE_AT_TARGET())) return;
                assertGe(lastCall.rateAtTarget, secondToLastCall.rateAtTarget);
            } else if (lastCall.utilization < uint256(_irm.TARGET_UTILIZATION())) {
                // must have translated the model down
                if (lastCall.rateAtTarget == uint256(irm.MIN_RATE_AT_TARGET())) return;
                assertLe(lastCall.rateAtTarget, secondToLastCall.rateAtTarget);
            }
        }
    }
}
