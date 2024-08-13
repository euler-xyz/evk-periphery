// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IIRM} from "evk/InterestRateModels/IIRM.sol";
import {IRMAdaptiveLinearKink} from "../../src/IRM/IRMAdaptiveLinearKink.sol";

struct IRMAdaptiveLinearKinkParams {
    int256 kink;
    int256 initialKinkRate;
    int256 minKinkRate;
    int256 maxKinkRate;
    int256 slope;
    int256 adjustmentSpeed;
}

contract IRMAdaptiveLinearKinkHarness is Test {
    int256 internal constant SECONDS_PER_YEAR = int256(365 days);
    IRMAdaptiveLinearKink[] internal irms;

    struct StateHistory {
        uint256 cash;
        uint256 borrows;
        uint256 utilization;
        uint256 rate;
        int208 kinkRate;
        uint48 timestamp;
        uint32 delay;
    }

    uint256 public numCalls;
    mapping(IRMAdaptiveLinearKink => StateHistory[]) public history;

    function addIrm(IRMAdaptiveLinearKink irm) external {
        irms.push(irm);
    }

    function getIrms() external view returns (IRMAdaptiveLinearKink[] memory) {
        return irms;
    }

    function computeInterestRate(uint24 delay, uint96 cash, uint96 borrows) external {
        skip(delay);
        ++numCalls;

        for (uint256 i = 0; i < irms.length; ++i) {
            IRMAdaptiveLinearKink irm = irms[i];
            uint256 rate = irm.computeInterestRate(address(this), cash, borrows);
            (int208 kinkRate, uint48 timestamp) = irm.irState(address(this));
            uint256 totalAssets = uint256(cash) + borrows;
            uint256 utilization = totalAssets == 0 ? 0 : uint256(borrows) * 1e18 / totalAssets;
            history[irm].push(
                StateHistory({
                    cash: cash,
                    borrows: borrows,
                    utilization: utilization,
                    rate: rate,
                    kinkRate: kinkRate,
                    timestamp: timestamp,
                    delay: delay
                })
            );
        }
    }

    function nthCall(IRMAdaptiveLinearKink irm, uint256 index) external view returns (StateHistory memory) {
        return history[irm][index];
    }

    function bound(IRMAdaptiveLinearKinkParams memory p) public pure {
        // [0.1%, 99.9%]
        p.kink = bound(p.kink, 0.001e18, 0.999e18);
        // [0.001% APR, 1000% APR]
        p.minKinkRate = bound(p.minKinkRate, 0.00001e18 / SECONDS_PER_YEAR, 10e18 / SECONDS_PER_YEAR);
        // [0.001% APR, 1000% APR]
        p.maxKinkRate = bound(p.maxKinkRate, p.minKinkRate, 10e18 / SECONDS_PER_YEAR);
        p.initialKinkRate = bound(p.initialKinkRate, p.minKinkRate, p.maxKinkRate);
        // [1.001x, 1000x]
        p.slope = bound(p.slope, 1.001e18, 1000e18);
        p.adjustmentSpeed = bound(p.adjustmentSpeed, 0.1e18, 1000e18);
    }
}

