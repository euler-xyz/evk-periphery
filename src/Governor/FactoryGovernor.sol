// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "openzeppelin-contracts/access/extensions/AccessControlEnumerable.sol";
import {GenericFactory} from "evk/GenericFactory/GenericFactory.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";

import {ReadOnlyProxy} from "./ReadOnlyProxy.sol";

/// @title FactoryGovernor
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Governor for the EVK beacon (factory), allowing pause guardians to upgrade the implementation to read only
/// proxy
contract FactoryGovernor is AccessControlEnumerable {
    /// @notice Role identifier for the guardian role.
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    /// @notice Event emitted when an admin call is made to a factory.
    /// @param admin The address of the admin making the call.
    /// @param factory The address of the factory being called.
    /// @param data The calldata of the admin call.
    event AdminCall(address indexed admin, address indexed factory, bytes data);

    /// @notice Event emitted when a factory is paused.
    /// @param guardian The address of the guardian who paused the factory.
    /// @param factory The address of the factory that was paused.
    /// @param roProxy The address of the read-only proxy which was installed.
    event Paused(address indexed guardian, address indexed factory, address indexed roProxy);

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
        emit AdminCall(_msgSender(), factory, data);
        return result;
    }

    /// @notice Pauses all upgradeable vaults by installing a new implementation,
    /// which is a read only proxy to the current implementation
    /// @param factory Address of the factory to pause.
    function pause(address factory) external onlyRole(GUARDIAN_ROLE) {
        address oldImplementation = GenericFactory(factory).implementation();

        // Not to pause twice, check if the old implementation already is a read only proxy
        (bool success, bytes memory result) =
            oldImplementation.staticcall(abi.encodeCall(ReadOnlyProxy.roProxyImplementation, ()));

        if (success && result.length >= 32) {
            revert("already paused");
        } else {
            address readOnlyProxy = address(new ReadOnlyProxy(oldImplementation));
            GenericFactory(factory).setImplementation(readOnlyProxy);

            emit Paused(_msgSender(), factory, readOnlyProxy);
        }
    }
}
