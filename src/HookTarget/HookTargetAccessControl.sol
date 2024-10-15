// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseHookTarget} from "./BaseHookTarget.sol";
import {SelectorAccessControl} from "../AccessControl/SelectorAccessControl.sol";

/// @title HookTargetAccessControl
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Hook target contract that allows specific functions on the vault to be called only by whitelisted callers.
contract HookTargetAccessControl is BaseHookTarget, SelectorAccessControl {
    /// @notice Initializes the HookTargetAccessControl contract
    /// @param evc The address of the EVC.
    /// @param admin The address to be granted the DEFAULT_ADMIN_ROLE.
    /// @param eVaultFactory The address of the EVault factory.
    constructor(address evc, address admin, address eVaultFactory)
        BaseHookTarget(eVaultFactory)
        SelectorAccessControl(evc, admin)
    {}

    /// @notice Fallback function to revert if the address is not whitelisted to call the selector.
    fallback() external {
        _authenticateCaller();
    }

    /// @notice Retrieves the message sender in the context of the EVC or calling vault.
    /// @dev If the caller is a vault deployed by the recognized EVault factory, this function extracts the target
    /// contract address from the calldata. Otherwise, this function returns the account on behalf of which the current
    /// operation is being performed, which is either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view virtual override (BaseHookTarget, SelectorAccessControl) returns (address) {
        address msgSender = BaseHookTarget._msgSender();
        return msg.sender == msgSender ? SelectorAccessControl._msgSender() : msgSender;
    }
}
