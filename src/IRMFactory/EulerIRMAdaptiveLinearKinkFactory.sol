// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseFactory} from "../BaseFactory/BaseFactory.sol";
import {IRMAdaptiveLinearKink} from "../IRM/IRMAdaptiveLinearKink.sol";

/// @title EulerIRMAdaptiveLinearKinkFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for Adaptive Linear Kink IRMs.
contract EulerIRMAdaptiveLinearKinkFactory is BaseFactory {
    int256 internal constant SECONDS_PER_YEAR = 365.2425 days;
    int256 internal constant MIN_KINK_RATE = 0.01e18 / SECONDS_PER_YEAR;
    int256 internal constant MAX_KINK_RATE = 1000e18 / SECONDS_PER_YEAR;
    int256 internal constant MIN_SLOPE = 1.01e18;
    int256 internal constant MAX_SLOPE = 100e18;
    int256 internal constant MIN_SPEED = 1e18 / SECONDS_PER_YEAR;
    int256 internal constant MAX_SPEED = 10000e18 / SECONDS_PER_YEAR;

    /// @notice Error thrown when the constructor parameters are invalid.
    error IRMFactory_InvalidParams();

    /// @notice Deploys a new IRMAdaptiveLinearKink.
    /// @param kink The utilization rate targeted by the interest rate model.
    /// @param initialKinkRate The initial interest rate at kink.
    /// @param minKinkRate The minimum interest rate at kink that the model can adjust to.
    /// @param maxKinkRate The maximum interest rate at kink that the model can adjust to.
    /// @param slope The steepness of interest rate function below and above the kink.
    /// @param adjustmentSpeed The speed at which the rate at kink is adjusted up or down.
    /// @return The deployment address.
    function deploy(
        int256 kink,
        int256 initialKinkRate,
        int256 minKinkRate,
        int256 maxKinkRate,
        int256 slope,
        int256 adjustmentSpeed
    ) external returns (address) {
        // Validate parameters.
        if (kink < 0 || kink > 1e18) revert IRMFactory_InvalidParams();
        if (initialKinkRate < minKinkRate || initialKinkRate > maxKinkRate) revert IRMFactory_InvalidParams();
        if (minKinkRate < MIN_KINK_RATE || minKinkRate > MAX_KINK_RATE) revert IRMFactory_InvalidParams();
        if (maxKinkRate < MIN_KINK_RATE || maxKinkRate > MAX_KINK_RATE) revert IRMFactory_InvalidParams();
        if (minKinkRate > maxKinkRate) revert IRMFactory_InvalidParams();
        if (slope < MIN_SLOPE || slope > MAX_SLOPE) revert IRMFactory_InvalidParams();
        if (adjustmentSpeed < MIN_SPEED || adjustmentSpeed > MAX_SPEED) revert IRMFactory_InvalidParams();

        // Deploy IRM.
        IRMAdaptiveLinearKink irm =
            new IRMAdaptiveLinearKink(kink, initialKinkRate, minKinkRate, maxKinkRate, slope, adjustmentSpeed);

        // Verify that the IRM is functional.
        irm.computeInterestRateView(address(0), type(uint32).max, 0);
        irm.computeInterestRateView(address(0), type(uint32).max - uint256(kink), uint256(kink));
        irm.computeInterestRateView(address(0), 0, type(uint32).max);

        // Store the deployment and return the address.
        deploymentInfo[address(irm)] = DeploymentInfo(msg.sender, uint96(block.timestamp));
        deployments.push(address(irm));
        emit ContractDeployed(address(irm), msg.sender, block.timestamp);
        return address(irm);
    }
}
