// SPDX-License-Identifier: MIT
// Copyright (c) 2023 Morpho Association
pragma solidity ^0.8.0;

import {IIRM} from "evk/InterestRateModels/IIRM.sol";
import {ExpWad} from "./lib/ExpWad.sol";

/// @title IRMAdaptiveLinearKink
/// @custom:contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/).
/// @author Adapted from Morpho Labs (https://github.com/morpho-org/morpho-blue-irm/).
/// @notice A Linear Kink IRM with an adaptive mechanism based on exponential growth/decay.
/// As utilization persists above/below the kink the Linear Kink IRM is translated up/down.
/// @dev The model is parameterized by `(kink, kinkRate, slope)` instead of `(kink, baseRate, slope1, slope2)`.
/// The `slope` parameter is equivalent to `slope2` (above kink), whereas `slope1` (under kink) is `1/slope`.
/// The `kinkRate` parameter is the adaptive component in this model.
contract IRMAdaptiveLinearKink is IIRM {
    /// @dev Unit for internal precision.
    int256 internal constant WAD = 1e18;
    /// @notice The utilization rate targeted by the model.
    /// @dev In WAD units.
    int256 public immutable kink;
    /// @notice The initial interest rate when utilization is at kink.
    /// @dev In WAD per second units.
    /// When the IRM is initialized for a vault this is the rate at kink that is assigned.
    int256 public immutable initialKinkRate;
    /// @notice The minimum interest rate when utilization is at kink that the model can adjust to.
    /// @dev In WAD per second units.
    int256 public immutable minKinkRate;
    /// @notice The maximum interest rate when utilization is at kink that the model can adjust to.
    /// @dev In WAD per second units.
    int256 public immutable maxKinkRate;
    /// @notice The steepness of interest rate line above the kink. The line below the kink has the inverse slope.
    /// @dev In WAD units. The line below the kink has the inverse slope.
    int256 public immutable slope;
    /// @notice The speed at which the rate at kink is adjusted up or down.
    /// @dev In WAD per second units. For example, an adjustment speed of `2e18 / 24 hours` will make the model
    /// double `kinkRate` if the rate remains at 100% for a day.
    int256 public immutable adjustmentSpeed;

    /// @notice Cached state of the interest rate model.
    struct IRState {
        /// @dev The current rate at kink.
        int208 kinkRate;
        /// @dev The timestamp of the last update to the model.
        uint48 lastUpdate;
    }

    /// @notice Get the cached state of a vault's irm.
    mapping(address => IRState) internal irState;

    /// @notice Deploy IRMAdaptiveLinearKink
    /// @param _kink The utilization rate targeted by the interest rate model.
    /// @param _initialKinkRate The initial interest rate at kink.
    /// @param _minKinkRate The minimum interest rate at kink that the model can adjust to.
    /// @param _maxKinkRate The maximum interest rate at kink that the model can adjust to.
    /// @param _slope The steepness of interest rate function below and above the kink.
    /// @param _adjustmentSpeed The speed at which the rate at kink is adjusted up or down.
    constructor(
        int256 _kink,
        int256 _initialKinkRate,
        int256 _minKinkRate,
        int256 _maxKinkRate,
        int256 _slope,
        int256 _adjustmentSpeed
    ) {
        kink = _kink;
        initialKinkRate = _initialKinkRate;
        minKinkRate = _minKinkRate;
        maxKinkRate = _maxKinkRate;
        slope = _slope;
        adjustmentSpeed = _adjustmentSpeed;
    }

    /// @inheritdoc IIRM
    function computeInterestRate(address vault, uint256 cash, uint256 borrows) external returns (uint256) {
        if (msg.sender != vault) revert E_IRMUpdateUnauthorized();
        (uint256 avgRate, int256 endKinkRate) = computeInterestRateInternal(vault, cash, borrows);
        irState[vault] = IRState(int208(endKinkRate), uint48(block.timestamp));
        return avgRate;
    }

    /// @inheritdoc IIRM
    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external view returns (uint256) {
        (uint256 avgRate,) = computeInterestRateInternal(vault, cash, borrows);
        return avgRate;
    }

    /// @notice Perform computation of the new kink rate without mutating state.
    /// @param vault Address of the vault to compute the new interest rate for.
    /// @param cash Amount of assets held directly by the vault.
    /// @param borrows Amount of assets lent out to borrowers by the vault.
    /// @return Then new kink rate in WAD per second units.
    function computeKinkRateView(address vault, uint256 cash, uint256 borrows) external view returns (int256) {
        (, int256 kinkRate) = computeInterestRateInternal(vault, cash, borrows);
        return kinkRate;
    }

    /// @notice Compute the new interest rate and rate at kink of a vault.
    /// @param vault Address of the vault to compute the new interest rate for.
    /// @param cash Amount of assets held directly by the vault.
    /// @param borrows Amount of assets lent out to borrowers by the vault.
    /// @return The new interest rate at current utilization.
    /// @return The new interest rate at kink.
    function computeInterestRateInternal(address vault, uint256 cash, uint256 borrows)
        internal
        view
        returns (uint256, int256)
    {
        // Calculate utilization rate.
        uint256 totalAssets = cash + borrows;
        int256 utilization = totalAssets == 0 ? int256(0) : int256(borrows) * WAD / int256(totalAssets);

        // Calculate the normalized distance between current utilization and target utilization (kink).
        // `err` is normalized to [-1,+1] where -1 is 0% util, 0 is at `kink` and +1 is 100% util.
        int256 errNormFactor = utilization > kink ? WAD - kink : kink;
        int256 err = (utilization - kink) * WAD / errNormFactor;

        // Initialize rate if this is the first interaction.
        IRState memory state = irState[vault];
        if (state.lastUpdate == 0) return (calcLinearKinkRate(initialKinkRate, err), initialKinkRate);

        // The speed is assumed constant between two updates, but it is in fact not constant because of interest.
        // So the rate is always underestimated.
        int256 speed = adjustmentSpeed * err / WAD;

        // Calculate the adaptation parameter.
        int256 deltaTime = int256(block.timestamp - state.lastUpdate);
        int256 adaptation = speed * deltaTime;

        // If adaptation == 0, avgKinkRate = endKinkRate = state.kinkRate.
        if (adaptation == 0) return (calcLinearKinkRate(state.kinkRate, err), state.kinkRate);

        // Formula of the average rate that should be returned:
        // avg = 1/T * ∫_0^T linear_kink(state.kinkRate*exp(speed*x), err) dx
        // The integral is approximated with the trapezoidal rule (N=2):
        // avg ~= linear_kink([state.kinkRate + endKinkRate + 2*state.kinkRate*exp(speed*T/2)] / 4, err)
        int256 endKinkRate = calcNewKinkRate(state.kinkRate, adaptation);
        int256 midKinkRate = calcNewKinkRate(state.kinkRate, adaptation / 2);
        int256 avgKinkRate = (state.kinkRate + endKinkRate + 2 * midKinkRate) / 4;

        return (calcLinearKinkRate(avgKinkRate, err), endKinkRate);
    }

    /// @notice Calculate the interest rate according to the linear kink model.
    /// @param kinkRate The current interest rate at kink.
    /// @param err The distance between the current utilization rate and the kink, normalized to `[-1,1]`.
    /// @dev rate = kinkRate * ((1 - 1/slope) * err + 1) if err < 0
    ///             kinkRate * ((slope - 1) * err + 1) else.
    /// @return The new interest rate at current utilization.
    function calcLinearKinkRate(int256 kinkRate, int256 err) internal view returns (uint256) {
        int256 coeff;
        if (err < 0) {
            coeff = WAD - WAD * WAD / slope;
        } else {
            coeff = slope - WAD;
        }
        return uint256(((coeff * err / WAD) + WAD) * kinkRate / WAD);
    }

    /// @notice Calculate the new interest rate at kink by applying an adaptation.
    /// @param kinkRate The current interest rate at kink.
    /// @param adaptation The adaptation parameter.
    /// @dev Applies exponential growth/decay to the current interest rate at kink.
    /// Formula: `newKinkRate = kinkRate * e^adaptation` bounded to `[minKinkRate, maxKinkRate]`.
    /// @return The new interest rate at kink.
    function calcNewKinkRate(int256 kinkRate, int256 adaptation) internal view returns (int256) {
        unchecked {
            // `expWad` is modified to saturate on overflow.
            int256 expResult = ExpWad.expWad(adaptation);
            // Detect overflow, in which case return `maxKinkRate`.
            int256 numerator = kinkRate * expResult;
            if (numerator / kinkRate != expResult) return maxKinkRate;
            // Bound `kinkRate` to `[minKinkRate, maxKinkRate]`.
            int256 newKinkRate = numerator / WAD;
            if (newKinkRate < minKinkRate) return minKinkRate;
            if (newKinkRate > maxKinkRate) return maxKinkRate;
            return newKinkRate;
        }
    }
}
