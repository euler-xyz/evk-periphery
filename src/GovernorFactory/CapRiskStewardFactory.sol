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
    /// @notice The address of the recognized IRM factory
    address public immutable irmFactory;

    /// @notice Thrown when a critical address parameter is zero
    error InvalidAddress();

    /// @notice Initializes the factory with the IRM factory address
    /// @param _irmFactory The address of the recognized IRM factory
    constructor(address _irmFactory) {
        if (_irmFactory == address(0)) revert InvalidAddress();
        irmFactory = _irmFactory;
    }

    /// @inheritdoc ICapRiskStewardFactory
    function deploy(address governorAccessControl, address IRMFactory, address admin)
        external
        override
        returns (address)
    {
        if (IRMFactory != irmFactory) revert InvalidAddress();

        address capRiskSteward = address(new CapRiskSteward(governorAccessControl, IRMFactory, admin));
        deploymentInfo[capRiskSteward] = DeploymentInfo(msg.sender, uint96(block.timestamp));
        deployments.push(capRiskSteward);
        emit ContractDeployed(capRiskSteward, msg.sender, block.timestamp);
        return capRiskSteward;
    }
}
