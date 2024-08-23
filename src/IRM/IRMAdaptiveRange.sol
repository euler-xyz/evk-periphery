// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIRM} from "evk/InterestRateModels/IIRM.sol";

/// @title IRMAdaptiveRange
/// @custom:contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/).
/// @author Adapted from Frax
/// (https://github.com/FraxFinance/fraxlend/blob/main/src/contracts/VariableInterestRate.sol).
contract IRMAdaptiveRange is IIRM {
    /// @notice The lower bound of the utilization range where the full rate does not adjust.
    /// @dev In 1e18 units.
    uint256 public immutable MIN_TARGET_UTIL;
    /// @notice The upper bound of the utilization range where the full rate does not adjust.
    /// @dev In 1e18 units.
    uint256 public immutable MAX_TARGET_UTIL;
    /// @notice The utilization at which the slope increases.
    /// @dev In 1e18 units.
    uint256 public immutable VERTEX_UTILIZATION;
    /// @notice The precision of utilization calculations.
    uint256 public constant UTIL_PREC = 1e5;

    /// @notice The minimum interest rate at full utilization.
    /// @dev In 1e18 per second units.
    uint256 public immutable MIN_FULL_UTIL_RATE;
    /// @notice The maximum interest rate at full utilization.
    /// @dev In 1e18 per second units.
    uint256 public immutable MAX_FULL_UTIL_RATE;
    /// @notice The initial interest rate at full utilization.
    /// @dev In 1e18 per second units.
    uint256 public immutable INITIAL_FULL_UTIL_RATE;
    /// @notice The interest rate at zero utilization.
    /// @dev In 1e18 per second units.
    uint256 public immutable ZERO_UTIL_RATE;
    /// @notice The time it takes for the interest to halve/double when adjusting the curve.
    /// @dev In seconds.
    uint256 public immutable RATE_HALF_LIFE;
    /// @notice The percent of the delta between max and min.
    /// @dev In 1e18 units.
    uint256 public immutable VERTEX_RATE_PERCENT;
    /// @notice The precision of interest rate calculations
    uint256 public constant RATE_PREC = 1e18; // 18 decimals

    /// @notice Cached state of the interest rate model.
    struct IRState {
        /// @dev The current rate at full utilization.
        uint64 fullUtilizationInterest;
        /// @dev The timestamp of the last update to the model.
        uint48 lastUpdate;
    }

    /// @notice Get the cached state of a vault's irm.
    mapping(address => IRState) internal irState;

    /// @notice Deploy IRMAdaptiveRange.
    /// @param _vertexUtilization The utilization at which the slope increases.
    /// @param _vertexRatePercentOfDelta The percent of the delta between max and min, defines vertex rate.
    /// @param _minUtil The lower bound of the utilization range where the interest rate does not adjust.
    /// @param _maxUtil The upper bound of the utilization range where the interest rate does not adjust.
    /// @param _zeroUtilizationRate The interest rate at zero utilization.
    /// @param _minFullUtilizationRate The minimum interest rate at full utilization.
    /// @param _maxFullUtilizationRate The maximum interest rate at full utilization.
    /// @param _initialFullUtilizationRate The initial interest rate at full utilization.
    /// @param _rateHalfLife The time it takes for the interest to halve when adjusting the curve.
    /// rate.
    constructor(
        uint256 _vertexUtilization,
        uint256 _vertexRatePercentOfDelta,
        uint256 _minUtil,
        uint256 _maxUtil,
        uint256 _zeroUtilizationRate,
        uint256 _minFullUtilizationRate,
        uint256 _maxFullUtilizationRate,
        uint256 _initialFullUtilizationRate,
        uint256 _rateHalfLife
    ) {
        MIN_TARGET_UTIL = _minUtil;
        MAX_TARGET_UTIL = _maxUtil;
        VERTEX_UTILIZATION = _vertexUtilization;
        ZERO_UTIL_RATE = _zeroUtilizationRate;
        MIN_FULL_UTIL_RATE = _minFullUtilizationRate;
        MAX_FULL_UTIL_RATE = _maxFullUtilizationRate;
        INITIAL_FULL_UTIL_RATE = _initialFullUtilizationRate;
        RATE_HALF_LIFE = _rateHalfLife;
        VERTEX_RATE_PERCENT = _vertexRatePercentOfDelta;
    }

    /// @inheritdoc IIRM
    function computeInterestRate(address vault, uint256 cash, uint256 borrows) external returns (uint256) {
        if (msg.sender != vault) revert E_IRMUpdateUnauthorized();
        (uint256 rate, uint256 fullUtilizationInterest) = computeInterestRateInternal(vault, cash, borrows);
        irState[vault] = IRState(uint64(fullUtilizationInterest), uint48(block.timestamp));
        return rate;
    }

    /// @inheritdoc IIRM
    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external view returns (uint256) {
        (uint64 ratePerSec,) = computeInterestRateInternal(vault, cash, borrows);
        // Scale rate to 1e27 for EVK.
        return uint256(ratePerSec) * 1e9;
    }

    /// @notice Perform computation of the new full rate without mutating state.
    /// @param vault Address of the vault to compute the new interest rate for.
    /// @param cash Amount of assets held directly by the vault.
    /// @param borrows Amount of assets lent out to borrowers by the vault.
    /// @return Then new rate at 100% utilization in 1e18 per second units.
    function computeFullUtilizationInterestView(address vault, uint256 cash, uint256 borrows)
        external
        view
        returns (uint256)
    {
        (, uint64 fullUtilizationInterest) = computeInterestRateInternal(vault, cash, borrows);
        // Scale rate to 1e27 for EVK.
        return uint256(fullUtilizationInterest) * 1e9;
    }

    /// @notice Compute the current interest rate for a vault.
    /// @param vault Address of the vault to compute the new interest rate for.
    /// @param cash Amount of assets held directly by the vault.
    /// @param borrows Amount of assets lent out to borrowers by the vault.
    /// @return The new interest rate.
    /// @return The new interest rate at full utilization.
    function computeInterestRateInternal(address vault, uint256 cash, uint256 borrows)
        internal
        view
        returns (uint64, uint64)
    {
        // Calculate utilization rate.
        uint256 totalAssets = cash + borrows;
        uint256 utilization = totalAssets == 0 ? 0 : borrows * UTIL_PREC / totalAssets;

        // Initialize full rate if this is the first call.
        IRState memory state = irState[vault];
        if (state.lastUpdate == 0) {
            return getNewRate(0, utilization, uint64(INITIAL_FULL_UTIL_RATE));
        }

        // Calculate new interest rates.
        uint256 deltaTime = block.timestamp - state.lastUpdate;
        return getNewRate(deltaTime, utilization, state.fullUtilizationInterest);
    }

    /// @notice Calculate the new interest rate.
    /// @param _deltaTime The elapsed time since last update, given in seconds
    /// @param _utilization The utilization rate in 1e18.
    /// @param _oldFullUtilizationInterest The new interest rate at full utilization in 1e18.
    /// @return _newRatePerSec The new interest rate.
    /// @return _newFullUtilizationInterest The new interest rate at full utilization.
    function getNewRate(uint256 _deltaTime, uint256 _utilization, uint64 _oldFullUtilizationInterest)
        internal
        view
        returns (uint64 _newRatePerSec, uint64 _newFullUtilizationInterest)
    {
        _newFullUtilizationInterest = getFullUtilizationInterest(_deltaTime, _utilization, _oldFullUtilizationInterest);

        // _vertexInterest is calculated as the percentage of the delta between min and max interest
        uint256 _vertexInterest =
            (((_newFullUtilizationInterest - ZERO_UTIL_RATE) * VERTEX_RATE_PERCENT) / RATE_PREC) + ZERO_UTIL_RATE;
        if (_utilization < VERTEX_UTILIZATION) {
            // For readability, the following formula is equivalent to:
            // uint256 _slope = ((_vertexInterest - ZERO_UTIL_RATE) * UTIL_PREC) / VERTEX_UTILIZATION;
            // _newRatePerSec = uint64(ZERO_UTIL_RATE + ((_utilization * _slope) / UTIL_PREC));
            _newRatePerSec =
                uint64(ZERO_UTIL_RATE + (_utilization * (_vertexInterest - ZERO_UTIL_RATE)) / VERTEX_UTILIZATION);
        } else {
            // For readability, the following formula is equivalent to:
            // uint256 _slope = (((_newFullUtilizationInterest - _vertexInterest) * UTIL_PREC) / (UTIL_PREC -
            // VERTEX_UTILIZATION));
            // _newRatePerSec = uint64(_vertexInterest + (((_utilization - VERTEX_UTILIZATION) * _slope) / UTIL_PREC));
            _newRatePerSec = uint64(
                _vertexInterest
                    + ((_utilization - VERTEX_UTILIZATION) * (_newFullUtilizationInterest - _vertexInterest))
                        / (UTIL_PREC - VERTEX_UTILIZATION)
            );
        }
    }

    /// @notice Calculate the new maximum interest rate, i.e. rate when utilization is 100%
    /// @param _deltaTime The elapsed time since last update given in seconds.
    /// @param _utilization The utilization %, given with 5 decimals of precision.
    /// @param _fullUtilizationInterest The interest value when utilization is 100% given with 18 decimals of precision.
    /// @return _newFullUtilizationInterest The new maximum interest rate per second.
    function getFullUtilizationInterest(uint256 _deltaTime, uint256 _utilization, uint256 _fullUtilizationInterest)
        internal
        view
        returns (uint64 _newFullUtilizationInterest)
    {
        if (_utilization < MIN_TARGET_UTIL) {
            uint256 _deltaUtilization = ((MIN_TARGET_UTIL - _utilization) * 1e18) / MIN_TARGET_UTIL;
            uint256 _decayGrowth = (RATE_HALF_LIFE * 1e36) + (_deltaUtilization * _deltaUtilization * _deltaTime);
            _newFullUtilizationInterest = uint64((_fullUtilizationInterest * (RATE_HALF_LIFE * 1e36)) / _decayGrowth);
        } else if (_utilization > MAX_TARGET_UTIL) {
            uint256 _deltaUtilization = ((_utilization - MAX_TARGET_UTIL) * 1e18) / (UTIL_PREC - MAX_TARGET_UTIL);
            uint256 _decayGrowth = (RATE_HALF_LIFE * 1e36) + (_deltaUtilization * _deltaUtilization * _deltaTime);
            _newFullUtilizationInterest = uint64((_fullUtilizationInterest * _decayGrowth) / (RATE_HALF_LIFE * 1e36));
        } else {
            _newFullUtilizationInterest = uint64(_fullUtilizationInterest);
        }
        if (_newFullUtilizationInterest > MAX_FULL_UTIL_RATE) {
            _newFullUtilizationInterest = uint64(MAX_FULL_UTIL_RATE);
        } else if (_newFullUtilizationInterest < MIN_FULL_UTIL_RATE) {
            _newFullUtilizationInterest = uint64(MIN_FULL_UTIL_RATE);
        }
    }
}
