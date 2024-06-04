// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IEulerRouterFactory} from "./interfaces/IEulerRouterFactory.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";

/// @title EulerRouterFactory
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for EulerRouter.
contract EulerRouterFactory is IEulerRouterFactory {
    /// @notice Routers deployed by the factory.
    mapping(address router => DeploymentInfo) internal _deployments;

    function deployments(address router) external view returns (address, uint256) {
        DeploymentInfo memory deployment = _deployments[router];
        return (deployment.deployer, deployment.deployedAt);
    }

    /// @notice Deploys a new EulerRouter.
    /// @param governor The governor of the router.
    /// @return The deployment address.
    function deploy(address governor) external returns (address) {
        address router = address(new EulerRouter(governor));
        _deployments[router] = DeploymentInfo(msg.sender, uint96(block.timestamp));
        emit RouterDeployed(router, msg.sender, block.timestamp);
        return router;
    }

    function isValidDeployment(address router) external view returns (bool) {
        return _deployments[router].deployedAt != 0;
    }
}