contract IRMAdaptiveLinearKinkInvariantTest is Test {
    int256 internal constant SECONDS_PER_YEAR = int256(365 days);
    int256 internal constant kink = 0.9e18;
    int256 internal constant initialKinkRate = 0.04e18 / SECONDS_PER_YEAR;
    int256 internal constant minKinkRate = 0.001e18 / SECONDS_PER_YEAR;
    int256 internal constant maxKinkRate = 2.0e18 / SECONDS_PER_YEAR;
    int256 internal constant slope = 4e18;
    int256 internal constant adjustmentSpeed = 50e18 / SECONDS_PER_YEAR;

    IRMAdaptiveLinearKink internal irm;
    IRMAdaptiveLinearKink internal irmSteeper;
    IRMAdaptiveLinearKink internal irmFlatter;
    IRMAdaptiveLinearKink internal irmSlower;
    IRMAdaptiveLinearKink internal irmFaster;
    IRMAdaptiveLinearKinkHarness internal harness;

    function setUp() public {
        irm = new IRMAdaptiveLinearKink(kink, initialKinkRate, minKinkRate, maxKinkRate, slope, adjustmentSpeed);
        irmSteeper = new IRMAdaptiveLinearKink(kink, initialKinkRate, minKinkRate, maxKinkRate, 40e18, adjustmentSpeed);
        irmFlatter = new IRMAdaptiveLinearKink(kink, initialKinkRate, minKinkRate, maxKinkRate, 2e18, adjustmentSpeed);
        irmSlower =
            new IRMAdaptiveLinearKink(kink, initialKinkRate, minKinkRate, maxKinkRate, slope, 5e18 / SECONDS_PER_YEAR);
        irmFaster =
            new IRMAdaptiveLinearKink(kink, initialKinkRate, minKinkRate, maxKinkRate, slope, 500e18 / SECONDS_PER_YEAR);
        harness = new IRMAdaptiveLinearKinkHarness();
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
        targetSelectors[0] = IRMAdaptiveLinearKinkHarness.computeInterestRate.selector;
        targetSelector(FuzzSelector(address(harness), targetSelectors));
        targetContract(address(harness));
    }

    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.depth = 100
    function invariant_KinkRateIsNeverBelowMin() public view {
        uint256 numCalls = harness.numCalls();
        if (numCalls == 0) return;
        IRMAdaptiveLinearKink[] memory irms = harness.getIrms();

        for (uint256 i = 0; i < irms.length; ++i) {
            IRMAdaptiveLinearKink _irm = irms[i];
            IRMAdaptiveLinearKinkHarness.StateHistory memory lastCall = harness.nthCall(_irm, numCalls - 1);
            assertGe(lastCall.kinkRate, _irm.minKinkRate());
        }
    }

    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.depth = 100
    function invariant_KinkRateIsNeverAboveMax() public view {
        uint256 numCalls = harness.numCalls();
        if (numCalls == 0) return;

        IRMAdaptiveLinearKink[] memory irms = harness.getIrms();
        for (uint256 i = 0; i < irms.length; ++i) {
            IRMAdaptiveLinearKink _irm = irms[i];
            IRMAdaptiveLinearKinkHarness.StateHistory memory lastCall = harness.nthCall(_irm, numCalls - 1);
            assertLe(lastCall.kinkRate, _irm.maxKinkRate());
        }
    }

    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.depth = 100
    function invariant_SlopeAffectsRatesCorrectly() public view {
        uint256 numCalls = harness.numCalls();
        if (numCalls == 0) return;

        IRMAdaptiveLinearKinkHarness.StateHistory memory lastCallIrm = harness.nthCall(irm, numCalls - 1);
        IRMAdaptiveLinearKinkHarness.StateHistory memory lastCallIrmSteeper = harness.nthCall(irmSteeper, numCalls - 1);
        IRMAdaptiveLinearKinkHarness.StateHistory memory lastCallIrmFlatter = harness.nthCall(irmFlatter, numCalls - 1);

        if (lastCallIrm.utilization > uint256(irm.kink())) {
            // Above kink steeper slope = higher rate
            assertGe(lastCallIrmSteeper.rate, lastCallIrm.rate);
            assertLe(lastCallIrmFlatter.rate, lastCallIrm.rate);
        } else if (lastCallIrm.utilization < uint256(irm.kink())) {
            assertLe(lastCallIrmSteeper.rate, lastCallIrm.rate);
            assertGe(lastCallIrmFlatter.rate, lastCallIrm.rate);
        }

        // Slope does not change kink rate.
        assertEq(lastCallIrmSteeper.kinkRate, lastCallIrm.kinkRate);
        assertEq(lastCallIrmFlatter.kinkRate, lastCallIrm.kinkRate);
    }

    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.depth = 100
    function invariant_SlopeDoesNotAffectRatesAtKink() public {
        harness.computeInterestRate(3600, 1e18, 9e18);
        uint256 numCalls = harness.numCalls();

        IRMAdaptiveLinearKinkHarness.StateHistory memory lastCallIrm = harness.nthCall(irm, numCalls - 1);
        IRMAdaptiveLinearKinkHarness.StateHistory memory lastCallIrmSteeper = harness.nthCall(irmSteeper, numCalls - 1);
        IRMAdaptiveLinearKinkHarness.StateHistory memory lastCallIrmFlatter = harness.nthCall(irmFlatter, numCalls - 1);

        assertEq(lastCallIrmSteeper.rate, lastCallIrm.rate);
        assertEq(lastCallIrmFlatter.rate, lastCallIrm.rate);
    }

    /// forge-config: default.invariant.runs = 100
    /// forge-config: default.invariant.depth = 100
    function invariant_AdaptiveMechanismMovesKinkRateInCorrectDirection() public view {
        uint256 numCalls = harness.numCalls();
        if (numCalls < 2) return;

        IRMAdaptiveLinearKink[] memory irms = harness.getIrms();
        for (uint256 i = 0; i < irms.length; ++i) {
            IRMAdaptiveLinearKink _irm = irms[i];
            IRMAdaptiveLinearKinkHarness.StateHistory memory lastCall = harness.nthCall(_irm, numCalls - 1);
            IRMAdaptiveLinearKinkHarness.StateHistory memory secondToLastCall = harness.nthCall(_irm, numCalls - 2);

            if (lastCall.delay == 0) {
                // if time has not passed then the model should not adapt
                assertEq(lastCall.kinkRate, secondToLastCall.kinkRate);
            } else if (lastCall.utilization > uint256(_irm.kink())) {
                // must have translated the kink model up
                if (lastCall.kinkRate == irm.maxKinkRate()) return;
                assertTrue(lastCall.kinkRate > secondToLastCall.kinkRate);
            } else if (lastCall.utilization < uint256(_irm.kink())) {
                // must have translated the kink model down
                if (lastCall.kinkRate == irm.minKinkRate()) return;
                assertTrue(lastCall.kinkRate < secondToLastCall.kinkRate);
            }
        }
    }
}
