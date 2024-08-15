// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IRMAdaptiveLinearKink} from "../../../src/IRM/IRMAdaptiveLinearKink.sol";

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
