// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEVault} from "evk/EVault/IEVault.sol";
import {IIRM} from "evk/InterestRateModels/IIRM.sol";
import {ExpWad} from "./lib/ExpWad.sol";

/// @title IRMAdaptiveLinearKink
/// @notice A Linear Kink IRM with an additional adaptive mechanism.
/// If utilization persists below/above the kink the entire model is translated downward/upward.
/// This mechanism adapts the interest rates to external changes in market rates and demand.
/// @author Euler Labs (https://www.eulerlabs.com/).
/// @author Inspired by Morpho Labs (https://github.com/morpho-org/morpho-blue-irm/blob/main/src/adaptive-curve-irm/AdaptiveCurveIrm.sol).
/// @custom:contact security@euler.xyz
contract IRMAdaptiveLinearKink is IIRM {
    /// @dev Unit for internal precision.
    int256 internal constant WAD = 1e18;
    /// @notice The utilization rate targeted by the interest rate model.
    /// @dev In WAD units e.g. 0.9e18 = 90%.
    int256 public immutable kink;
    /// @notice The initial interest rate at the kink level.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    int256 public immutable initialKinkRate;
    /// @notice The minimum interest rate at the kink level that the model can adjust to.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    int256 public immutable minKinkRate;
    /// @notice The maximum interest rate at the kink level that the model can adjust to.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    int256 public immutable maxKinkRate;
    /// @notice The steepness of interest rate function below and above the kink.
    /// @dev In WAD units e.g. 4e18 = 400%.
    int256 public immutable slope;
    /// @notice The speed at which the kink rate is adjusted up or down.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    int256 public immutable adjustmentSpeed;

    struct IRState {
        int224 kinkRate;
        uint32 lastUpdate;
    }

    /// @notice Get the cached state of a vault's irm.
    /// @return kinkRate The current kink rate.
    /// @return lastUpdate The last update timestamp.
    /// @dev Note that this state may be outdated. Use `computeInterestRateView` for the latest interest rate.
    mapping(address => IRState) public irState;

    /// @notice Deploy IRMAdaptiveLinearKink
    /// @param _kink The utilization rate targeted by the interest rate model.
    /// @param _initialKinkRate The initial interest rate at the kink level.
    /// @param _minKinkRate The minimum interest rate at the kink level that the model can adjust to.
    /// @param _maxKinkRate The maximum interest rate at the kink level that the model can adjust to.
    /// @param _slope The steepness of interest rate function below and above the kink.
    /// @param _adjustmentSpeed The speed at which the kink rate is adjusted up or down.
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
        irState[vault] = IRState(int224(endKinkRate), uint32(block.timestamp));
        return avgRate;
    }

    /// @inheritdoc IIRM
    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external view returns (uint256) {
        (uint256 avgRate,) = computeInterestRateInternal(vault, cash, borrows);
        return avgRate;
    }

    /// @notice Compute the current interest rate for a vault.
    /// @param vault Address of the vault to compute the new interest rate for.
    /// @param cash Amount of assets held directly by the vault.
    /// @param borrows Amount of assets lent out to borrowers by the vault.
    function computeInterestRateInternal(address vault, uint256 cash, uint256 borrows)
        internal
        view
        returns (uint256, int256)
    {
        IRState memory state = irState[vault];
        // Initialize rate if this is the first interaction.
        if (state.lastUpdate == 0) return (uint256(initialKinkRate), initialKinkRate);

        // Calculate utilization rate.
        uint256 totalAssets = cash + borrows;
        int256 utilization = totalAssets == 0 ? int256(0) : int256(borrows) * WAD / int256(totalAssets);

        // Calculate the normalized distance between current utilization wrt. target utilization (kink).
        // `err` is normalized to [-1,+1] where -1 is 0% util, 0 is `kink` and +1 is 100% util.
        int256 errNormFactor = utilization > kink ? WAD - kink : kink;
        int256 err = (utilization - kink) * WAD / errNormFactor;

        // The speed is assumed constant between two updates, but it is in fact not constant because of interest.
        // So the rate is always underestimated.
        int256 speed = adjustmentSpeed * err / WAD;
        // Safe "unchecked" cast because block.timestamp - state.lastUpdate <= block.timestamp <= type(int256).max.
        int256 elapsed = int256(block.timestamp - state.lastUpdate);
        int256 linearAdaptation = speed * elapsed;

        // If linearAdaptation == 0, avgKinkRate = endKinkRate = state.kinkRate;
        if (linearAdaptation == 0) return (calcRateOnCurve(state.kinkRate, err), state.kinkRate);

        // Formula of the average rate that should be returned:
        // avg = 1/T * ∫_0^T curve(state.kinkRate*exp(speed*x), err) dx
        // The integral is approximated with the trapezoidal rule:
        // avg ~= 1/T * Σ_i=1^N [curve(f((i-1) * T/N), err) + curve(f(i * T/N), err)] / 2 * T/N
        // Where f(x) = state.kinkRate*exp(speed*x)
        // avg ~= Σ_i=1^N [curve(f((i-1) * T/N), err) + curve(f(i * T/N), err)] / (2 * N)
        // As curve is linear in its first argument:
        // avg ~= curve([Σ_i=1^N [f((i-1) * T/N) + f(i * T/N)] / (2 * N), err)
        // avg ~= curve([(f(0) + f(T))/2 + Σ_i=1^(N-1) f(i * T/N)] / N, err)
        // avg ~= curve([(state.kinkRate + endKinkRate)/2 + Σ_i=1^(N-1) f(i * T/N)] / N, err)
        // With N = 2:
        // avg ~= curve([(state.kinkRate + endKinkRate)/2 + state.kinkRate*exp(speed*T/2)] / 2, err)
        // avg ~= curve([state.kinkRate + endKinkRate + 2*state.kinkRate*exp(speed*T/2)] / 4, err)
        int256 endKinkRate = calcNewKinkRate(state.kinkRate, linearAdaptation);
        int256 midKinkRate = calcNewKinkRate(state.kinkRate, linearAdaptation / 2);
        int256 avgKinkRate = (state.kinkRate + endKinkRate + 2 * midKinkRate) / 4;

        return (calcRateOnCurve(avgKinkRate, err), endKinkRate);
    }

    /// @dev Returns the rate for a given `kinkRate` and an `err`.
    /// The formula of the curve is the following:
    /// r = ((1-1/C)*err + 1) * kinkRate if err < 0
    ///     ((C-1)*err + 1) * kinkRate else.
    function calcRateOnCurve(int256 kinkRate, int256 err) internal view returns (uint256) {
        // Non-negative because slope > 1.
        int256 coeff;
        if (err < 0) {
            coeff = WAD - WAD * WAD / slope;
        } else {
            coeff = slope - WAD;
        }
        // Non negative if kinkRate >= 0 because if err < 0, coeff <= 1.
        return uint256(((coeff * err / WAD) + WAD) * kinkRate / WAD);
    }

    /// @dev Returns the new rate at target, for a given `startKinkRate` and a given `linearAdaptation`.
    function calcNewKinkRate(int256 startKinkRate, int256 linearAdaptation) internal view returns (int256) {
        // Non negative because minKinkRate > 0.
        int256 rate = startKinkRate * ExpWad.expWad(linearAdaptation) / WAD;
        if (rate < minKinkRate) return minKinkRate;
        if (rate > maxKinkRate) return maxKinkRate;
        return rate;
    }
}
