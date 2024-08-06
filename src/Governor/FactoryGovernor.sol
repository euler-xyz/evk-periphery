// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";

import {ReadOnlyProxy} from "./ReadOnlyProxy.sol";

/// @title FactoryGovernor
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Governor for the EVK beacon (factory), allowing pause guardians to upgrade the implementation to read only
/// proxy
contract FactoryGovernor is AccessControl {
    /// @notice Role identifier for the guardian role.
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /// @notice Event emitted when a factory is paused.
    /// @param factory The factory that was paused.
    event Paused(address indexed factory);

    /// @notice Constructor to set the initial admin of the contract.
    /// @param admin The address of the initial admin.
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Executes a call to a specified factory.
    /// @param factory The address of the factory to call.
    /// @param data The calldata to be called on the factory.
    /// @return Return data of the factory call.
    function adminCall(address factory, bytes calldata data)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (bytes memory)
    {
        (bool success, bytes memory result) = factory.call(data);
        if (!success) RevertBytes.revertBytes(result);
        return result;
    }

    /// @notice Pauses all upgradeable vaults by installing a new implementation,
    /// which is a read only proxy to the current implementation
    /// @param factory Address of the factory to pause.
    function pause(address factory) external onlyRole(GUARDIAN_ROLE) {
        address oldImplementation = GenericFactory(factory).implementation();
        address readOnlyProxy = address(new ReadOnlyProxy(oldImplementation));
        GenericFactory(factory).setImplementation(readOnlyProxy);

        emit Paused(factory);
    }
}
