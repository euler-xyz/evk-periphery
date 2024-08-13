// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEVault} from "evk/EVault/IEVault.sol";
import {IIRM} from "evk/InterestRateModels/IIRM.sol";

/// @title IRMTimeWeightedVariable
/// @author Euler Labs (https://www.eulerlabs.com/).
/// @author Inspired by Frax (https://docs.frax.finance/fraxlend/advanced-concepts/interest-rates).
/// @custom:contact security@euler.xyz
contract IRMTimeWeightedVariable is IIRM {
    /// @dev Unit for internal precision.
    uint256 internal constant WAD = 1e18;
    /// @notice The lower bound of the utilization range where the interest rate does not adjust.
    /// @dev In WAD units e.g. 0.9e18 = 90%.
    uint256 public immutable targetUtilizationLower;
    /// @notice The upper bound of the utilization range where the interest rate does not adjust.
    /// @dev In WAD units e.g. 0.9e18 = 90%.
    uint256 public immutable targetUtilizationUpper;
    /// @notice The minimum interest rate for the model.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    uint256 public immutable minRate;
    /// @notice The maximum interest rate for the model.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    uint256 public immutable maxRate;
    /// @notice The initial interest rate for the model.
    /// @dev In WAD units per second e.g. 1e18 / 365 days = 100%.
    uint256 public immutable initialRate;
    /// @notice The time it takes for the interest to halve when utilization is 0%.
    /// @dev In seconds e.g. 43200 = 12 hours.
    uint256 public immutable halfLife;

    struct IRState {
        uint208 rate;
        uint48 lastUpdate;
    }

    /// @notice Get the cached state of a vault's irm.
    /// @return rate The current rate.
    /// @return lastUpdate The last update timestamp.
    /// @dev Note that this state may be outdated. Use `computeInterestRateView` for the latest interest rate.
    mapping(address => IRState) public irState;

    /// @notice Deploy IRMTimeWeightedVariable.
    /// @param _targetUtilizationLower The lower bound of the utilization range where the interest rate does not adjust.
    /// @param _targetUtilizationUpper The upper bound of the utilization range where the interest rate does not adjust.
    /// @param _minRate The minimum interest rate for the model.
    /// @param _maxRate The maximum interest rate for the model.
    /// @param _halfLife The time it takes for the interest to halve when utilization is 0%.
    constructor(
        uint256 _targetUtilizationLower,
        uint256 _targetUtilizationUpper,
        uint256 _minRate,
        uint256 _maxRate,
        uint256 _initialRate,
        uint256 _halfLife
    ) {
        targetUtilizationLower = _targetUtilizationLower;
        targetUtilizationUpper = _targetUtilizationUpper;
        minRate = _minRate;
        maxRate = _maxRate;
        initialRate = _initialRate;
        halfLife = _halfLife;
    }

    /// @inheritdoc IIRM
    function computeInterestRate(address vault, uint256 cash, uint256 borrows) external returns (uint256) {
        if (msg.sender != vault) revert E_IRMUpdateUnauthorized();
        uint256 rate = computeInterestRateInternal(vault, cash, borrows);
        irState[vault] = IRState(uint208(rate), uint48(block.timestamp));
        return rate;
    }

    /// @inheritdoc IIRM
    function computeInterestRateView(address vault, uint256 cash, uint256 borrows) external view returns (uint256) {
        return computeInterestRateInternal(vault, cash, borrows);
    }

    /// @notice Compute the current interest rate for a vault.
    /// @param vault Address of the vault to compute the new interest rate for.
    /// @param cash Amount of assets held directly by the vault.
    /// @param borrows Amount of assets lent out to borrowers by the vault.
    function computeInterestRateInternal(address vault, uint256 cash, uint256 borrows)
        internal
        view
        returns (uint256)
    {
        // Initialize rate if this is the first call.
        IRState memory state = irState[vault];
        if (state.lastUpdate == 0) return initialRate;

        // Calculate utilization rate.
        uint256 totalAssets = cash + borrows;
        uint256 utilization = totalAssets == 0 ? 0 : borrows * WAD / totalAssets;

        // Calculate time
        uint256 deltaTime = block.timestamp - state.lastUpdate;

        if (utilization < targetUtilizationLower) {
            uint256 deltaUtilization = ((targetUtilizationLower - utilization) * WAD) / targetUtilizationLower;
            uint256 decayGrowth = halfLife * WAD * WAD + deltaUtilization * deltaUtilization * deltaTime;
            return boundRate(state.rate * halfLife * WAD * WAD / decayGrowth);
        } else if (utilization > targetUtilizationUpper) {
            uint256 deltaUtilization = ((utilization - targetUtilizationUpper) * WAD) / (WAD - targetUtilizationUpper);
            uint256 decayGrowth = halfLife * WAD * WAD + deltaUtilization * deltaUtilization * deltaTime;
            return boundRate(state.rate * decayGrowth / (halfLife * WAD * WAD));
        }
        // Utilization is within target range. Return last rate.
        return state.rate;
    }

    /// @notice Bound `rate` to `[minRate, maxRate]`.
    /// @param rate The rate to bound.
    /// @return The bounded rate.
    function boundRate(uint256 rate) internal view returns (uint256) {
        if (rate < minRate) return minRate;
        if (rate > maxRate) return maxRate;
        return rate;
    }
}
