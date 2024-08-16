// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IIRM} from "evk/InterestRateModels/IIRM.sol";

/// @title IRMVariableRange
/// @author Euler Labs (https://www.eulerlabs.com/).
/// @author Inspired by Frax (https://docs.frax.finance/fraxlend/advanced-concepts/interest-rates).
/// @custom:contact security@euler.xyz
contract IRMVariableRange is IIRM {
    /// @dev Unit for internal precision.
    uint256 internal constant WAD = 1e18;
    /// @notice The lower bound of the utilization range where the full rate does not adjust.
    /// @dev In WAD units e.g. 0.9e18 = 90%.
    uint256 public immutable targetUtilizationLower;
    /// @notice The upper bound of the utilization range where the full rate does not adjust.
    /// @dev In WAD units e.g. 0.9e18 = 90%.
    uint256 public immutable targetUtilizationUpper;
    /// @notice The utilization at which the slope increases.
    /// @dev In WAD units e.g. 0.9e18 = 90%.
    uint256 public immutable kink;
    /// @notice The interest rate when utilization is 0%.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    uint256 public immutable baseRate;
    /// @notice The minimum interest rate when utilization is 100%.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    uint256 public immutable minFullRate;
    /// @notice The maximum interest rate when utilization is 100%.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    uint256 public immutable maxFullRate;
    /// @notice The initial interest rate when utilization is 100%.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    uint256 public immutable initialFullRate;
    /// @notice The time it takes for the interest to halve when adjusting the curve.
    /// @dev In seconds e.g. 43200 = 12 hours.
    uint256 public immutable halfLife;
    /// @notice The percent of the delta between max and min.
    uint256 public immutable kinkRatePercent;

    /// @notice Cached state of the interest rate model.
    struct IRState {
        /// @dev The current rate at 100% utilization.
        uint208 fullRate;
        /// @dev The timestamp of the last update to the model.
        uint48 lastUpdate;
    }

    /// @notice Get the cached state of a vault's irm.
    /// @return fullRate The current full rate.
    /// @return lastUpdate The last update timestamp.
    /// @dev Note that this state may be outdated. Use `computeInterestRateView` for the latest interest rate.
    mapping(address => IRState) public irState;

    /// @notice Deploy IRMVariableRange.
    /// @param _targetUtilizationLower The lower bound of the utilization range where the interest rate does not adjust.
    /// @param _targetUtilizationUpper The upper bound of the utilization range where the interest rate does not adjust.
    /// @param _kink The utilization at which the slope increases.
    /// @param _baseRate The interest rate when utilization is 0%.
    /// @param _minFullRate The minimum interest rate when utilization is 100%.
    /// @param _maxFullRate The maximum interest rate when utilization is 100%.
    /// @param _initialFullRate The initial interest rate when utilization is 100%.
    /// @param _halfLife The time it takes for the interest to halve when adjusting the curve.
    /// @param _kinkRatePercent The percent of the delta between max and min.
    constructor(
        uint256 _targetUtilizationLower,
        uint256 _targetUtilizationUpper,
        uint256 _kink,
        uint256 _baseRate,
        uint256 _minFullRate,
        uint256 _maxFullRate,
        uint256 _initialFullRate,
        uint256 _halfLife,
        uint256 _kinkRatePercent
    ) {
        targetUtilizationLower = _targetUtilizationLower;
        targetUtilizationUpper = _targetUtilizationUpper;
        kink = _kink;
        baseRate = _baseRate;
        minFullRate = _minFullRate;
        maxFullRate = _maxFullRate;
        initialFullRate = _initialFullRate;
        halfLife = _halfLife;
        kinkRatePercent = _kinkRatePercent;
    }

    /// @inheritdoc IIRM
    function computeInterestRate(address vault, uint256 cash, uint256 borrows) external returns (uint256) {
        if (msg.sender != vault) revert E_IRMUpdateUnauthorized();
        (uint256 rate, uint256 fullRate) = computeInterestRateInternal(vault, cash, borrows);
        irState[vault] = IRState(uint208(fullRate), uint48(block.timestamp));
        return rate;
    }

    /// @inheritdoc IIRM
    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external view returns (uint256) {
        (uint256 rate,) = computeInterestRateInternal(vault, cash, borrows);
        return rate;
    }

    /// @notice Compute the current interest rate for a vault.
    /// @param vault Address of the vault to compute the new interest rate for.
    /// @param cash Amount of assets held directly by the vault.
    /// @param borrows Amount of assets lent out to borrowers by the vault.
    /// @return The new interest rate.
    /// @return The new maximum interest rate.
    function computeInterestRateInternal(address vault, uint256 cash, uint256 borrows)
        internal
        view
        returns (uint256, uint256)
    {
        // Calculate utilization rate.
        uint256 totalAssets = cash + borrows;
        uint256 utilization = totalAssets == 0 ? 0 : borrows * WAD / totalAssets;

        IRState memory state = irState[vault];
        // Initialize full rate if this is the first call.
        if (state.lastUpdate == 0) return (calcLinearKinkRate(utilization, initialFullRate), initialFullRate);

        // Calculate time elapsed since last update.
        uint256 deltaTime = block.timestamp - state.lastUpdate;

        // Calculate new interest rates.
        uint256 newFullRate = calcNewFullRate(deltaTime, utilization, state.fullRate);
        uint256 newRate = calcLinearKinkRate(utilization, newFullRate);
        return (newRate, newFullRate);
    }

    /// @notice Calculate the new interest rate.
    /// @param utilization The utilization rate in WAD.
    /// @param newFullRate The new interest rate when utilization is 100% in WAD.
    /// @return The new interest rate in WAD per second.
    function calcLinearKinkRate(uint256 utilization, uint256 newFullRate) internal view returns (uint256) {
        // kinkRate is calculated as the percentage of the delta between min and max interest
        uint256 kinkRate = (((newFullRate - baseRate) * kinkRatePercent) / WAD) + baseRate;

        if (utilization < kink) {
            return baseRate + (utilization * (kinkRate - baseRate)) / kink;
        } else {
            return kinkRate + ((utilization - kink) * (newFullRate - kinkRate)) / (WAD - kink);
        }
    }
    /// @notice Calculate the new full interest rate, i.e. rate when utilization is 100%.
    /// @param deltaTime The elapsed time since last update in seconds.
    /// @param utilization The utilization rate in WAD.
    /// @param fullRate The interest rate when utilization is 100% in WAD.
    /// @return The new full interest rate in WAD per second.

    function calcNewFullRate(uint256 deltaTime, uint256 utilization, uint256 fullRate)
        internal
        view
        returns (uint256)
    {
        if (utilization < targetUtilizationLower) {
            // Adjust full rate downward based on half life decay.
            uint256 deltaUtilization = ((targetUtilizationLower - utilization) * WAD) / targetUtilizationLower;
            uint256 decayGrowth = halfLife * WAD * WAD + deltaUtilization * deltaUtilization * deltaTime;
            return boundFullRate(fullRate * halfLife * WAD * WAD / decayGrowth);
        } else if (utilization > targetUtilizationUpper) {
            // Adjust full rate upward based on half life decay.
            uint256 deltaUtilization = ((utilization - targetUtilizationUpper) * WAD) / (WAD - targetUtilizationUpper);
            uint256 decayGrowth = halfLife * WAD * WAD + deltaUtilization * deltaUtilization * deltaTime;
            return boundFullRate(fullRate * decayGrowth / (halfLife * WAD * WAD));
        }
        // Utilization is within target range. Return last rate.
        return fullRate;
    }

    /// @notice Bound `fullRate` to `[minFullRate, maxFullRate]`.
    /// @param fullRate The rate to bound.
    /// @return The bounded rate.
    function boundFullRate(uint256 fullRate) internal view returns (uint256) {
        if (fullRate < minFullRate) return minFullRate;
        if (fullRate > maxFullRate) return maxFullRate;
        return fullRate;
    }
}
