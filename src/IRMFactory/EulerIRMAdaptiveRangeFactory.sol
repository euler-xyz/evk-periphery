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
    /// @param targetUtilizationLower The lower bound of the utilization range where the interest rate does not adjust.
    /// @param targetUtilizationUpper The upper bound of the utilization range where the interest rate does not adjust.
    /// @param kink The utilization at which the slope increases.
    /// @param baseRate The interest rate at zero utilization.
    /// @param minFullRate The minimum interest rate at full utilization.
    /// @param maxFullRate The maximum interest rate at full utilization.
    /// @param initialFullRate The initial interest rate at full utilization.
    /// @param halfLife The time it takes for the interest to halve when adjusting the curve.
    /// @param kinkRatePercent The delta between full rate and base rate used for calculating kink rate.
    /// @return The deployment address.
    function deploy(
        uint256 targetUtilizationLower,
        uint256 targetUtilizationUpper,
        uint256 kink,
        uint256 baseRate,
        uint256 minFullRate,
        uint256 maxFullRate,
        uint256 initialFullRate,
        uint256 halfLife,
        uint256 kinkRatePercent
    ) external returns (address) {
        // Validate parameters.
        if (targetUtilizationLower < MIN_TARGET_UTILIZATION || targetUtilizationLower > MAX_TARGET_UTILIZATION) {
            revert IRMFactory_InvalidParams();
        }
        if (targetUtilizationUpper < MIN_TARGET_UTILIZATION || targetUtilizationUpper > MAX_TARGET_UTILIZATION) {
            revert IRMFactory_InvalidParams();
        }
        if (targetUtilizationLower > targetUtilizationUpper) revert IRMFactory_InvalidParams();
        if (kink < 0 || kink > 1e18) revert IRMFactory_InvalidParams();
        if (baseRate < MIN_BASE_RATE || baseRate > MAX_BASE_RATE) revert IRMFactory_InvalidParams();
        if (initialFullRate < minFullRate || initialFullRate > minFullRate) revert IRMFactory_InvalidParams();
        if (minFullRate < MIN_FULL_RATE || minFullRate > MAX_FULL_RATE) revert IRMFactory_InvalidParams();
        if (maxFullRate < MIN_FULL_RATE || maxFullRate > MAX_FULL_RATE) revert IRMFactory_InvalidParams();
        if (minFullRate > maxFullRate) revert IRMFactory_InvalidParams();
        if (halfLife < MIN_HALF_LIFE || halfLife > MAX_HALF_LIFE) revert IRMFactory_InvalidParams();
        if (kinkRatePercent < 0 || kinkRatePercent > 1e18) revert IRMFactory_InvalidParams();

        // Deploy IRM.
        IRMAdaptiveRange irm = new IRMAdaptiveRange(
            targetUtilizationLower,
            targetUtilizationUpper,
            kink,
            baseRate,
            minFullRate,
            maxFullRate,
            initialFullRate,
            halfLife,
            kinkRatePercent
        );

        // Verify that the IRM is functional.
        irm.computeInterestRateView(address(0), type(uint32).max, 0);
        irm.computeInterestRateView(address(0), type(uint32).max - kink, kink);
        irm.computeInterestRateView(address(0), 0, type(uint32).max);

        // Store the deployment and return the address.
        deploymentInfo[address(irm)] = DeploymentInfo(msg.sender, uint96(block.timestamp));
        deployments.push(address(irm));
        emit ContractDeployed(address(irm), msg.sender, block.timestamp);
        return address(irm);
    }
}
