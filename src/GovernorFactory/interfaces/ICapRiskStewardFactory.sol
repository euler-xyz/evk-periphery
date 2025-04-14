// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import {IFactory} from "../../BaseFactory/interfaces/IFactory.sol";

/// @title ICapRiskStewardFactory
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A factory for cap risk steward contract.
interface ICapRiskStewardFactory is IFactory {
    /// @notice Deploys a new cap risk steward contract.
    /// @param governorAccessControl The address of the governor contract that will execute the actual parameter changes
    /// that is installed on the target vault
    /// @param irmFactory The address of the recognized IRM factory
    /// @param admin The address to be granted admin privileges in the cap risk steward contract
    /// @return capRiskSteward The address of the cap risk steward contract.
    function deploy(address governorAccessControl, address irmFactory, address admin) external returns (address);
}
