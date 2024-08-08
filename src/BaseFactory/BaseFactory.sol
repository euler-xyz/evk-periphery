// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IFactory} from "./interfaces/IFactory.sol";

/// @title BaseFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for deploying various contracts.
abstract contract BaseFactory is IFactory {
    /// @notice Contracts deployed by the factory.
    mapping(address => DeploymentInfo) internal deploymentInfo;

    /// @notice An array of addresses of all the contracts deployed by the factory
    address[] public deployments;

    /// @inheritdoc IFactory
    function getDeploymentInfo(address contractAddress) external view returns (address deployer, uint96 deployedAt) {
        DeploymentInfo memory info = deploymentInfo[contractAddress];
        return (info.deployer, info.deployedAt);
    }

    /// @inheritdoc IFactory
    function isValidDeployment(address contractAddress) external view returns (bool) {
        return deploymentInfo[contractAddress].deployedAt != 0;
    }

    /// @inheritdoc IFactory
    function getDeploymentsListLength() external view returns (uint256) {
        return deployments.length;
    }

    /// @inheritdoc IFactory
    function getDeploymentsListSlice(uint256 start, uint256 end) external view returns (address[] memory list) {
        if (end == type(uint256).max) end = deployments.length;
        if (end < start || end > deployments.length) revert Factory_BadQuery();

        list = new address[](end - start);
        for (uint256 i; i < end - start; ++i) {
            list[i] = deployments[start + i];
        }
    }
}
