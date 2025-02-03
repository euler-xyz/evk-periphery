// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {IFactory} from "../../BaseFactory/interfaces/IFactory.sol";

/// @title IEulerKinkIRMFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for EulerKinkIRM.
interface IEulerKinkIRMFactory is IFactory {
    /// @notice Deploys a new EulerKinkIRM.
    /// @param baseRate The base rate of the IRM.
    /// @param slope1 The slope of the IRM at the first kink.
    /// @param slope2 The slope of the IRM at the second kink.
    /// @param kink The kink of the IRM.
    /// @return The deployment address.
    function deploy(uint256 baseRate, uint256 slope1, uint256 slope2, uint32 kink) external returns (address);
}
