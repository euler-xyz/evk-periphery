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
    address internal constant VAULT = address(0x1234);
    int256 internal constant SECONDS_PER_YEAR = int256(365 days);
    IRMAdaptiveLinearKink internal irm;
    uint256 public lastCash;
    uint256 public lastBorrows;
    uint256 public lastRate;

    constructor(IRMAdaptiveLinearKink _irm) {
        irm = _irm;
    }

    function computeInterestRate(uint256 delay, uint256 cash, uint256 borrows) external view returns (uint256) {
        skip(delay);
        lastCash = cash;
        lastBorrows = borrows;
        vm.prank(VAULT);
        lastRate = irm.computeInterestRate(VAULT, cash, borrows);
    }

    function bound(IRMAdaptiveLinearKinkParams memory p) {
        int256 year = int256(365 days);
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
    /// @dev 90%
    int256 constant kink = 0.9 ether;
    /// @dev 4%
    int256 constant initialKinkRate = 0.04 ether / int256(365 days);
    /// @dev 0.1%
    int256 constant minKinkRate = 0.001 ether / int256(365 days);
    /// @dev 200%
    int256 constant maxKinkRate = 2.0 ether / int256(365 days);
    /// @dev 4:1
    int256 constant slope = 4 ether;
    /// @dev 50%
    int256 constant adjustmentSpeed = 50 ether / int256(365 days);

    IRMAdaptiveLinearKink irm;
    IRMAdaptiveLinearKinkHarness harness;

    function setUp() public {
        irm = new IRMAdaptiveLinearKink(kink, initialKinkRate, minKinkRate, maxKinkRate, slope, adjustmentSpeed);
        harness = new IRMAdaptiveLinearKinkHarness(irm);
        targetContract(address(harness));
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IRMAdaptiveLinearKinkHarness.computeInterestRate.selector;
        targetSelector(FuzzSelector(address(harness), selectors));
    }

    function invariant_KinkRateAtLeastMinKinkRate() public {
        (int224 kinkRate, ) = irm.irState();
        assertGe(kinkRate, irm.minKinkRate());
    }

    function invariant_KinkRateAtMostMaxKinkRate() public {
        (int224 kinkRate, ) = irm.irState();
        assertLe(kinkRate, irm.maxKinkRate());
    }
}
