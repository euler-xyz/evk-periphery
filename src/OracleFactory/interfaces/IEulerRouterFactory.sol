// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {IFactory} from "../../BaseFactory/interfaces/IFactory.sol";

/// @title IEulerRouterFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for EulerRouter.
interface IEulerRouterFactory is IFactory {
    /// @notice Deploys a new EulerRouter.
    /// @param governor The governor of the router.
    /// @return The deployment address.
    function deploy(address governor) external returns (address);
}
