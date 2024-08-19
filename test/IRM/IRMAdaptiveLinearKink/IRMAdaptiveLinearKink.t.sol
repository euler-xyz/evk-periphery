// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IIRM} from "evk/InterestRateModels/IIRM.sol";
import {IRMAdaptiveLinearKink} from "../../../src/IRM/IRMAdaptiveLinearKink.sol";

contract IRMAdaptiveLinearKinkTest is Test {
    address constant VAULT = address(0x1234);

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

    function setUp() public {
        irm = new IRMAdaptiveLinearKink(kink, initialKinkRate, minKinkRate, maxKinkRate, slope, adjustmentSpeed);
        vm.startPrank(VAULT);
    }

    function test_OnlyVaultCanMutateIRMState() public {
        irm.computeInterestRate(VAULT, 5, 6);

        vm.expectRevert(IIRM.E_IRMUpdateUnauthorized.selector);
        vm.startPrank(address(0x2345));
        irm.computeInterestRate(VAULT, 5, 6);
    }

    function test_IRMCalculations() public {
        // First call returns `initialKinkRate.
        uint256 rate1 = computeRateAtUtilization(0.9e18);
        assertEq(rate1, uint256(initialKinkRate));

        // Utilization remains at `kink` so the rate remains at `initialKinkRate`.
        skip(1 minutes);
        uint256 rate2 = computeRateAtUtilization(0.9e18);
        assertEq(rate2, uint256(initialKinkRate));
        skip(365 days);
        uint256 rate3 = computeRateAtUtilization(0.9e18);
        assertEq(rate3, uint256(initialKinkRate));

        // Utilization climbs to 100% without time delay. The rate is 4x larger than initial.
        uint256 rate4 = computeRateAtUtilization(1e18);
        assertEq(rate4, uint256(slope * initialKinkRate / 1e18));

        // Utilization goes down to 0% without time delay. The rate is 4x smaller than initial.
        uint256 rate5 = computeRateAtUtilization(0);
        assertEq(rate5, uint256(1e18 * initialKinkRate / slope));

        // Utilization goes back to 90% without time delay. The rate is back at initial.
        uint256 rate6 = computeRateAtUtilization(0.9e18);
        assertEq(rate6, uint256(initialKinkRate));

        // Utilization climbs to 100% after 1 day.
        // The rate is 4x larger than initial + the whole curve has adjusted up.
        skip(1 days);
        uint256 rate7 = computeRateAtUtilization(1e18);
        assertGt(rate7, uint256(slope * initialKinkRate / 1e18));
        uint256 rate8 = computeRateAtUtilization(1e18);
        // Utilization goes back to 90% without time delay. The rate is back at initial + adjustment factor.
        uint256 rate9 = computeRateAtUtilization(0.9e18);
        assertEq(rate8, uint256(slope) * rate9 / 1e18);
    }

    function computeRateAtUtilization(uint256 utilizationRate) internal returns (uint256) {
        if (utilizationRate == 0) return irm.computeInterestRate(VAULT, 0, 0);
        if (utilizationRate == 1e18) return irm.computeInterestRate(VAULT, 0, 1e18);

        uint256 borrows = 1e18 * utilizationRate / (1e18 - utilizationRate);
        return irm.computeInterestRate(VAULT, 1e18, borrows);
    }
}