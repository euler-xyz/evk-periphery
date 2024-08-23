// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseFactory} from "../BaseFactory/BaseFactory.sol";
import {IRMAdaptiveCurve} from "../IRM/IRMAdaptiveCurve.sol";

/// @title EulerIRMAdaptiveCurveFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for Adaptive Linear Kink IRMs.
contract EulerIRMAdaptiveCurveFactory is BaseFactory {
    int256 internal constant SECONDS_PER_YEAR = 365.2425 days;
    int256 internal constant MIN_KINK_RATE = 0.01e18 / SECONDS_PER_YEAR;
    int256 internal constant MAX_KINK_RATE = 1000e18 / SECONDS_PER_YEAR;
    int256 internal constant MIN_SLOPE = 1.01e18;
    int256 internal constant MAX_SLOPE = 100e18;
    int256 internal constant MIN_SPEED = 1e18 / SECONDS_PER_YEAR;
    int256 internal constant MAX_SPEED = 10000e18 / SECONDS_PER_YEAR;

    /// @notice Error thrown when the constructor parameters are invalid.
    error IRMFactory_InvalidParams();

    /// @notice Deploys a new IRMAdaptiveCurve.
    /// @param kink The utilization rate targeted by the interest rate model.
    /// @param INITIAL_RATE_AT_TARGET The initial interest rate at kink.
    /// @param MIN_RATE_AT_TARGET The minimum interest rate at kink that the model can adjust to.
    /// @param MAX_RATE_AT_TARGET The maximum interest rate at kink that the model can adjust to.
    /// @param CURVE_STEEPNESS The steepness of interest rate function below and above the kink.
    /// @param ADJUSTMENT_SPEED The speed at which the rate at kink is adjusted up or down.
    /// @return The deployment address.
    function deploy(
        int256 kink,
        int256 INITIAL_RATE_AT_TARGET,
        int256 MIN_RATE_AT_TARGET,
        int256 MAX_RATE_AT_TARGET,
        int256 CURVE_STEEPNESS,
        int256 ADJUSTMENT_SPEED
    ) external returns (address) {
        // Validate parameters.
        if (kink < 0 || kink > 1e18) revert IRMFactory_InvalidParams();
        if (INITIAL_RATE_AT_TARGET < MIN_RATE_AT_TARGET || INITIAL_RATE_AT_TARGET > MAX_RATE_AT_TARGET) {
            revert IRMFactory_InvalidParams();
        }
        if (MIN_RATE_AT_TARGET < MIN_KINK_RATE || MIN_RATE_AT_TARGET > MAX_KINK_RATE) revert IRMFactory_InvalidParams();
        if (MAX_RATE_AT_TARGET < MIN_KINK_RATE || MAX_RATE_AT_TARGET > MAX_KINK_RATE) revert IRMFactory_InvalidParams();
        if (MIN_RATE_AT_TARGET > MAX_RATE_AT_TARGET) revert IRMFactory_InvalidParams();
        if (CURVE_STEEPNESS < MIN_SLOPE || CURVE_STEEPNESS > MAX_SLOPE) revert IRMFactory_InvalidParams();
        if (ADJUSTMENT_SPEED < MIN_SPEED || ADJUSTMENT_SPEED > MAX_SPEED) revert IRMFactory_InvalidParams();

        // Deploy IRM.
        IRMAdaptiveCurve irm = new IRMAdaptiveCurve(
            kink, INITIAL_RATE_AT_TARGET, MIN_RATE_AT_TARGET, MAX_RATE_AT_TARGET, CURVE_STEEPNESS, ADJUSTMENT_SPEED
        );

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
