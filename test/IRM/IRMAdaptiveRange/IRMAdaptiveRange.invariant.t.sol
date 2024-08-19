// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IRMAdaptiveRange} from "../../../src/IRM/IRMAdaptiveRange.sol";
import {IRMAdaptiveRangeHarness} from "./IRMAdaptiveRangeHarness.sol";

/// forge-config: default.invariant.runs = 100
/// forge-config: default.invariant.depth = 100
contract IRMAdaptiveRangeInvariantTest is Test {
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

    IRMAdaptiveRange internal irm;
    IRMAdaptiveRange internal irmSlower;
    IRMAdaptiveRange internal irmFaster;
    IRMAdaptiveRangeHarness internal harness;

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
        irmSlower = new IRMAdaptiveRange(
            targetUtilizationLower,
            targetUtilizationUpper,
            kink,
            baseRate,
            minFullRate,
            maxFullRate,
            initialFullRate,
            halfLife * 2,
            kinkRatePercent
        );
        irmFaster = new IRMAdaptiveRange(
            targetUtilizationLower,
            targetUtilizationUpper,
            kink,
            baseRate,
            minFullRate,
            maxFullRate,
            initialFullRate,
            halfLife / 2,
            kinkRatePercent
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
            assertGe(lastCall.fullRate, _irm.minFullRate());
            assertLe(lastCall.fullRate, _irm.maxFullRate());
        }
    }

    function invariant_FirstCallAlwaysSetsFullRateToInitialFullRate() public view {
        uint256 numCalls = harness.numCalls();
        if (numCalls != 1) return;
        IRMAdaptiveRange[] memory irms = harness.getIrms();

        for (uint256 i = 0; i < irms.length; ++i) {
            IRMAdaptiveRange _irm = irms[i];
            IRMAdaptiveRangeHarness.StateHistory memory lastCall = harness.nthCall(_irm, numCalls - 1);
            assertGe(lastCall.fullRate, _irm.initialFullRate());
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
            } else if (lastCall.utilization > uint256(_irm.targetUtilizationUpper())) {
                // must have translated the kink model up
                if (lastCall.fullRate == irm.maxFullRate()) return;
                assertGe(lastCall.fullRate, secondToLastCall.fullRate);
            } else if (lastCall.utilization < uint256(_irm.targetUtilizationLower())) {
                // must have translated the kink model down
                if (lastCall.fullRate == irm.minFullRate()) return;
                assertLe(lastCall.fullRate, secondToLastCall.fullRate);
            } else {
                // if utilization rate is within bounds then the model should not adapt
                assertEq(lastCall.fullRate, secondToLastCall.fullRate);
            }
        }
    }
}