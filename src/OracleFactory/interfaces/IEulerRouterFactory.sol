// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title IEulerRouterFactory
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for EulerRouter.
interface IEulerRouterFactory {
    struct DeploymentInfo {
        /// @notice The sender of the deployment call.
        address deployer;
        /// @notice The timestamp when the adapter was added.
        uint96 deployedAt;
    }

    /// @notice An instance of EulerRouter was deployed.
    /// @param router The deployment address of the router.
    /// @param deployer The sender of the deployment call.
    /// @param deployedAt The deployment timestamp of the router.
    event RouterDeployed(address indexed router, address indexed deployer, uint256 deployedAt);

    /// @notice Routers deployed by the factory.
    function deployments(address router) external view returns (address, uint256);

    /// @notice Deploys a new EulerRouter.
    /// @param governor The governor of the router.
    /// @return The deployment address.
    function deploy(address governor) external returns (address);

    function isValidDeployment(address router) external view returns (bool);
}
