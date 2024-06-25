// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseFactory} from "../BaseFactory/BaseFactory.sol";
import {EulerRouter} from "euler-price-oracle/EulerRouter.sol";
import {IEulerRouterFactory} from "./interfaces/IEulerRouterFactory.sol";

/// @title EulerRouterFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for EulerRouter.
contract EulerRouterFactory is BaseFactory, IEulerRouterFactory {
    /// @notice Deploys a new EulerRouter.
    /// @param governor The governor of the router.
    /// @return The deployment address.
    function deploy(address governor) external returns (address) {
        address router = address(new EulerRouter(governor));
        deploymentInfo[router] = DeploymentInfo(msg.sender, uint96(block.timestamp));
        emit ContractDeployed(router, msg.sender, block.timestamp);
        return router;
    }
}
