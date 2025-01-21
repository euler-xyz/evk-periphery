// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {IRMAdaptiveCurve} from "../../../src/IRM/IRMAdaptiveCurve.sol";

struct IRMAdaptiveCurveParams {
    int256 TARGET_UTILIZATION;
    int256 INITIAL_RATE_AT_TARGET;
    int256 MIN_RATE_AT_TARGET;
    int256 MAX_RATE_AT_TARGET;
    int256 CURVE_STEEPNESS;
    int256 ADJUSTMENT_SPEED;
}

contract IRMAdaptiveCurveHarness is Test {
    int256 internal constant SECONDS_PER_YEAR = int256(365 days);
    IRMAdaptiveCurve[] internal irms;

    struct StateHistory {
        uint256 cash;
        uint256 borrows;
        uint256 utilization;
        uint256 rate;
        uint256 rateRay;
        uint256 rateAtTarget;
        uint256 rateAtTargetRay;
        uint32 delay;
    }

    uint256 public numCalls;
    mapping(IRMAdaptiveCurve => StateHistory[]) public history;

    function addIrm(IRMAdaptiveCurve irm) external {
        irms.push(irm);
    }

    function getIrms() external view returns (IRMAdaptiveCurve[] memory) {
        return irms;
    }

    function computeInterestRate(uint24 delay, uint96 cash, uint96 borrows) external {
        skip(delay);
        ++numCalls;

        for (uint256 i = 0; i < irms.length; ++i) {
            IRMAdaptiveCurve irm = irms[i];
            uint256 rateRay = irm.computeInterestRate(address(this), cash, borrows);
            uint256 rateAtTargetRay = irm.computeRateAtTargetView(address(this), cash, borrows);
            uint256 totalAssets = uint256(cash) + borrows;
            uint256 utilization = totalAssets == 0 ? 0 : uint256(borrows) * 1e18 / totalAssets;
            history[irm].push(
                StateHistory({
                    cash: cash,
                    borrows: borrows,
                    utilization: utilization,
                    rate: rateRay / 1e9,
                    rateRay: rateRay,
                    rateAtTarget: rateAtTargetRay / 1e9,
                    rateAtTargetRay: rateAtTargetRay,
                    delay: delay
                })
            );
        }
    }

    function nthCall(IRMAdaptiveCurve irm, uint256 index) external view returns (StateHistory memory) {
        return history[irm][index];
    }

    function bound(IRMAdaptiveCurveParams memory p) public pure {
        // [0.1%, 99.9%]
        p.TARGET_UTILIZATION = bound(p.TARGET_UTILIZATION, 0.001e18, 0.999e18);
        // [0.001%, 1000%]
        p.MIN_RATE_AT_TARGET = bound(p.MIN_RATE_AT_TARGET, 0.00001e18 / SECONDS_PER_YEAR, 10e18 / SECONDS_PER_YEAR);
        // [0.001%, 1000%]
        p.MAX_RATE_AT_TARGET = bound(p.MAX_RATE_AT_TARGET, p.MIN_RATE_AT_TARGET, 10e18 / SECONDS_PER_YEAR);
        p.INITIAL_RATE_AT_TARGET = bound(p.INITIAL_RATE_AT_TARGET, p.MIN_RATE_AT_TARGET, p.MAX_RATE_AT_TARGET);
        // [1.001x, 1000x]
        p.CURVE_STEEPNESS = bound(p.CURVE_STEEPNESS, 1.001e18, 1000e18);
        p.ADJUSTMENT_SPEED = bound(p.ADJUSTMENT_SPEED, 0.1e18, 1000e18);
    }
}