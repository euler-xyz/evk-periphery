// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {IFactory} from "../../BaseFactory/interfaces/IFactory.sol";

/// @title IGovernorAccessControlEmergencyFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A factory for governor access control emergency contract configured with timelock controllers.
interface IGovernorAccessControlEmergencyFactory is IFactory {
    /// @notice Parameters for deploying a TimelockController
    /// @param minDelay The minimum delay before a proposal can be executed
    /// @param proposers Addresses that can propose operations
    /// @param cancellers Addresses that can cancel operations
    /// @param executors Addresses that can execute operations after the minDelay period
    struct TimelockControllerParams {
        uint256 minDelay;
        address[] proposers;
        address[] cancellers;
        address[] executors;
    }

    /// @notice Deploys a new governor contracts suite.
    /// @param adminTimelockControllerParams The parameters for the admin timelock controller.
    /// @param wildcardTimelockControllerParams The parameters for the wildcard timelock controller.
    /// @param governorAccessControlEmergencyGuardians The addresses that will be granted emergency roles
    /// @return adminTimelockController The address of the admin timelock controller.
    /// @return wildcardTimelockController The address of the wildcard timelock controller.
    /// @return governorAccessControlEmergency The address of the governor access control emergency contract.
    function deploy(
        TimelockControllerParams memory adminTimelockControllerParams,
        TimelockControllerParams memory wildcardTimelockControllerParams,
        address[] memory governorAccessControlEmergencyGuardians
    ) external returns (address, address, address);
}
