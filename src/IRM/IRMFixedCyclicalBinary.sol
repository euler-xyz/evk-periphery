// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IIRM} from "evk/InterestRateModels/IIRM.sol";

/// @title IRMFixedCyclicalBinary
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Implementation of an interest rate model, where interest rate cycles between two fixed values,
contract IRMFixedCyclicalBinary is IIRM {
    /// @notice Interest rate applied during the first part of the cycle
    uint256 public immutable primaryRate;
    /// @notice Interest rate applied during the second part of the cycle
    uint256 public immutable secondaryRate;
    /// @notice Duration of the primary part of the cycle in seconds
    uint256 public immutable primaryDuration;
    /// @notice Duration of the secondary part of the cycle in seconds
    uint256 public immutable secondaryDuration;
    /// @notice Timestamp of the start of the first cycle
    uint256 public immutable startTimestamp;

    /// @notice Error thrown when start timestamp is in the future
    error BadStartTimestamp();
    /// @notice Error thrown when duration of either primary or secondary part of the cycle is zero
    /// or when the whole cycle duration overflows uint
    error BadDuration();

    /// @notice Creates a fixed cyclical binary interest rate model
    /// @param primaryRate_ Interest rate applied during the first part of the cycle
    /// @param secondaryRate_ Interest rate applied during the second part of the cycle
    /// @param primaryDuration_ Duration of the primary part of the cycle in seconds
    /// @param secondaryDuration_ Duration of the secondary part of the cycle in seconds
    /// @param startTimestamp_ Timestamp of the start of the first cycle
    constructor(
        uint256 primaryRate_,
        uint256 secondaryRate_,
        uint256 primaryDuration_,
        uint256 secondaryDuration_,
        uint256 startTimestamp_
    ) {
        if (startTimestamp_ > block.timestamp) revert BadStartTimestamp();
        if (
            primaryDuration_ == 0 || secondaryDuration_ == 0
                || (type(uint256).max - primaryDuration_ < secondaryDuration_)
        ) revert BadDuration();

        primaryRate = primaryRate_;
        secondaryRate = secondaryRate_;
        primaryDuration = primaryDuration_;
        secondaryDuration = secondaryDuration_;
        startTimestamp = startTimestamp_;
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

    function computeInterestRateInternal() internal view returns (uint256) {
        uint256 timeSinceStart = block.timestamp - startTimestamp;

        return timeSinceStart % (primaryDuration + secondaryDuration) <= primaryDuration ? primaryRate : secondaryRate;
    }
}
