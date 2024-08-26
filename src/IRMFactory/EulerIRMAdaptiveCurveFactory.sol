// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseFactory} from "../BaseFactory/BaseFactory.sol";
import {IRMAdaptiveCurve} from "../IRM/IRMAdaptiveCurve.sol";

/// @title EulerIRMAdaptiveCurveFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for Adaptive Curve IRMs.
contract EulerIRMAdaptiveCurveFactory is BaseFactory {
    /// @notice Deploy IRMAdaptiveCurve using the Factory.
    /// @param _TARGET_UTILIZATION The utilization rate targeted by the interest rate model.
    /// @param _INITIAL_RATE_AT_TARGET The initial interest rate at target utilization.
    /// @param _MIN_RATE_AT_TARGET The minimum interest rate at target utilization that the model can adjust to.
    /// @param _MAX_RATE_AT_TARGET The maximum interest rate at target utilization that the model can adjust to.
    /// @param _CURVE_STEEPNESS The slope of interest rate above target. The line below target has inverse slope.
    /// @param _ADJUSTMENT_SPEED The speed at which the rate at target utilization is adjusted up or down.
    /// @return The deployment address.
    function deploy(
        int256 _TARGET_UTILIZATION,
        int256 _INITIAL_RATE_AT_TARGET,
        int256 _MIN_RATE_AT_TARGET,
        int256 _MAX_RATE_AT_TARGET,
        int256 _CURVE_STEEPNESS,
        int256 _ADJUSTMENT_SPEED
    ) external returns (address) {
        // Deploy IRM.
        IRMAdaptiveCurve irm = new IRMAdaptiveCurve(
            _TARGET_UTILIZATION,
            _INITIAL_RATE_AT_TARGET,
            _MIN_RATE_AT_TARGET,
            _MAX_RATE_AT_TARGET,
            _CURVE_STEEPNESS,
            _ADJUSTMENT_SPEED
        );

        // Store the deployment and return the address.
        deploymentInfo[address(irm)] = DeploymentInfo(msg.sender, uint96(block.timestamp));
        deployments.push(address(irm));
        emit ContractDeployed(address(irm), msg.sender, block.timestamp);
        return address(irm);
    }
}
