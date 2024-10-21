// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ContextUpgradeable} from "openzeppelin-contracts-upgradeable/utils/ContextUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from
    "openzeppelin-contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {
    AccessControlUpgradeable,
    IAccessControl
} from "openzeppelin-contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

/// @title SelectorAccessControl
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A utility contract with the EVC support that allows for access control based on specific selectors.
abstract contract SelectorAccessControl is EVCUtil, AccessControlEnumerableUpgradeable {
    /// @notice The wildcard for all selectors. A caller with this role can call any function selector.
    bytes32 public constant WILD_CARD = bytes32(type(uint256).max);

    /// @notice Constructor for SelectorAccessControl
    /// @param evc The address of the Ethereum Vault Connector (EVC)
    /// @param admin The address to be granted the DEFAULT_ADMIN_ROLE
    constructor(address evc, address admin) EVCUtil(evc) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _disableInitializers();
    }

    /// @notice Initializes the contract, setting up the admin role
    /// @param admin The address to be granted the DEFAULT_ADMIN_ROLE
    function initialize(address admin) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @dev Grants `role` to `account`.
    function grantRole(bytes32 role, address account)
        public
        virtual
        override (AccessControlUpgradeable, IAccessControl)
        onlyEVCAccountOwner
    {
        super.grantRole(role, account);
    }

    /// @dev Revokes `role` from `account`.
    function revokeRole(bytes32 role, address account)
        public
        virtual
        override (AccessControlUpgradeable, IAccessControl)
        onlyEVCAccountOwner
    {
        super.revokeRole(role, account);
    }

    /// @dev Revokes `role` from the calling account.
    function renounceRole(bytes32 role, address callerConfirmation)
        public
        virtual
        override (AccessControlUpgradeable, IAccessControl)
        onlyEVCAccountOwner
    {
        super.renounceRole(role, callerConfirmation);
    }

    /// @notice Authenticates the caller based on their role and the function selector called
    /// @dev Checks if the caller has either the wildcard role or the specific role for the current function selector
    /// @dev If the caller doesn't have the required role, it reverts with a NotAuthorized error
    function _authenticateCaller() internal view virtual {
        address msgSender = _msgSender();

        // Don't revert if whitelisted for wildcard or specific selector
        if (!hasRole(WILD_CARD, msgSender) && !hasRole(msg.sig, msgSender)) revert NotAuthorized();
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view virtual override (EVCUtil, ContextUpgradeable) returns (address) {
        return EVCUtil._msgSender();
    }
}
