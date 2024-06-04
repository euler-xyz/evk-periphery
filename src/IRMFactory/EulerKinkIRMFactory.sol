// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IRMLinearKink} from "evk/InterestRateModels/IRMLinearKink.sol";

/// @title EulerKinkIRMFactory
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for Kink IRMs.
contract EulerKinkIRMFactory {
    // corresponds to 1000% APY
    uint256 internal constant MAX_ALLOWED_INTEREST_RATE = 75986276241127470105;

    struct DeploymentInfo {
        /// @notice The sender of the deployment call.
        address deployer;
        /// @notice The timestamp when the IRM was deployed.
        uint96 deployedAt;
    }

    /// @notice IRMs deployed by the factory.
    mapping(address irm => DeploymentInfo) public deployments;

    /// @notice An instance of IRMLinearKink was deployed.
    /// @param irm The deployment address of the IRM.
    /// @param deployer The sender of the deployment call.
    /// @param deployedAt The deployment timestamp of the IRM.
    event IRMDeployed(address indexed irm, address indexed deployer, uint256 deployedAt);

    /// @notice Error thrown when the kink value is incorrect.
    error IRMFactory_IncorrectKinkValue();

    /// @notice Error thrown when the computed interest rate exceeds the maximum allowed limit.
    error IRMFactory_ExcessiveInterestRate();

    /// @notice Deploys a new IRMLinearKink.
    /// @param baseRate Base interest rate applied when utilization is equal zero
    /// @param slope1 Slope of the function before the kink
    /// @param slope2 Slope of the function after the kink
    /// @param kink Utilization at which the slope of the interest rate function changes. In type(uint32).max scale
    /// @return The deployment address.
    function deploy(uint256 baseRate, uint256 slope1, uint256 slope2, uint256 kink) external returns (address) {
        if (kink > type(uint32).max) revert IRMFactory_IncorrectKinkValue();

        IRMLinearKink irm = new IRMLinearKink(baseRate, slope1, slope2, kink);

        // verify if the IRM is functional
        irm.computeInterestRateView(address(0), type(uint32).max, 0);
        irm.computeInterestRateView(address(0), type(uint32).max - kink, kink);
        uint256 maxInterestRate = irm.computeInterestRateView(address(0), 0, type(uint32).max);

        if (maxInterestRate > MAX_ALLOWED_INTEREST_RATE) revert IRMFactory_ExcessiveInterestRate();

        deployments[address(irm)] = DeploymentInfo(msg.sender, uint96(block.timestamp));
        emit IRMDeployed(address(irm), msg.sender, block.timestamp);
        return address(irm);
    }

    function isValidDeployment(address irm) external view returns (bool) {
        return deployments[irm].deployedAt != 0;
    }
}
