// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseFactory} from "../BaseFactory/BaseFactory.sol";
import {IRMLinearKink} from "evk/InterestRateModels/IRMLinearKink.sol";
import {IEulerKinkIRMFactory} from "./interfaces/IEulerKinkIRMFactory.sol";

/// @title EulerKinkIRMFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A minimal factory for Kink IRMs.
contract EulerKinkIRMFactory is BaseFactory, IEulerKinkIRMFactory {
    // corresponds to 1000% APY
    uint256 internal constant MAX_ALLOWED_INTEREST_RATE = 75986279153383989049;

    /// @notice Error thrown when the computed interest rate exceeds the maximum allowed limit.
    error IRMFactory_ExcessiveInterestRate();

    /// @notice Deploys a new IRMLinearKink.
    /// @param baseRate Base interest rate applied when utilization is equal zero
    /// @param slope1 Slope of the function before the kink
    /// @param slope2 Slope of the function after the kink
    /// @param kink Utilization at which the slope of the interest rate function changes. In type(uint32).max scale
    /// @return The deployment address.
    function deploy(uint256 baseRate, uint256 slope1, uint256 slope2, uint32 kink)
        external
        override
        returns (address)
    {
        IRMLinearKink irm = new IRMLinearKink(baseRate, slope1, slope2, kink);

        // verify if the IRM is functional
        irm.computeInterestRateView(address(0), type(uint32).max, 0);
        irm.computeInterestRateView(address(0), type(uint32).max - kink, kink);
        uint256 maxInterestRate = irm.computeInterestRateView(address(0), 0, type(uint32).max);

        if (maxInterestRate > MAX_ALLOWED_INTEREST_RATE) revert IRMFactory_ExcessiveInterestRate();

        deploymentInfo[address(irm)] = DeploymentInfo(msg.sender, uint96(block.timestamp));
        deployments.push(address(irm));
        emit ContractDeployed(address(irm), msg.sender, block.timestamp);
        return address(irm);
    }
}
