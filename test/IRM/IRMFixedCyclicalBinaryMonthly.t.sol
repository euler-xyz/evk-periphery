// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IIRM} from "evk/InterestRateModels/IIRM.sol";
import {IRMFixedCyclicalBinaryMonthly} from "../../src/IRM/IRMFixedCyclicalBinaryMonthly.sol";
import {EulerKinkIRMFactory} from "../../src/IRMFactory/EulerKinkIRMFactory.sol";
import {EulerKinkyIRMFactory} from "../../src/IRMFactory/EulerKinkyIRMFactory.sol";
import {EulerIRMAdaptiveCurveFactory} from "../../src/IRMFactory/EulerIRMAdaptiveCurveFactory.sol";
import {EulerFixedCyclicalBinaryIRMFactory} from "../../src/IRMFactory/EulerFixedCyclicalBinaryIRMFactory.sol";
import {IRMLens} from "../../src/Lens/IRMLens.sol";
import {
    InterestRateModelDetailedInfo,
    InterestRateModelType,
    FixedCyclicalBinaryMonthlyIRMInfo
} from "../../src/Lens/LensTypes.sol";

contract IRMFixedCyclicalBinaryMonthlyTest is Test {
    uint256 constant PRIMARY_RATE = 1;
    uint256 constant SECONDARY_RATE = 2;

    // Reference UTC timestamps (computed off-chain, verified against Python datetime).
    uint256 constant TS_2024_01_01 = 1704067200;
    uint256 constant TS_2024_01_30 = 1706572800;
    uint256 constant TS_2024_01_31 = 1706659200;
    uint256 constant TS_2024_01_31_END = 1706745599;
    uint256 constant TS_2024_02_01 = 1706745600;
    uint256 constant TS_2024_02_28 = 1709078400;
    uint256 constant TS_2024_02_29 = 1709164800;
    uint256 constant TS_2024_02_29_END = 1709251199;
    uint256 constant TS_2024_03_01 = 1709251200;
    uint256 constant TS_2024_04_29 = 1714348800;
    uint256 constant TS_2024_04_30 = 1714435200;
    uint256 constant TS_2024_05_01 = 1714521600;
    uint256 constant TS_2024_12_30 = 1735516800;
    uint256 constant TS_2024_12_31 = 1735603200;
    uint256 constant TS_2024_12_31_END = 1735689599;
    uint256 constant TS_2025_01_01 = 1735689600;
    uint256 constant TS_2025_02_27 = 1740614400;
    uint256 constant TS_2025_02_28 = 1740700800;
    uint256 constant TS_2025_03_01 = 1740787200;
    uint256 constant TS_2000_02_28 = 951696000;
    uint256 constant TS_2000_02_29 = 951782400;
    uint256 constant TS_2000_03_01 = 951868800;
    uint256 constant TS_2100_02_27 = 4107369600;
    uint256 constant TS_2100_02_28 = 4107456000;
    uint256 constant TS_2100_03_01 = 4107542400;

    IRMFixedCyclicalBinaryMonthly irm;

    function setUp() public {
        // cycleStartDay = 1, secondaryDays = 1 — equivalent to the legacy "last day of month = secondary"
        // behavior, so the bulk of existing tests below remain valid.
        irm = new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 1, 1);
    }

    // ───── construction ─────

    function test_Construction_StoresImmutables() public view {
        assertEq(irm.primaryRate(), PRIMARY_RATE);
        assertEq(irm.secondaryRate(), SECONDARY_RATE);
        assertEq(irm.cycleStartDay(), 1);
        assertEq(irm.secondaryDays(), 1);
    }

    function test_Construction_RevertsOnZeroCycleStartDay() public {
        vm.expectRevert(IRMFixedCyclicalBinaryMonthly.BadCycleStartDay.selector);
        new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 0, 1);
    }

    function test_Construction_RevertsOnCycleStartDayTooHigh() public {
        vm.expectRevert(IRMFixedCyclicalBinaryMonthly.BadCycleStartDay.selector);
        new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 29, 1);
    }

    function test_Construction_RevertsOnZeroSecondaryDays() public {
        vm.expectRevert(IRMFixedCyclicalBinaryMonthly.BadSecondaryDays.selector);
        new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 1, 0);
    }

    function test_Construction_RevertsOnSecondaryDaysTooHigh() public {
        vm.expectRevert(IRMFixedCyclicalBinaryMonthly.BadSecondaryDays.selector);
        new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 1, 28);
    }

    function test_Construction_AcceptsBoundaryParameters() public {
        // cycleStartDay boundaries: 1 and 28.
        new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 1, 1);
        new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 28, 1);
        // secondaryDays boundaries: 1 and 27.
        new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 1, 27);
        new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 28, 27);
    }

    function test_Construction_AcceptsArbitrarilyHighRates() public {
        // No rate cap in this contract; the curator is trusted to set sensible rates.
        new IRMFixedCyclicalBinaryMonthly(type(uint256).max, type(uint256).max, 1, 1);
    }

    // ───── authorization ─────

    function test_OnlyVaultCanCallComputeInterestRate() public {
        vm.warp(TS_2024_01_01);
        vm.expectRevert(IIRM.E_IRMUpdateUnauthorized.selector);
        irm.computeInterestRate(address(1234), 5, 6);

        vm.prank(address(1234));
        irm.computeInterestRate(address(1234), 5, 6);
    }

    function test_ComputeInterestRateViewIsPermissionless() public {
        vm.warp(TS_2024_01_01);
        irm.computeInterestRateView(address(0xBEEF), 0, 0);
    }

    // ───── rate switching, secondaryDays = 1 ─────

    function test_LastDayJanuary2024_Secondary() public {
        // secondaryDays = 1: only the last day of the month flips.
        vm.warp(TS_2024_01_30);
        assertEq(_ir(), PRIMARY_RATE);

        vm.warp(TS_2024_01_31);
        assertEq(_ir(), SECONDARY_RATE);

        vm.warp(TS_2024_01_31_END);
        assertEq(_ir(), SECONDARY_RATE);

        vm.warp(TS_2024_02_01);
        assertEq(_ir(), PRIMARY_RATE);
    }

    function test_LeapYear_LastDayFebruary2024() public {
        vm.warp(TS_2024_02_28);
        assertEq(_ir(), PRIMARY_RATE, "Feb 28 of leap year is not the last day");

        vm.warp(TS_2024_02_29);
        assertEq(_ir(), SECONDARY_RATE, "Feb 29 of leap year is the last day");

        vm.warp(TS_2024_02_29_END);
        assertEq(_ir(), SECONDARY_RATE);

        vm.warp(TS_2024_03_01);
        assertEq(_ir(), PRIMARY_RATE);
    }

    function test_NonLeapYear_LastDayFebruary2025() public {
        vm.warp(TS_2025_02_27);
        assertEq(_ir(), PRIMARY_RATE);

        vm.warp(TS_2025_02_28);
        assertEq(_ir(), SECONDARY_RATE);

        vm.warp(TS_2025_03_01);
        assertEq(_ir(), PRIMARY_RATE);
    }

    function test_FourHundredYearLeap_Feb29_2000() public {
        vm.warp(TS_2000_02_28);
        assertEq(_ir(), PRIMARY_RATE, "Feb 28, 2000 is not the last day (year-2000 is leap)");

        vm.warp(TS_2000_02_29);
        assertEq(_ir(), SECONDARY_RATE);

        vm.warp(TS_2000_03_01);
        assertEq(_ir(), PRIMARY_RATE);
    }

    function test_CenturyNonLeap_Feb28_2100() public {
        // Year 2100 is divisible by 100 but not by 400 → non-leap. Feb 28 is the last day.
        vm.warp(TS_2100_02_27);
        assertEq(_ir(), PRIMARY_RATE);

        vm.warp(TS_2100_02_28);
        assertEq(_ir(), SECONDARY_RATE);

        vm.warp(TS_2100_03_01);
        assertEq(_ir(), PRIMARY_RATE);
    }

    function test_ThirtyDayMonth_April2024() public {
        vm.warp(TS_2024_04_29);
        assertEq(_ir(), PRIMARY_RATE);

        vm.warp(TS_2024_04_30);
        assertEq(_ir(), SECONDARY_RATE);

        vm.warp(TS_2024_05_01);
        assertEq(_ir(), PRIMARY_RATE);
    }

    function test_YearBoundary_December2024() public {
        vm.warp(TS_2024_12_30);
        assertEq(_ir(), PRIMARY_RATE);

        vm.warp(TS_2024_12_31);
        assertEq(_ir(), SECONDARY_RATE);

        vm.warp(TS_2024_12_31_END);
        assertEq(_ir(), SECONDARY_RATE);

        vm.warp(TS_2025_01_01);
        assertEq(_ir(), PRIMARY_RATE);
    }

    function test_MidnightTransition_FlipsExactlyOnSecondBoundary() public {
        // Secondary window starts the moment Jan 30 ends and Jan 31 begins (UTC).
        vm.warp(TS_2024_01_31 - 1);
        assertEq(_ir(), PRIMARY_RATE);

        vm.warp(TS_2024_01_31);
        assertEq(_ir(), SECONDARY_RATE);
    }

    // ───── every month of a leap year ─────

    function test_AllMonths_2024_LeapYear_LastDayBoundaries() public {
        uint256[12] memory lastDays = [uint256(31), 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

        for (uint256 m = 1; m <= 12; ++m) {
            uint256 last = lastDays[m - 1];

            // Penultimate day is primary.
            vm.warp(_ts(2024, m, last - 1));
            assertEq(_ir(), PRIMARY_RATE, _label("2024 last-1", m));

            // Last day is secondary.
            vm.warp(_ts(2024, m, last));
            assertEq(_ir(), SECONDARY_RATE, _label("2024 last", m));

            // Day 1 of the following month is primary again (handle Dec → Jan rollover).
            if (m == 12) {
                vm.warp(_ts(2025, 1, 1));
            } else {
                vm.warp(_ts(2024, m + 1, 1));
            }
            assertEq(_ir(), PRIMARY_RATE, _label("2024 next-month-day-1", m));
        }
    }

    // ───── every month of a non-leap year ─────

    function test_AllMonths_2023_NonLeapYear_LastDayBoundaries() public {
        uint256[12] memory lastDays = [uint256(31), 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

        for (uint256 m = 1; m <= 12; ++m) {
            uint256 last = lastDays[m - 1];

            vm.warp(_ts(2023, m, last - 1));
            assertEq(_ir(), PRIMARY_RATE, _label("2023 last-1", m));

            vm.warp(_ts(2023, m, last));
            assertEq(_ir(), SECONDARY_RATE, _label("2023 last", m));

            if (m == 12) {
                vm.warp(_ts(2024, 1, 1));
            } else {
                vm.warp(_ts(2023, m + 1, 1));
            }
            assertEq(_ir(), PRIMARY_RATE, _label("2023 next-month-day-1", m));
        }
    }

    // ───── leap year detection across many years ─────

    function test_LeapYearDetection_RegularLeapYears() public {
        // Divisible by 4 but not 100 — standard leap years.
        uint256[7] memory ys = [uint256(1972), 1984, 1996, 2004, 2020, 2024, 2096];

        for (uint256 i = 0; i < ys.length; ++i) {
            uint256 y = ys[i];
            vm.warp(_ts(y, 2, 28));
            assertEq(_ir(), PRIMARY_RATE, "Feb 28 of a leap year is not the last day");

            vm.warp(_ts(y, 2, 29));
            assertEq(_ir(), SECONDARY_RATE, "Feb 29 of a leap year is the last day");

            vm.warp(_ts(y, 3, 1));
            assertEq(_ir(), PRIMARY_RATE, "March 1 is primary");
        }
    }

    function test_LeapYearDetection_FourHundredYearLeaps() public {
        // Divisible by 400 — leap (overrides century rule). 2000 already covered separately.
        uint256[3] memory ys = [uint256(2000), 2400, 2800];

        for (uint256 i = 0; i < ys.length; ++i) {
            uint256 y = ys[i];
            vm.warp(_ts(y, 2, 29));
            assertEq(_ir(), SECONDARY_RATE, "400-year leap should have Feb 29 as last day");

            vm.warp(_ts(y, 3, 1));
            assertEq(_ir(), PRIMARY_RATE);
        }
    }

    function test_NonLeapYearDetection_CenturyYears() public {
        // Divisible by 100 but not 400 — non-leap. Feb 28 must be the last day.
        uint256[4] memory ys = [uint256(2100), 2200, 2300, 2500];

        for (uint256 i = 0; i < ys.length; ++i) {
            uint256 y = ys[i];
            vm.warp(_ts(y, 2, 27));
            assertEq(_ir(), PRIMARY_RATE, "Feb 27 of a non-leap century is primary");

            vm.warp(_ts(y, 2, 28));
            assertEq(_ir(), SECONDARY_RATE, "Feb 28 of a non-leap century is the last day");

            vm.warp(_ts(y, 3, 1));
            assertEq(_ir(), PRIMARY_RATE);
        }
    }

    function test_NonLeapYearDetection_RegularYears() public {
        // Not divisible by 4 — non-leap.
        uint256[7] memory ys = [uint256(1971), 1973, 2001, 2023, 2025, 2099, 2500];

        for (uint256 i = 0; i < ys.length; ++i) {
            uint256 y = ys[i];
            vm.warp(_ts(y, 2, 28));
            assertEq(_ir(), SECONDARY_RATE, "Feb 28 of a non-leap year is the last day");

            vm.warp(_ts(y, 3, 1));
            assertEq(_ir(), PRIMARY_RATE);
        }
    }

    // ───── epoch and far-future ─────

    function test_EpochBoundary_1970() public {
        // Unix epoch is 1970-01-01 — first day, primary.
        vm.warp(_ts(1970, 1, 1));
        assertEq(_ir(), PRIMARY_RATE);

        vm.warp(_ts(1970, 1, 31));
        assertEq(_ir(), SECONDARY_RATE);

        vm.warp(_ts(1970, 2, 1));
        assertEq(_ir(), PRIMARY_RATE);

        vm.warp(_ts(1970, 2, 28));
        assertEq(_ir(), SECONDARY_RATE, "1970 is not a leap year, Feb 28 is last");
    }

    function test_FarFuture_Years() public {
        // Sample years well past current cutoff to exercise the Hinnant algorithm beyond the current era.
        uint256[5] memory ys = [uint256(2500), 2700, 3000, 3500, 4000];

        for (uint256 i = 0; i < ys.length; ++i) {
            uint256 y = ys[i];

            vm.warp(_ts(y, 1, 31));
            assertEq(_ir(), SECONDARY_RATE);

            vm.warp(_ts(y, 6, 30));
            assertEq(_ir(), SECONDARY_RATE, "June has 30 days");

            vm.warp(_ts(y, 6, 29));
            assertEq(_ir(), PRIMARY_RATE);

            vm.warp(_ts(y, 7, 31));
            assertEq(_ir(), SECONDARY_RATE, "July has 31 days");

            vm.warp(_ts(y, 12, 31));
            assertEq(_ir(), SECONDARY_RATE);
        }
    }

    // ───── mid-month sampling: many random non-last days stay primary ─────

    function test_MidMonthDays_AcrossManyMonths_StayPrimary() public {
        uint256[5] memory sampleYears = [uint256(1985), 2000, 2024, 2099, 3000];

        for (uint256 yi = 0; yi < sampleYears.length; ++yi) {
            uint256 y = sampleYears[yi];

            for (uint256 m = 1; m <= 12; ++m) {
                // Mid-month days: 1, 7, 14, 21. All firmly inside the primary window for secondaryDays=1.
                uint256[4] memory daySamples = [uint256(1), 7, 14, 21];

                for (uint256 di = 0; di < daySamples.length; ++di) {
                    vm.warp(_ts(y, m, daySamples[di]));
                    assertEq(_ir(), PRIMARY_RATE);
                }
            }
        }
    }

    // ───── independent timestamp anchors ─────

    // The fuzz test below builds timestamps via `_ts`, which is the inverse of the production Hinnant
    // forward conversion in the IRM. A mirrored bug in the shared constants could theoretically evade
    // that check. This anchor test breaks the symmetry: every `(ts, year, month, day)` row was computed
    // externally by Python's `datetime` and is hard-coded — the test path never invokes `_ts` or any
    // Hinnant-derived helper. The expected rate is derived from `_refLastDayOfMonth` (also independent).
    struct Anchor {
        uint256 ts;
        uint256 year;
        uint256 month;
        uint256 day;
    }

    function test_IndependentTimestampAnchors() public {
        Anchor[33] memory anchors = [
            Anchor(0, 1970, 1, 1),
            Anchor(2592000, 1970, 1, 31),
            Anchor(2678400, 1970, 2, 1),
            Anchor(5011200, 1970, 2, 28),
            Anchor(68083200, 1972, 2, 28),
            Anchor(68169600, 1972, 2, 29),
            Anchor(68256000, 1972, 3, 1),
            Anchor(946598400, 1999, 12, 31),
            Anchor(946684800, 2000, 1, 1),
            Anchor(951696000, 2000, 2, 28),
            Anchor(951782400, 2000, 2, 29),
            Anchor(951868800, 2000, 3, 1),
            Anchor(1588204800, 2020, 4, 30),
            Anchor(1588291200, 2020, 5, 1),
            Anchor(1706659200, 2024, 1, 31),
            Anchor(1709164800, 2024, 2, 29),
            Anchor(1719705600, 2024, 6, 30),
            Anchor(1719792000, 2024, 7, 1),
            Anchor(1725062400, 2024, 8, 31),
            Anchor(1732924800, 2024, 11, 30),
            Anchor(1740700800, 2025, 2, 28),
            Anchor(1740787200, 2025, 3, 1),
            Anchor(4102358400, 2099, 12, 31),
            Anchor(4102444800, 2100, 1, 1),
            Anchor(4107369600, 2100, 2, 27),
            Anchor(4107456000, 2100, 2, 28),
            Anchor(4107542400, 2100, 3, 1),
            Anchor(13574563200, 2400, 2, 29),
            Anchor(13574649600, 2400, 3, 1),
            Anchor(32503680000, 3000, 1, 1),
            Anchor(32535129600, 3000, 12, 31),
            Anchor(64074931200, 4000, 6, 15),
            Anchor(64076313600, 4000, 7, 1)
        ];

        // setUp's `irm` uses secondaryDays = 1.
        for (uint256 i = 0; i < anchors.length; ++i) {
            Anchor memory a = anchors[i];
            uint256 last = _refLastDayOfMonth(a.year, a.month);
            uint256 expected = a.day == last ? SECONDARY_RATE : PRIMARY_RATE;

            vm.warp(a.ts);
            assertEq(
                _ir(),
                expected,
                string.concat("anchor i=", vm.toString(i), " ts=", vm.toString(a.ts))
            );
        }
    }

    // ───── fuzz: rate classification matches independent calendar math across the whole range ─────

    // Note: this fuzz uses `_ts` to build timestamps, which is the inverse of the IRM's Hinnant forward
    // conversion. Mirrored bugs in shared constants could theoretically escape this check; the
    // `test_IndependentTimestampAnchors` test above (hard-coded externally-computed timestamps)
    // breaks that symmetry.
    function test_Fuzz_RateClassificationMatchesDateMath(
        uint256 yearRaw,
        uint256 monthRaw,
        uint256 dayRaw,
        uint256 cycleStartRaw,
        uint256 secDaysRaw
    ) public {
        uint256 year = bound(yearRaw, 1970, 4000);
        uint256 month = bound(monthRaw, 1, 12);
        uint256 cycleStart = bound(cycleStartRaw, 1, 28);
        uint256 secDays = bound(secDaysRaw, 1, 27);
        uint256 lastDay = _refLastDayOfMonth(year, month);
        uint256 day = bound(dayRaw, 1, lastDay);

        IRMFixedCyclicalBinaryMonthly fuzzIrm =
            new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, cycleStart, secDays);
        vm.warp(_ts(year, month, day));

        // Independent reproduction of the IRM's classification rule.
        uint256 daysUntilNext = day < cycleStart ? cycleStart - day : (lastDay - day) + cycleStart;
        uint256 expected = daysUntilNext <= secDays ? SECONDARY_RATE : PRIMARY_RATE;
        assertEq(_irOf(fuzzIrm), expected);
    }

    // ───── rate switching, secondaryDays > 1 ─────

    function test_SecondaryDaysThree_LastThreeDaysSecondary() public {
        IRMFixedCyclicalBinaryMonthly irm3 = new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 1, 3);

        // January 2024 has 31 days → days 29, 30, 31 are secondary; 28 is primary.
        vm.warp(_ts(2024, 1, 28));
        assertEq(_irOf(irm3), PRIMARY_RATE);

        vm.warp(_ts(2024, 1, 29));
        assertEq(_irOf(irm3), SECONDARY_RATE);

        vm.warp(_ts(2024, 1, 30));
        assertEq(_irOf(irm3), SECONDARY_RATE);

        vm.warp(_ts(2024, 1, 31));
        assertEq(_irOf(irm3), SECONDARY_RATE);

        vm.warp(_ts(2024, 2, 1));
        assertEq(_irOf(irm3), PRIMARY_RATE);
    }

    function test_SecondaryDaysThree_FebruaryLeap() public {
        IRMFixedCyclicalBinaryMonthly irm3 = new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 1, 3);

        // Feb 2024 has 29 days → days 27, 28, 29 are secondary; 26 is primary.
        vm.warp(_ts(2024, 2, 26));
        assertEq(_irOf(irm3), PRIMARY_RATE);

        vm.warp(_ts(2024, 2, 27));
        assertEq(_irOf(irm3), SECONDARY_RATE);

        vm.warp(_ts(2024, 2, 28));
        assertEq(_irOf(irm3), SECONDARY_RATE);

        vm.warp(_ts(2024, 2, 29));
        assertEq(_irOf(irm3), SECONDARY_RATE);
    }

    function test_SecondaryDaysTwentySeven_FebruaryNonLeap_Day1Primary() public {
        // The extreme case: in a 28-day Feb with secondaryDays=27, only day 1 is primary.
        IRMFixedCyclicalBinaryMonthly irm27 = new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 1, 27);

        vm.warp(_ts(2025, 2, 1));
        assertEq(_irOf(irm27), PRIMARY_RATE, "Feb 1 non-leap should be primary");

        vm.warp(_ts(2025, 2, 2));
        assertEq(_irOf(irm27), SECONDARY_RATE);

        vm.warp(_ts(2025, 2, 28));
        assertEq(_irOf(irm27), SECONDARY_RATE);
    }

    // ───── cycleStartDay variations ─────

    function test_CycleStartDay15_SecondaryDays3_SecondaryIsDays12To14() public {
        // Cycle starts on the 15th of every month, repayment period = 3 days. Secondary = days 12, 13, 14.
        IRMFixedCyclicalBinaryMonthly irmMid = new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 15, 3);

        vm.warp(_ts(2024, 6, 11));
        assertEq(_irOf(irmMid), PRIMARY_RATE, "day 11 is outside the 3-day pre-cycle window");

        vm.warp(_ts(2024, 6, 12));
        assertEq(_irOf(irmMid), SECONDARY_RATE);

        vm.warp(_ts(2024, 6, 13));
        assertEq(_irOf(irmMid), SECONDARY_RATE);

        vm.warp(_ts(2024, 6, 14));
        assertEq(_irOf(irmMid), SECONDARY_RATE);

        vm.warp(_ts(2024, 6, 15));
        assertEq(_irOf(irmMid), PRIMARY_RATE, "day 15 is the cycle start (primary)");

        vm.warp(_ts(2024, 6, 30));
        assertEq(_irOf(irmMid), PRIMARY_RATE, "end of June is mid-cycle");

        vm.warp(_ts(2024, 7, 1));
        assertEq(_irOf(irmMid), PRIMARY_RATE, "July 1 is still mid-cycle for cycleStart=15");
    }

    function test_CycleStartDay5_SecondaryDays7_SpansMonthBoundary_31DayMonth() public {
        // Cycle starts on the 5th, repayment 7 days. In a 31-day month, secondary = last 3 days of
        // previous month (29, 30, 31) plus days 1-4 of the current month — 7 days total spanning the
        // month boundary.
        IRMFixedCyclicalBinaryMonthly irmBoundary = new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 5, 7);

        // March (31 days) into April. Secondary window ends just before April 5.
        vm.warp(_ts(2024, 3, 28));
        assertEq(_irOf(irmBoundary), PRIMARY_RATE, "Mar 28: 8 days until next cycle start");

        vm.warp(_ts(2024, 3, 29));
        assertEq(_irOf(irmBoundary), SECONDARY_RATE, "Mar 29: 7 days until cycle start (Apr 5)");

        vm.warp(_ts(2024, 3, 30));
        assertEq(_irOf(irmBoundary), SECONDARY_RATE);

        vm.warp(_ts(2024, 3, 31));
        assertEq(_irOf(irmBoundary), SECONDARY_RATE);

        vm.warp(_ts(2024, 4, 1));
        assertEq(_irOf(irmBoundary), SECONDARY_RATE, "Apr 1: still in secondary window");

        vm.warp(_ts(2024, 4, 4));
        assertEq(_irOf(irmBoundary), SECONDARY_RATE);

        vm.warp(_ts(2024, 4, 5));
        assertEq(_irOf(irmBoundary), PRIMARY_RATE, "Apr 5: cycle start");
    }

    function test_CycleStartDay5_SecondaryDays7_SpansMonthBoundary_FebNonLeap() public {
        // Same config, but the previous month is February non-leap (28 days). Secondary = last 5 days
        // of Feb (24..28) plus first 4 of Mar — but only the last 3 of Feb fall in the 7-day window.
        // Window math: from Feb 28 to Mar 5 is 5 days; we need 7 days back, so window starts on Feb 26.
        IRMFixedCyclicalBinaryMonthly irmBoundary = new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 5, 7);

        vm.warp(_ts(2025, 2, 25));
        assertEq(_irOf(irmBoundary), PRIMARY_RATE, "Feb 25: 8 days until Mar 5");

        vm.warp(_ts(2025, 2, 26));
        assertEq(_irOf(irmBoundary), SECONDARY_RATE, "Feb 26: 7 days until Mar 5");

        vm.warp(_ts(2025, 2, 28));
        assertEq(_irOf(irmBoundary), SECONDARY_RATE);

        vm.warp(_ts(2025, 3, 1));
        assertEq(_irOf(irmBoundary), SECONDARY_RATE);

        vm.warp(_ts(2025, 3, 4));
        assertEq(_irOf(irmBoundary), SECONDARY_RATE);

        vm.warp(_ts(2025, 3, 5));
        assertEq(_irOf(irmBoundary), PRIMARY_RATE, "Mar 5: cycle start");
    }

    function test_CycleStartDay28_SecondaryDays1_OnlyDay27IsSecondary() public {
        // Cycle starts on the 28th (max allowed). Secondary = day 27 only.
        IRMFixedCyclicalBinaryMonthly irmLate = new IRMFixedCyclicalBinaryMonthly(PRIMARY_RATE, SECONDARY_RATE, 28, 1);

        vm.warp(_ts(2024, 6, 26));
        assertEq(_irOf(irmLate), PRIMARY_RATE);

        vm.warp(_ts(2024, 6, 27));
        assertEq(_irOf(irmLate), SECONDARY_RATE);

        vm.warp(_ts(2024, 6, 28));
        assertEq(_irOf(irmLate), PRIMARY_RATE, "day 28 is the cycle start (primary)");

        vm.warp(_ts(2024, 6, 30));
        assertEq(_irOf(irmLate), PRIMARY_RATE);

        // Feb non-leap: day 27 still secondary, day 28 still cycle start primary.
        vm.warp(_ts(2025, 2, 27));
        assertEq(_irOf(irmLate), SECONDARY_RATE);

        vm.warp(_ts(2025, 2, 28));
        assertEq(_irOf(irmLate), PRIMARY_RATE);
    }

    // ───── name ─────

    function test_Name_ReturnsExpectedString() public view {
        assertEq(irm.name(), "IRMFixedCyclicalBinaryMonthly");
    }

    // ───── IRMLens integration: self-identifying fallback ─────

    function test_IRMLens_RecognizesMonthlyViaName() public {
        IRMLens lens = _deployLens();
        InterestRateModelDetailedInfo memory info = lens.getInterestRateModelInfo(address(irm));

        assertEq(uint256(info.interestRateModelType), uint256(InterestRateModelType.FIXED_CYCLICAL_BINARY_MONTHLY));
        assertEq(info.interestRateModel, address(irm));

        FixedCyclicalBinaryMonthlyIRMInfo memory params =
            abi.decode(info.interestRateModelParams, (FixedCyclicalBinaryMonthlyIRMInfo));

        assertEq(params.primaryRate, PRIMARY_RATE);
        assertEq(params.secondaryRate, SECONDARY_RATE);
        assertEq(params.cycleStartDay, 1);
        assertEq(params.secondaryDays, 1);
    }

    function test_IRMLens_ContractWithoutNameClassifiedAsUnknown() public {
        IRMLens lens = _deployLens();

        // Contract with no name() function — staticcall reverts (no matching selector, no fallback).
        EmptyContract empty = new EmptyContract();
        InterestRateModelDetailedInfo memory info = lens.getInterestRateModelInfo(address(empty));
        assertEq(uint256(info.interestRateModelType), uint256(InterestRateModelType.UNKNOWN));
        assertEq(info.interestRateModelParams.length, 0);
    }

    function test_IRMLens_UnrecognizedNameClassifiedAsUnknown() public {
        IRMLens lens = _deployLens();

        NamedDummy dummy = new NamedDummy("SomeOtherIRMFlavour");
        InterestRateModelDetailedInfo memory info = lens.getInterestRateModelInfo(address(dummy));
        assertEq(uint256(info.interestRateModelType), uint256(InterestRateModelType.UNKNOWN));
        assertEq(info.interestRateModelParams.length, 0);
    }

    function test_IRMLens_RevertingNameClassifiedAsUnknown() public {
        IRMLens lens = _deployLens();

        RevertingDummy dummy = new RevertingDummy();
        InterestRateModelDetailedInfo memory info = lens.getInterestRateModelInfo(address(dummy));
        assertEq(uint256(info.interestRateModelType), uint256(InterestRateModelType.UNKNOWN));
    }

    function test_IRMLens_ShortReturnDataClassifiedAsUnknown() public {
        IRMLens lens = _deployLens();

        // Contract whose name() returns less than 32 bytes — the data.length >= 32 gate skips decoding.
        ShortReturnDummy dummy = new ShortReturnDummy();
        InterestRateModelDetailedInfo memory info = lens.getInterestRateModelInfo(address(dummy));
        assertEq(uint256(info.interestRateModelType), uint256(InterestRateModelType.UNKNOWN));
    }

    function test_IRMLens_ZeroAddressReturnsEmpty() public {
        IRMLens lens = _deployLens();
        InterestRateModelDetailedInfo memory info = lens.getInterestRateModelInfo(address(0));
        assertEq(info.interestRateModel, address(0));
        assertEq(uint256(info.interestRateModelType), uint256(InterestRateModelType.UNKNOWN));
    }

    // ───── helpers ─────

    function _ir() private view returns (uint256) {
        return irm.computeInterestRateView(address(1), 0, 0);
    }

    function _irOf(IRMFixedCyclicalBinaryMonthly target) private view returns (uint256) {
        return target.computeInterestRateView(address(1), 0, 0);
    }

    function _deployLens() private returns (IRMLens) {
        EulerKinkIRMFactory kink = new EulerKinkIRMFactory();
        EulerIRMAdaptiveCurveFactory adaptive = new EulerIRMAdaptiveCurveFactory();
        EulerKinkyIRMFactory kinky = new EulerKinkyIRMFactory();
        EulerFixedCyclicalBinaryIRMFactory fixedCyclical = new EulerFixedCyclicalBinaryIRMFactory();
        return new IRMLens(address(kink), address(adaptive), address(kinky), address(fixedCyclical));
    }

    /// @dev Independent reference implementation of last-day-of-month for the fuzz oracle. Intentionally
    /// duplicated from the IRM (rather than reused) so a bug in the IRM's logic can't cancel out in the test.
    function _refLastDayOfMonth(uint256 year, uint256 month) internal pure returns (uint256) {
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            return 31;
        }
        if (month == 4 || month == 6 || month == 9 || month == 11) {
            return 30;
        }
        // February
        bool isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
        return isLeap ? 29 : 28;
    }

    function _label(string memory prefix, uint256 month) internal pure returns (string memory) {
        return string.concat(prefix, " month=", vm.toString(month));
    }

    /// @dev Compute UTC midnight Unix timestamp for a given Gregorian (year, month, day). Only valid for
    /// `(y, m, d) >= (1970, 1, 1)` — earlier dates would correspond to negative Unix time and underflow in
    /// uint256. The IRM itself has no such restriction because it only consumes positive `block.timestamp`.
    function _ts(uint256 y, uint256 m, uint256 d) internal pure returns (uint256) {
        // Inverse of Howard Hinnant's civil_from_days: days_from_civil.
        if (m <= 2) y -= 1;
        uint256 era = y / 400;
        uint256 yoe = y - era * 400;
        uint256 doy = (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1;
        uint256 doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
        uint256 daysFromEpoch = era * 146097 + doe - 719468;
        return daysFromEpoch * 86400;
    }
}

contract EmptyContract {}

contract NamedDummy {
    string private _name;

    constructor(string memory n) {
        _name = n;
    }

    function name() external view returns (string memory) {
        return _name;
    }
}

contract RevertingDummy {
    function name() external pure returns (string memory) {
        revert("nope");
    }
}

contract ShortReturnDummy {
    // Returns fewer than 32 bytes, exercising the data.length >= 32 gate in the IRMLens fallback.
    fallback(bytes calldata) external returns (bytes memory) {
        return hex"deadbeef";
    }
}
