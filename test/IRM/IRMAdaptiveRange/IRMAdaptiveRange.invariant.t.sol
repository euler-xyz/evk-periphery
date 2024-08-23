// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IRMAdaptiveRange} from "../../../src/IRM/IRMAdaptiveRange.sol";
import {IRMAdaptiveRangeHarness} from "./IRMAdaptiveRangeHarness.sol";

/// forge-config: default.invariant.runs = 100
/// forge-config: default.invariant.depth = 100
contract IRMAdaptiveRangeInvariantTest is Test {
    uint256 internal constant SECONDS_PER_YEAR = 365 days;
    uint256 internal constant MIN_TARGET_UTIL = 0.7e18;
    uint256 internal constant MAX_TARGET_UTIL = 0.9e18;
    uint256 internal constant VERTEX_UTILIZATION = 0.8e18;
    uint256 internal constant ZERO_UTIL_RATE = 0.01e18 / SECONDS_PER_YEAR;
    uint256 internal constant MIN_FULL_UTIL_RATE = 100e18 / SECONDS_PER_YEAR;
    uint256 internal constant MAX_FULL_UTIL_RATE = 1000e18 / SECONDS_PER_YEAR;
    uint256 internal constant INITIAL_FULL_UTIL_RATE = 200e18 / SECONDS_PER_YEAR;
    uint256 internal constant RATE_HALF_LIFE = 6 hours;
    uint256 internal constant VERTEX_RATE_PERCENT = 0.9e18;

    IRMAdaptiveRange internal irm;
    IRMAdaptiveRange internal irmSlower;
    IRMAdaptiveRange internal irmFaster;
    IRMAdaptiveRangeHarness internal harness;

    function setUp() public {
        irm = new IRMAdaptiveRange(
            MIN_TARGET_UTIL,
            MAX_TARGET_UTIL,
            VERTEX_UTILIZATION,
            ZERO_UTIL_RATE,
            MIN_FULL_UTIL_RATE,
            MAX_FULL_UTIL_RATE,
            INITIAL_FULL_UTIL_RATE,
            RATE_HALF_LIFE,
            VERTEX_RATE_PERCENT
        );
        irmSlower = new IRMAdaptiveRange(
            MIN_TARGET_UTIL,
            MAX_TARGET_UTIL,
            VERTEX_UTILIZATION,
            ZERO_UTIL_RATE,
            MIN_FULL_UTIL_RATE,
            MAX_FULL_UTIL_RATE,
            INITIAL_FULL_UTIL_RATE,
            RATE_HALF_LIFE * 2,
            VERTEX_RATE_PERCENT
        );
        irmFaster = new IRMAdaptiveRange(
            MIN_TARGET_UTIL,
            MAX_TARGET_UTIL,
            VERTEX_UTILIZATION,
            ZERO_UTIL_RATE,
            MIN_FULL_UTIL_RATE,
            MAX_FULL_UTIL_RATE,
            INITIAL_FULL_UTIL_RATE,
            RATE_HALF_LIFE / 2,
            VERTEX_RATE_PERCENT
        );
        harness = new IRMAdaptiveRangeHarness();
        harness.addIrm(irm);
        harness.addIrm(irmSlower);
        harness.addIrm(irmFaster);

        vm.label(address(irm), "irm");
        vm.label(address(irmSlower), "irmSlower");
        vm.label(address(irmFaster), "irmFaster");
        vm.label(address(harness), "harness");

        // Only let the vault call the harness computeInterestRate method
        bytes4[] memory targetSelectors = new bytes4[](1);
        targetSelectors[0] = IRMAdaptiveRangeHarness.computeInterestRate.selector;
        targetSelector(FuzzSelector(address(harness), targetSelectors));
        targetContract(address(harness));
    }

    function invariant_FullRateBetweenMinAndMax() public view {
        uint256 numCalls = harness.numCalls();
        if (numCalls == 0) return;
        IRMAdaptiveRange[] memory irms = harness.getIrms();

        for (uint256 i = 0; i < irms.length; ++i) {
            IRMAdaptiveRange _irm = irms[i];
            IRMAdaptiveRangeHarness.StateHistory memory lastCall = harness.nthCall(_irm, numCalls - 1);
            assertGe(lastCall.fullRate, _irm.MIN_FULL_UTIL_RATE());
            assertLe(lastCall.fullRate, _irm.MAX_FULL_UTIL_RATE());
        }
    }

    function invariant_FirstCallAlwaysSetsFullRateToInitialFullRate() public view {
        uint256 numCalls = harness.numCalls();
        if (numCalls != 1) return;
        IRMAdaptiveRange[] memory irms = harness.getIrms();

        for (uint256 i = 0; i < irms.length; ++i) {
            IRMAdaptiveRange _irm = irms[i];
            IRMAdaptiveRangeHarness.StateHistory memory lastCall = harness.nthCall(_irm, numCalls - 1);
            assertGe(lastCall.fullRate, _irm.INITIAL_FULL_UTIL_RATE());
        }
    }

    function invariant_AdaptiveMechanismMovesFullRateInCorrectDirection() public view {
        uint256 numCalls = harness.numCalls();
        if (numCalls < 2) return;

        IRMAdaptiveRange[] memory irms = harness.getIrms();
        for (uint256 i = 0; i < irms.length; ++i) {
            IRMAdaptiveRange _irm = irms[i];
            IRMAdaptiveRangeHarness.StateHistory memory lastCall = harness.nthCall(_irm, numCalls - 1);
            IRMAdaptiveRangeHarness.StateHistory memory secondToLastCall = harness.nthCall(_irm, numCalls - 2);

            if (lastCall.delay == 0) {
                // if time has not passed then the model should not adapt
                assertEq(lastCall.fullRate, secondToLastCall.fullRate);
            } else if (lastCall.utilization > uint256(_irm.MAX_TARGET_UTIL())) {
                // must have translated the VERTEX_UTILIZATION model up
                if (lastCall.fullRate == irm.MAX_FULL_UTIL_RATE()) return;
                assertGe(lastCall.fullRate, secondToLastCall.fullRate);
            } else if (lastCall.utilization < uint256(_irm.MIN_TARGET_UTIL())) {
                // must have translated the VERTEX_UTILIZATION model down
                if (lastCall.fullRate == irm.MIN_FULL_UTIL_RATE()) return;
                assertLe(lastCall.fullRate, secondToLastCall.fullRate);
            } else {
                // if utilization rate is within bounds then the model should not adapt
                assertEq(lastCall.fullRate, secondToLastCall.fullRate);
            }
        }
    }
}
