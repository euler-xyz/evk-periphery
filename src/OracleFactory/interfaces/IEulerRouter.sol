// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title IEulerRouter
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Oracle resolver interface.
interface IEulerRouter {
    function resolveOracle(uint256 inAmount, address base, address quote)
        external
        view
        returns (uint256, address, address, address);

    function govSetConfig(address base, address quote, address oracle) external;
    function govSetResolvedVault(address vault, bool set) external;
}
