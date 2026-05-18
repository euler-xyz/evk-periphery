// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IIRM} from "evk/InterestRateModels/IIRM.sol";
import {IIRMNamed} from "./interfaces/IIRMNamed.sol";

/// @title IRMFixedCyclicalBinaryMonthly
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Interest rate model that cycles between two fixed rates with a monthly cadence aligned to UTC.
/// @dev Each calendar month starts a new cycle on day-of-month `cycleStartDay`. The `secondaryDays`
/// calendar days immediately BEFORE each cycle start return `secondaryRate` (the "repayment" window);
/// every other day returns `primaryRate`. The secondary window can span month boundaries — e.g. with
/// `cycleStartDay = 1` and `secondaryDays = 1`, the last day of every month returns `secondaryRate`.
/// Day boundaries are calendar days in UTC, computed deterministically from `block.timestamp` using
/// Howard Hinnant's `civil_from_days` algorithm (https://howardhinnant.github.io/date_algorithms.html);
/// no oracle or external state is involved.
contract IRMFixedCyclicalBinaryMonthly is IIRM, IIRMNamed {
    /// @notice Interest rate applied outside the secondary (repayment) window.
    uint256 public immutable primaryRate;
    /// @notice Interest rate applied during the secondary (repayment) window.
    uint256 public immutable secondaryRate;
    /// @notice Day-of-month on which a new cycle starts. Must be in `[1, MAX_CYCLE_START_DAY]`.
    uint256 public immutable cycleStartDay;
    /// @notice Number of calendar days immediately before each cycle start that use `secondaryRate`.
    /// Must be in `[1, MAX_SECONDARY_DAYS]`.
    uint256 public immutable secondaryDays;

    /// @notice Upper bound on `cycleStartDay`. Capped at 28 so the cycle start exists in every calendar
    /// month, including February in non-leap years.
    uint256 public constant MAX_CYCLE_START_DAY = 28;

    /// @notice Upper bound on `secondaryDays`. Capped at 27 so that the shortest calendar month
    /// (28-day February) still has at least one primary day per cycle.
    uint256 public constant MAX_SECONDARY_DAYS = 27;

    /// @notice Thrown when `cycleStartDay` is outside the valid range `[1, MAX_CYCLE_START_DAY]`.
    error BadCycleStartDay();
    /// @notice Thrown when `secondaryDays` is outside the valid range `[1, MAX_SECONDARY_DAYS]`.
    error BadSecondaryDays();

    /// @param primaryRate_ Interest rate used outside the secondary window.
    /// @param secondaryRate_ Interest rate used during the secondary window.
    /// @param cycleStartDay_ Day-of-month on which each cycle starts. Must be in `[1, MAX_CYCLE_START_DAY]`.
    /// @param secondaryDays_ Number of calendar days immediately before each cycle start that use
    /// `secondaryRate_`. Must be in `[1, MAX_SECONDARY_DAYS]`.
    constructor(uint256 primaryRate_, uint256 secondaryRate_, uint256 cycleStartDay_, uint256 secondaryDays_) {
        if (cycleStartDay_ == 0 || cycleStartDay_ > MAX_CYCLE_START_DAY) revert BadCycleStartDay();
        if (secondaryDays_ == 0 || secondaryDays_ > MAX_SECONDARY_DAYS) revert BadSecondaryDays();

        primaryRate = primaryRate_;
        secondaryRate = secondaryRate_;
        cycleStartDay = cycleStartDay_;
        secondaryDays = secondaryDays_;
    }

    /// @inheritdoc IIRM
    function computeInterestRate(address vault, uint256, uint256) external view override returns (uint256) {
        if (msg.sender != vault) revert E_IRMUpdateUnauthorized();

        return computeInterestRateInternal();
    }

    /// @inheritdoc IIRM
    function computeInterestRateView(address, uint256, uint256) external view override returns (uint256) {
        return computeInterestRateInternal();
    }

    /// @inheritdoc IIRMNamed
    function name() external pure override returns (string memory) {
        return "IRMFixedCyclicalBinaryMonthly";
    }

    function computeInterestRateInternal() internal view returns (uint256) {
        // `year` here is the Gregorian calendar year (post-shift), not Hinnant's March-anchored `y`.
        // `_lastDayOfMonth` relies on this for its leap-year rule, so do not refactor to pass `y`.
        (uint256 year, uint256 month, uint256 day) = _timestampToDate(block.timestamp);
        uint256 lastDay = _lastDayOfMonth(year, month);

        // Calendar days remaining until the next cycle start. If today is before `cycleStartDay` the
        // next start is later in the current month; otherwise it falls on `cycleStartDay` of the next
        // month and the secondary window can span the month boundary.
        uint256 daysUntilNextCycleStart =
            day < cycleStartDay ? cycleStartDay - day : (lastDay - day) + cycleStartDay;

        return daysUntilNextCycleStart <= secondaryDays ? secondaryRate : primaryRate;
    }

    /// @dev Converts a Unix timestamp (seconds, UTC) to a Gregorian (year, month, day).
    /// Implementation of Howard Hinnant's `civil_from_days` algorithm
    /// (https://howardhinnant.github.io/date_algorithms.html), adapted for unsigned integers — the C++
    /// reference's negative-`z` branch is unreachable here because `z = ts / 86400 + 719468 >= 719468 > 0`
    /// for any `uint256 ts`. All intermediates stay non-negative under Hinnant's invariants
    /// (`doe < 146097`, `yoe < 400`, `doy < 366`), so the body is safe under 0.8 checked arithmetic for
    /// every realistic `block.timestamp`.
    function _timestampToDate(uint256 ts) internal pure returns (uint256 year, uint256 month, uint256 day) {
        uint256 z = ts / 86400 + 719468;
        uint256 era = z / 146097;
        uint256 doe = z - era * 146097;
        uint256 yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
        uint256 y = yoe + era * 400;
        uint256 doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
        uint256 mp = (5 * doy + 2) / 153;
        day = doy - (153 * mp + 2) / 5 + 1;
        month = mp < 10 ? mp + 3 : mp - 9;
        year = y + (month <= 2 ? 1 : 0);
    }

    function _lastDayOfMonth(uint256 year, uint256 month) internal pure returns (uint256) {
        if (month == 2) {
            bool isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
            return isLeap ? 29 : 28;
        }
        if (month == 4 || month == 6 || month == 9 || month == 11) return 30;
        return 31;
    }
}
