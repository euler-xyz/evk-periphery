// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseFactory} from "../BaseFactory/BaseFactory.sol";
import {CapRiskSteward} from "../Governor/CapRiskSteward.sol";
import {ICapRiskStewardFactory} from "./interfaces/ICapRiskStewardFactory.sol";

/// @title CapRiskStewardFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A factory for cap risk steward contract.
contract CapRiskStewardFactory is BaseFactory, ICapRiskStewardFactory {
    /// @notice The multiplier in WAD units used to calculate the maximum allowable cap adjustment
    uint256 public constant MAX_ADJUST_FACTOR = 1.5e18;

    /// @notice The time in seconds needed to recharge the adjustment factor to the maximum
    uint256 public constant CHARGE_INTERVAL = 3 days;

    /// @notice The address of the governor access control factory
    address public immutable governorAccessControlFactory;

    /// @notice The address of the recognized IRM factory
    address public immutable irmFactory;

    /// @notice Thrown when a critical address parameter is zero
    error InvalidAddress();

    /// @notice Initializes the factory with the IRM factory address
    /// @param _governorAccessControlFactory The address of the governor access control factory
    /// @param _irmFactory The address of the recognized IRM factory
    constructor(address _governorAccessControlFactory, address _irmFactory) {
        if (_governorAccessControlFactory == address(0) || _irmFactory == address(0)) revert InvalidAddress();
        governorAccessControlFactory = _governorAccessControlFactory;
        irmFactory = _irmFactory;
    }

    /// @inheritdoc ICapRiskStewardFactory
    function deploy(address governorAccessControl, address IRMFactory, address admin)
        external
        override
        returns (address)
    {
        if (
            !BaseFactory(governorAccessControlFactory).isValidDeployment(governorAccessControl)
                || IRMFactory != irmFactory
        ) {
            revert InvalidAddress();
        }

        address capRiskSteward =
            address(new CapRiskSteward(governorAccessControl, IRMFactory, admin, MAX_ADJUST_FACTOR, CHARGE_INTERVAL));
        deploymentInfo[capRiskSteward] = DeploymentInfo(msg.sender, uint96(block.timestamp));
        deployments.push(capRiskSteward);
        emit ContractDeployed(capRiskSteward, msg.sender, block.timestamp);
        return capRiskSteward;
    }
}
