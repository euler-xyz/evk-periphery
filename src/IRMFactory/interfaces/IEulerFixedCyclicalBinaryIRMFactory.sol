// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {IFactory} from "../../BaseFactory/interfaces/IFactory.sol";

/// @title IEulerFixedCyclicalBinaryRMFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for EulerFixedCyclicalBinaryIRM.
interface IEulerFixedCyclicalBinaryIRMFactory is IFactory {
    /// @notice Deploys a new IRMFixedCyclicalBinary.
    /// @param primaryRate Interest rate applied during the first part of the cycle
    /// @param secondaryRate Interest rate applied during the second part of the cycle
    /// @param primaryDuration Duration of the primary part of the cycle in seconds
    /// @param secondaryDuration Duration of the secondary part of the cycle in seconds
    /// @param startTimestamp Timestamp of the start of the first cycle
    /// @return The deployment address.
    function deploy(
        uint256 primaryRate,
        uint256 secondaryRate,
        uint256 primaryDuration,
        uint256 secondaryDuration,
        uint256 startTimestamp
    ) external returns (address);
}
