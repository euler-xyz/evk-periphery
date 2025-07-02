// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IIRM} from "evk/InterestRateModels/IIRM.sol";

/// @title IRMLinearKinky
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Implementation of an interest rate model, where interest rate grows linearly with utilization, and spikes
/// non-linearly after reaching kink
contract IRMLinearKinky is IIRM {
    /// @notice Base interest rate applied when utilization is equal zero
    uint256 public immutable baseRate;
    /// @notice Slope of the function before the kink
    uint256 public immutable slope;
    /// @notice Shape parameter for the non-linear part of the curve. Typically between 0 and 100.
    uint256 public immutable shape;
    /// @notice Utilization at which the slope of the interest rate function changes. In type(uint32).max scale.
    uint256 public immutable kink;
    /// @notice Interest rate in second percent yield (SPY) at which the interest rate function is capped
    uint256 public immutable cutoff;

    /// @notice Remaining kink helper constant.
    uint256 internal immutable kinkRemaining;

    /// @notice Creates a new linear kinky interest rate model
    /// @param baseRate_ Base interest rate applied when utilization is equal zero
    /// @param slope_ Slope of the function before the kink
    /// @param shape_ Shape parameter for the non-linear part of the curve. Typically between 0 and 100
    /// @param kink_ Utilization at which the slope of the interest rate function changes. In type(uint32).max scale
    /// @param cutoff_ Interest rate in second percent yield (SPY) at which the interest rate function is capped
    constructor(uint256 baseRate_, uint256 slope_, uint256 shape_, uint32 kink_, uint256 cutoff_) {
        baseRate = baseRate_;
        slope = slope_;
        shape = shape_;
        kink = kink_;
        cutoff = cutoff_;
        kinkRemaining = type(uint32).max - kink;
    }

    /// @inheritdoc IIRM
    function computeInterestRate(address vault, uint256 cash, uint256 borrows)
        external
        view
        override
        returns (uint256)
    {
        if (msg.sender != vault) revert E_IRMUpdateUnauthorized();

        return computeInterestRateInternal(vault, cash, borrows);
    }

    /// @inheritdoc IIRM
    function computeInterestRateView(address vault, uint256 cash, uint256 borrows)
        external
        view
        override
        returns (uint256)
    {
        return computeInterestRateInternal(vault, cash, borrows);
    }

    function computeInterestRateInternal(address, uint256 cash, uint256 borrows) internal view returns (uint256) {
        uint256 totalAssets = cash + borrows;

        uint32 utilization = totalAssets == 0
            ? 0 // empty pool arbitrarily given utilization of 0
            : uint32(borrows * type(uint32).max / totalAssets);

        uint256 ir = baseRate;

        if (utilization <= kink) {
            ir += utilization * slope;
        } else {
            ir += kink * slope;

            uint256 utilizationOverKink;
            uint256 utilizationRemaining;
            unchecked {
                utilizationOverKink = utilization - kink;
                utilizationRemaining = type(uint32).max - utilization;
            }

            if (utilizationRemaining == 0) return cutoff;

            uint256 slopeUtilizationOverKink = slope * utilizationOverKink;

            ir += slopeUtilizationOverKink * kinkRemaining * (1 + shape) / utilizationRemaining
                - slopeUtilizationOverKink * shape;
        }

        return ir > cutoff ? cutoff : ir;
    }
}
