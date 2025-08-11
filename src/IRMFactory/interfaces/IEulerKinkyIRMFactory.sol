// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {IFactory} from "../../BaseFactory/interfaces/IFactory.sol";

/// @title IEulerKinkyIRMFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for EulerKinkyIRM.
interface IEulerKinkyIRMFactory is IFactory {
    /// @notice Deploys a new EulerKinkyIRM.
    /// @param baseRate The base rate of the IRM.
    /// @param slope Slope of the function before the kink.
    /// @param shape Shape parameter for the non-linear part of the curve. Typically between 0 and 100.
    /// @param kink Utilization at which the slope of the interest rate function changes. In type(uint32).max scale.
    /// @param cutoff Interest rate in second percent yield (SPY) at which the interest rate function is capped
    /// @return The deployment address.
    function deploy(uint256 baseRate, uint256 slope, uint256 shape, uint32 kink, uint256 cutoff)
        external
        returns (address);
}
