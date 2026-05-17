// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

/// @title IIRMNamed
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Optional interface for IRM contracts to self-identify their type to off-chain consumers and lenses.
/// @dev Implementations are expected to return a stable, unique identifier (e.g. the contract name).
interface IIRMNamed {
    /// @notice Returns a stable identifier for this IRM type.
    function name() external view returns (string memory);
}
