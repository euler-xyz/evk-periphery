// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseFactory} from "../BaseFactory/BaseFactory.sol";
import {IRMAdaptiveRange} from "../IRM/IRMAdaptiveRange.sol";

/// @title EulerIRMAdaptiveRangeFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for Adaptive Range IRMs.
contract EulerIRMAdaptiveRangeFactory is BaseFactory {
    uint256 internal constant SECONDS_PER_YEAR = 365.2425 days;
    uint256 internal constant MIN_TARGET_UTILIZATION = 0.1e18;
    uint256 internal constant MAX_TARGET_UTILIZATION = 0.9e18;
    uint256 internal constant MIN_BASE_RATE = 0;
    uint256 internal constant MAX_BASE_RATE = 100e18 / SECONDS_PER_YEAR;
    uint256 internal constant MIN_FULL_RATE = 0.1e18 / SECONDS_PER_YEAR;
    uint256 internal constant MAX_FULL_RATE = 10000e18 / SECONDS_PER_YEAR;
    uint256 internal constant MIN_HALF_LIFE = 1 hours;
    uint256 internal constant MAX_HALF_LIFE = SECONDS_PER_YEAR;

    /// @notice Error thrown when the constructor parameters are invalid.
    error IRMFactory_InvalidParams();

    /// @notice Deploys a new IRMAdaptiveRange.
    /// @param MIN_TARGET_UTIL The lower bound of the utilization range where the interest rate does not adjust.
    /// @param MAX_TARGET_UTIL The upper bound of the utilization range where the interest rate does not adjust.
    /// @param VERTEX_UTILIZATION The utilization at which the slope increases.
    /// @param ZERO_UTIL_RATE The interest rate at zero utilization.
    /// @param MIN_FULL_UTIL_RATE The minimum interest rate at full utilization.
    /// @param MAX_FULL_UTIL_RATE The maximum interest rate at full utilization.
    /// @param INITIAL_FULL_UTIL_RATE The initial interest rate at full utilization.
    /// @param RATE_HALF_LIFE The time it takes for the interest to halve when adjusting the curve.
    /// @param VERTEX_RATE_PERCENT The delta between full rate and base rate used for calculating VERTEX_UTILIZATION
    /// rate.
    /// @return The deployment address.
    function deploy(
        uint256 MIN_TARGET_UTIL,
        uint256 MAX_TARGET_UTIL,
        uint256 VERTEX_UTILIZATION,
        uint256 ZERO_UTIL_RATE,
        uint256 MIN_FULL_UTIL_RATE,
        uint256 MAX_FULL_UTIL_RATE,
        uint256 INITIAL_FULL_UTIL_RATE,
        uint256 RATE_HALF_LIFE,
        uint256 VERTEX_RATE_PERCENT
    ) external returns (address) {
        // Validate parameters.
        if (MIN_TARGET_UTIL < MIN_TARGET_UTILIZATION || MIN_TARGET_UTIL > MAX_TARGET_UTILIZATION) {
            revert IRMFactory_InvalidParams();
        }
        if (MAX_TARGET_UTIL < MIN_TARGET_UTILIZATION || MAX_TARGET_UTIL > MAX_TARGET_UTILIZATION) {
            revert IRMFactory_InvalidParams();
        }
        if (MIN_TARGET_UTIL > MAX_TARGET_UTIL) revert IRMFactory_InvalidParams();
        if (VERTEX_UTILIZATION < 0 || VERTEX_UTILIZATION > 1e18) revert IRMFactory_InvalidParams();
        if (ZERO_UTIL_RATE < MIN_BASE_RATE || ZERO_UTIL_RATE > MAX_BASE_RATE) revert IRMFactory_InvalidParams();
        if (INITIAL_FULL_UTIL_RATE < MIN_FULL_UTIL_RATE || INITIAL_FULL_UTIL_RATE > MIN_FULL_UTIL_RATE) {
            revert IRMFactory_InvalidParams();
        }
        if (MIN_FULL_UTIL_RATE < MIN_FULL_RATE || MIN_FULL_UTIL_RATE > MAX_FULL_RATE) revert IRMFactory_InvalidParams();
        if (MAX_FULL_UTIL_RATE < MIN_FULL_RATE || MAX_FULL_UTIL_RATE > MAX_FULL_RATE) revert IRMFactory_InvalidParams();
        if (MIN_FULL_UTIL_RATE > MAX_FULL_UTIL_RATE) revert IRMFactory_InvalidParams();
        if (RATE_HALF_LIFE < MIN_HALF_LIFE || RATE_HALF_LIFE > MAX_HALF_LIFE) revert IRMFactory_InvalidParams();
        if (VERTEX_RATE_PERCENT < 0 || VERTEX_RATE_PERCENT > 1e18) revert IRMFactory_InvalidParams();

        // Deploy IRM.
        IRMAdaptiveRange irm = new IRMAdaptiveRange(
            MIN_TARGET_UTIL,
            MAX_TARGET_UTIL,
            VERTEX_UTILIZATION,
            ZERO_UTIL_RATE,
            MIN_FULL_UTIL_RATE,
            MAX_FULL_UTIL_RATE,
            INITIAL_FULL_UTIL_RATE,
            RATE_HALF_LIFE,
            VERTEX_RATE_PERCENT
        );

        // Verify that the IRM is functional.
        irm.computeInterestRateView(address(0), type(uint32).max, 0);
        irm.computeInterestRateView(address(0), type(uint32).max - VERTEX_UTILIZATION, VERTEX_UTILIZATION);
        irm.computeInterestRateView(address(0), 0, type(uint32).max);

        // Store the deployment and return the address.
        deploymentInfo[address(irm)] = DeploymentInfo(msg.sender, uint96(block.timestamp));
        deployments.push(address(irm));
        emit ContractDeployed(address(irm), msg.sender, block.timestamp);
        return address(irm);
    }
}
