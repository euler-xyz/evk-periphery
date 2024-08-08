// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

/// @title IFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory interface for deploying contracts.
interface IFactory {
    struct DeploymentInfo {
        /// @notice The sender of the deployment call.
        address deployer;
        /// @notice The timestamp when the contract was deployed.
        uint96 deployedAt;
    }

    /// @notice An instance of a contract was deployed.
    /// @param deployedContract The deployment address of the contract.
    /// @param deployer The sender of the deployment call.
    /// @param deployedAt The deployment timestamp of the contract.
    event ContractDeployed(address indexed deployedContract, address indexed deployer, uint256 deployedAt);

    /// @notice Error thrown when the query is incorrect.
    error Factory_BadQuery();

    /// @notice Contracts deployed by the factory.
    function getDeploymentInfo(address contractAddress) external view returns (address deployer, uint96 deployedAt);

    /// @notice Checks if the deployment at the given address is valid.
    /// @param contractAddress The address of the contract to check.
    /// @return True if the deployment is valid, false otherwise.
    function isValidDeployment(address contractAddress) external view returns (bool);

    /// @notice Returns the number of contracts deployed by the factory.
    /// @return The number of deployed contracts.
    function getDeploymentsListLength() external view returns (uint256);

    /// @notice Returns a slice of the list of deployments.
    /// @param start The starting index of the slice.
    /// @param end The ending index of the slice (exclusive).
    /// @return list An array of addresses of the deployed contracts in the specified range.
    function getDeploymentsListSlice(uint256 start, uint256 end) external view returns (address[] memory list);
}
