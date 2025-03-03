// SPDX-License-Identifier: MIT
// Copyright (c) 2023 Morpho Association

pragma solidity ^0.8.0;

import {IIRM} from "evk/InterestRateModels/IIRM.sol";
import {ExpLib} from "./lib/ExpLib.sol";

/// @title IRMAdaptiveCurve
/// @custom:contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/).
/// @author Adapted from Morpho Labs (https://github.com/morpho-org/morpho-blue-irm/).
/// @notice A Linear Kink IRM that adjusts the rate at target utilization based on time spent above/below it.
/// @dev This implementation intentionally leaves variables names, units and ExpLib unchanged from original.
/// Returned rates are extended to RAY per second to be compatible with the EVK.
contract IRMAdaptiveCurve is IIRM {
    /// @dev Unit for internal precision.
    int256 internal constant WAD = 1e18;
    /// @dev Unit for internal precision.
    int256 internal constant YEAR = int256(365.2425 days);
    /// @notice The name of the IRM.
    string public constant name = "IRMAdaptiveCurve";
    /// @notice The utilization rate targeted by the model.
    /// @dev In WAD units.
    int256 public immutable TARGET_UTILIZATION;
    /// @notice The initial interest rate at target utilization.
    /// @dev In WAD per second units.
    /// When the IRM is initialized for a vault this is the rate at target utilization that is assigned.
    int256 public immutable INITIAL_RATE_AT_TARGET;
    /// @notice The minimum interest rate at target utilization that the model can adjust to.
    /// @dev In WAD per second units.
    int256 public immutable MIN_RATE_AT_TARGET;
    /// @notice The maximum interest rate at target utilization that the model can adjust to.
    /// @dev In WAD per second units.
    int256 public immutable MAX_RATE_AT_TARGET;
    /// @notice The steepness of the interest rate line.
    /// @dev In WAD units.
    int256 public immutable CURVE_STEEPNESS;
    /// @notice The speed at which the rate at target is adjusted up or down.
    /// @dev In WAD per second units.
    /// For example, with `2e18 / 24 hours` the model will 2x `rateAtTarget` if the vault is fully utilized for a day.
    int256 public immutable ADJUSTMENT_SPEED;

    /// @notice Internal cached state of the interest rate model.
    struct IRState {
        /// @dev The current rate at target utilization.
        uint144 rateAtTarget;
        /// @dev The previous utilization rate of the vault.
        int64 lastUtilization;
        /// @dev The timestamp of the last update to the model.
        uint48 lastUpdate;
    }

    /// @notice Get the internal cached state of a vault's irm.
    mapping(address => IRState) internal irState;

    error InvalidParams();

    /// @notice Deploy IRMAdaptiveCurve.
    /// @param _TARGET_UTILIZATION The utilization rate targeted by the interest rate model.
    /// @param _INITIAL_RATE_AT_TARGET The initial interest rate at target utilization.
    /// @param _MIN_RATE_AT_TARGET The minimum interest rate at target utilization that the model can adjust to.
    /// @param _MAX_RATE_AT_TARGET The maximum interest rate at target utilization that the model can adjust to.
    /// @param _CURVE_STEEPNESS The steepness of the interest rate line.
    /// @param _ADJUSTMENT_SPEED The speed at which the rate at target utilization is adjusted up or down.
    constructor(
        int256 _TARGET_UTILIZATION,
        int256 _INITIAL_RATE_AT_TARGET,
        int256 _MIN_RATE_AT_TARGET,
        int256 _MAX_RATE_AT_TARGET,
        int256 _CURVE_STEEPNESS,
        int256 _ADJUSTMENT_SPEED
    ) {
        // Validate parameters.
        if (_TARGET_UTILIZATION <= 0 || _TARGET_UTILIZATION > 1e18) {
            revert InvalidParams();
        }
        if (_INITIAL_RATE_AT_TARGET < _MIN_RATE_AT_TARGET || _INITIAL_RATE_AT_TARGET > _MAX_RATE_AT_TARGET) {
            revert InvalidParams();
        }
        if (_MIN_RATE_AT_TARGET < 0.001e18 / YEAR || _MIN_RATE_AT_TARGET > 10e18 / YEAR) {
            revert InvalidParams();
        }
        if (_MAX_RATE_AT_TARGET < 0.001e18 / YEAR || _MAX_RATE_AT_TARGET > 10e18 / YEAR) {
            revert InvalidParams();
        }
        if (_CURVE_STEEPNESS < 1.01e18 || _CURVE_STEEPNESS > 100e18) {
            revert InvalidParams();
        }
        if (_ADJUSTMENT_SPEED < 2e18 / YEAR || _ADJUSTMENT_SPEED > 1000e18 / YEAR) {
            revert InvalidParams();
        }

        TARGET_UTILIZATION = _TARGET_UTILIZATION;
        INITIAL_RATE_AT_TARGET = _INITIAL_RATE_AT_TARGET;
        MIN_RATE_AT_TARGET = _MIN_RATE_AT_TARGET;
        MAX_RATE_AT_TARGET = _MAX_RATE_AT_TARGET;
        CURVE_STEEPNESS = _CURVE_STEEPNESS;
        ADJUSTMENT_SPEED = _ADJUSTMENT_SPEED;
    }

    /// @inheritdoc IIRM
    function computeInterestRate(address vault, uint256 cash, uint256 borrows) external returns (uint256) {
        if (msg.sender != vault) revert E_IRMUpdateUnauthorized();

        // Do not update state until the first borrow.
        if (borrows == 0 && irState[vault].lastUpdate == 0) {
            return uint256(_curve(INITIAL_RATE_AT_TARGET, _calcErr(0))) * 1e9;
        }

        int256 utilization = _calcUtilization(cash, borrows);
        (uint256 rate, uint256 rateAtTarget) = computeInterestRateInternal(vault, utilization);

        irState[vault] = IRState(uint144(rateAtTarget), int64(utilization), uint48(block.timestamp));
        return rate * 1e9; // Extend rate to RAY/sec for EVK.
    }

    /// @inheritdoc IIRM
    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external view returns (uint256) {
        int256 utilization = _calcUtilization(cash, borrows);
        (uint256 rate,) = computeInterestRateInternal(vault, utilization);
        return rate * 1e9; // Extend rate to RAY/sec for EVK.
    }

    /// @notice Perform computation of the new rate at target without mutating state.
    /// @param vault Address of the vault to compute the new interest rate for.
    /// @param cash Amount of assets held directly by the vault.
    /// @param borrows Amount of assets lent out to borrowers by the vault.
    /// @return The new rate at target utilization in RAY units.
    function computeRateAtTargetView(address vault, uint256 cash, uint256 borrows) external view returns (uint256) {
        int256 utilization = _calcUtilization(cash, borrows);
        (, uint256 rateAtTarget) = computeInterestRateInternal(vault, utilization);
        return rateAtTarget * 1e9; // Extend rate to RAY/sec for EVK.
    }

    /// @notice Get the timestamp of the last update for a vault.
    /// @param vault Address of the vault to get the last update timestamp for.
    /// @return The last update timestamp.
    function getLastUpdateTimestamp(address vault) external view returns (uint256) {
        return irState[vault].lastUpdate;
    }

    /// @notice Compute the new interest rate and rate at target utilization of a vault.
    /// @param vault Address of the vault to compute the new interest rate for.
    /// @return The new interest rate at current utilization.
    /// @return The new interest rate at target utilization.
    function computeInterestRateInternal(address vault, int256 utilization) internal view returns (uint256, uint256) {
        // Calculate normalized distance using previous utilization for curve shifting
        int256 lastUtilization = irState[vault].lastUpdate == 0 ? utilization : int256(irState[vault].lastUtilization);
        int256 errOld = _calcErr(lastUtilization);

        // Calculate normalized distance using current utilization for position on curve
        int256 errNew = _calcErr(utilization);

        IRState memory state = irState[vault];
        int256 startRateAtTarget = int256(uint256(state.rateAtTarget));
        int256 endRateAtTarget;

        if (startRateAtTarget == 0) {
            // First interaction.
            endRateAtTarget = INITIAL_RATE_AT_TARGET;
        } else {
            // Use errOld for curve shifting
            int256 speed = ADJUSTMENT_SPEED * errOld / WAD;

            // Calculate the adaptation parameter.
            int256 elapsed = int256(block.timestamp - state.lastUpdate);
            int256 linearAdaptation = speed * elapsed;

            if (linearAdaptation == 0) {
                endRateAtTarget = startRateAtTarget;
            } else {
                endRateAtTarget = _newRateAtTarget(startRateAtTarget, linearAdaptation);
            }
        }

        // Use errNew for position on curve to get current interest rate
        return (uint256(_curve(endRateAtTarget, errNew)), uint256(endRateAtTarget));
    }

    /// @notice Calculate the interest rate according to the linear kink model.
    /// @param rateAtTarget The current interest rate at target utilization.
    /// @param err The distance between the current utilization and the target utilization, normalized to `[-1, +1]`.
    /// @dev rate = ((1-1/C)*err + 1) * rateAtTarget if err < 0
    ///             (C-1)*err + 1) * rateAtTarget else.
    /// @return The new interest rate at current utilization.
    function _curve(int256 rateAtTarget, int256 err) internal view returns (int256) {
        // Non negative because 1 - 1/C >= 0, C - 1 >= 0.
        int256 coeff = err < 0 ? WAD - WAD * WAD / CURVE_STEEPNESS : CURVE_STEEPNESS - WAD;
        // Non negative if rateAtTarget >= 0 because if err < 0, coeff <= 1.
        return ((coeff * err / WAD) + WAD) * rateAtTarget / WAD;
    }

    /// @notice Calculate the new interest rate at target utilization by applying an adaptation.
    /// @param startRateAtTarget The current interest rate at target utilization.
    /// @param linearAdaptation The adaptation parameter, used as a power of `e`.
    /// @dev Applies exponential growth/decay to the current interest rate at target utilization.
    /// Formula: `rateAtTarget = startRateAtTarget * e^linearAdaptation` bounded to min and max.
    /// @return The new interest rate at target utilization.
    function _newRateAtTarget(int256 startRateAtTarget, int256 linearAdaptation) internal view returns (int256) {
        int256 rateAtTarget = startRateAtTarget * ExpLib.wExp(linearAdaptation) / WAD;
        if (rateAtTarget < MIN_RATE_AT_TARGET) return MIN_RATE_AT_TARGET;
        if (rateAtTarget > MAX_RATE_AT_TARGET) return MAX_RATE_AT_TARGET;
        return rateAtTarget;
    }

    /// @notice Calculate the normalized distance between the utilization and target utilization.
    /// @param utilization The utilization rate.
    /// @return The normalized distance between the utilization and target utilization.
    function _calcErr(int256 utilization) internal view returns (int256) {
        int256 errNormFactor = utilization > TARGET_UTILIZATION ? WAD - TARGET_UTILIZATION : TARGET_UTILIZATION;
        return (utilization - TARGET_UTILIZATION) * WAD / errNormFactor;
    }

    /// @notice Calculate the utilization rate, given cash and borrows from the vault.
    /// @param cash Amount of assets held directly by the vault.
    /// @param borrows Amount of assets lent out to borrowers by the vault.
    /// @return The utilization rate in WAD.
    function _calcUtilization(uint256 cash, uint256 borrows) internal pure returns (int256) {
        int256 totalAssets = int256(cash + borrows);
        if (totalAssets == 0) return 0;
        return int256(borrows) * WAD / totalAssets;
    }
}
