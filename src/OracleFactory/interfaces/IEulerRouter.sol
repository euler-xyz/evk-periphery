// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

/// @title IEulerRouter
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Oracle resolver interface.
interface IEulerRouter {
    function name() external view returns (string memory);
    function governor() external view returns (address);
    function fallbackOracle() external view returns (address);
    function getConfiguredOracle(address base, address quote) external view returns (address);
    function resolvedVaults(address vault) external view returns (address);
    function transferGovernance(address newGovernor) external;
    function resolveOracle(uint256 inAmount, address base, address quote)
        external
        view
        returns (uint256, address, address, address);

    function govSetConfig(address base, address quote, address oracle) external;
    function govSetResolvedVault(address vault, bool set) external;
}
