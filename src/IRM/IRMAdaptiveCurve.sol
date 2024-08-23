// SPDX-License-Identifier: MIT
// Copyright (c) 2023 Morpho Association
pragma solidity ^0.8.0;

import {IIRM} from "evk/InterestRateModels/IIRM.sol";
import {ExpLib} from "./lib/ExpLib.sol";

/// @title IRMAdaptiveCurve
/// @custom:contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/).
/// @author Adapted from Morpho Labs (https://github.com/morpho-org/morpho-blue-irm/).
/// @notice A Linear Kink IRM with an adaptive mechanism based on exponential growth/decay.
/// As utilization persists above/below the target the Linear Kink IRM is translated up/down.
/// @dev The model is parameterized by `(TARGET_UTILIZATION, rateAtTarget, CURVE_STEEPNESS)`.
/// `CURVE_STEEPNESS` is equivalent to `slope2` (above target), whereas `slope1` (under target) is `1/CURVE_STEEPNESS`.
/// The `rateAtTarget` parameter is the adaptive component in this model.
contract IRMAdaptiveCurve is IIRM {
    /// @dev Unit for internal precision.
    int256 internal constant WAD = 1e18;
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
    /// @notice The slope of interest rate line above the target. The line below the target has inverse slope.
    /// @dev In WAD units.
    int256 public immutable CURVE_STEEPNESS;
    /// @notice The speed at which the rate at target is adjusted up or down.
    /// @dev In WAD per second units.
    /// For example, with `2e18 / 24 hours` the model will 2x `rateAtTarget` if the vault is fully utilized for a day.
    int256 public immutable ADJUSTMENT_SPEED;

    /// @notice Internal cached state of the interest rate model.
    struct IRState {
        /// @dev The current rate at target utilization.
        uint208 rateAtTarget;
        /// @dev The timestamp of the last update to the model.
        uint48 lastUpdate;
    }

    /// @notice Get the cached state of a vault's irm.
    mapping(address => IRState) internal irState;

    /// @notice Deploy IRMAdaptiveCurve.
    /// @param _TARGET_UTILIZATION The utilization rate targeted by the interest rate model.
    /// @param _INITIAL_RATE_AT_TARGET The initial interest rate at target utilization.
    /// @param _MIN_RATE_AT_TARGET The minimum interest rate at target utilization that the model can adjust to.
    /// @param _MAX_RATE_AT_TARGET The maximum interest rate at target utilization that the model can adjust to.
    /// @param _CURVE_STEEPNESS The slope of interest rate above target. The line below target has inverse slope.
    /// @param _ADJUSTMENT_SPEED The speed at which the rate at target utilization is adjusted up or down.
    constructor(
        int256 _TARGET_UTILIZATION,
        int256 _INITIAL_RATE_AT_TARGET,
        int256 _MIN_RATE_AT_TARGET,
        int256 _MAX_RATE_AT_TARGET,
        int256 _CURVE_STEEPNESS,
        int256 _ADJUSTMENT_SPEED
    ) {
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
        (uint256 avgRate, uint256 endRateAtTarget) = computeInterestRateInternal(vault, cash, borrows);
        irState[vault] = IRState(uint208(endRateAtTarget), uint48(block.timestamp));
        return avgRate;
    }

    /// @inheritdoc IIRM
    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external view returns (uint256) {
        (uint256 avgRate,) = computeInterestRateInternal(vault, cash, borrows);
        // Scale rate to 1e27 for EVK.
        return avgRate * 1e9;
    }

    /// @notice Perform computation of the new rate at target without mutating state.
    /// @param vault Address of the vault to compute the new interest rate for.
    /// @param cash Amount of assets held directly by the vault.
    /// @param borrows Amount of assets lent out to borrowers by the vault.
    /// @return The new rate at target utilization in RAY units.
    function computeRateAtTargetView(address vault, uint256 cash, uint256 borrows) external view returns (uint256) {
        (, uint256 rateAtTarget) = computeInterestRateInternal(vault, cash, borrows);
        // Scale rate to 1e27 for EVK.
        return rateAtTarget * 1e9;
    }

    /// @notice Compute the new interest rate and rate at target utilization of a vault.
    /// @param vault Address of the vault to compute the new interest rate for.
    /// @param cash Amount of assets held directly by the vault.
    /// @param borrows Amount of assets lent out to borrowers by the vault.
    /// @return The new interest rate at current utilization.
    /// @return The new interest rate at target utilization.
    function computeInterestRateInternal(address vault, uint256 cash, uint256 borrows)
        internal
        view
        returns (uint256, uint256)
    {
        // Calculate utilization rate.
        int256 totalAssets = int256(cash + borrows);
        int256 utilization = totalAssets > 0 ? int256(borrows) * WAD / totalAssets : int256(0);

        // Calculate the normalized distance between current utilization and target utilization.
        // `err` is normalized to [-1, +1] where -1 is 0% util, 0 is at target and +1 is 100% util.
        int256 errNormFactor = utilization > TARGET_UTILIZATION ? WAD - TARGET_UTILIZATION : TARGET_UTILIZATION;
        int256 err = (utilization - TARGET_UTILIZATION) * WAD / errNormFactor;

        IRState memory state = irState[vault];
        int256 startRateAtTarget = int256(uint256(state.rateAtTarget));

        int256 avgRateAtTarget;
        int256 endRateAtTarget;

        if (startRateAtTarget == 0) {
            // First interaction.
            avgRateAtTarget = INITIAL_RATE_AT_TARGET;
            endRateAtTarget = INITIAL_RATE_AT_TARGET;
        } else {
            // The speed is assumed constant between two updates, but it is in fact not constant because of interest.
            // So the rate is always underestimated.
            int256 speed = ADJUSTMENT_SPEED * err / WAD;

            // Calculate the adaptation parameter.
            int256 elapsed = int256(block.timestamp - state.lastUpdate);
            int256 linearAdaptation = speed * elapsed;

            // If linearAdaptation == 0, avgRateAtTarget = endRateAtTarget = startRateAtTarget.
            if (linearAdaptation == 0) {
                avgRateAtTarget = startRateAtTarget;
                endRateAtTarget = startRateAtTarget;
            } else {
                // Formula of the average rate that should be returned:
                // avg = 1/T * ∫_0^T curve(startRateAtTarget*exp(speed*x), err) dx
                // The integral is approximated:
                // avg ~= curve([startRateAtTarget + endRateAtTarget + 2*startRateAtTarget*exp(speed*T/2)] / 4, err)
                endRateAtTarget = _newRateAtTarget(startRateAtTarget, linearAdaptation);
                int256 midRateAtTarget = _newRateAtTarget(startRateAtTarget, linearAdaptation / 2);
                avgRateAtTarget = (startRateAtTarget + endRateAtTarget + 2 * midRateAtTarget) / 4;
            }
        }
        return (uint256(_curve(avgRateAtTarget, err)), uint256(endRateAtTarget));
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
}
