// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseFactory} from "../BaseFactory/BaseFactory.sol";
import {IRMFixedCyclicalBinary} from "../IRM/IRMFixedCyclicalBinary.sol";
import {IEulerFixedCyclicalBinaryIRMFactory} from "./interfaces/IEulerFixedCyclicalBinaryIRMFactory.sol";

/// @title EulerFixedCyclicalBinaryIRMFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for Fixed Cyclical Binary IRMs.
contract EulerFixedCyclicalBinaryIRMFactory is BaseFactory, IEulerFixedCyclicalBinaryIRMFactory {
    // corresponds to 1000% APY
    uint256 internal constant MAX_ALLOWED_INTEREST_RATE = 75986279153383989049;

    /// @notice Error thrown when the computed interest rate exceeds the maximum allowed limit.
    error IRMFactory_ExcessiveInterestRate();

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
    ) external override returns (address) {
        if (primaryRate > MAX_ALLOWED_INTEREST_RATE || secondaryRate > MAX_ALLOWED_INTEREST_RATE) {
            revert IRMFactory_ExcessiveInterestRate();
        }

        IRMFixedCyclicalBinary irm =
            new IRMFixedCyclicalBinary(primaryRate, secondaryRate, primaryDuration, secondaryDuration, startTimestamp);

        deploymentInfo[address(irm)] = DeploymentInfo(msg.sender, uint96(block.timestamp));
        deployments.push(address(irm));
        emit ContractDeployed(address(irm), msg.sender, block.timestamp);
        return address(irm);
    }
}
