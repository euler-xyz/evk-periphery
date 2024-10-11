// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseHookTarget} from "./BaseHookTarget.sol";
import {AccessControlEnumerable} from "openzeppelin-contracts/access/extensions/AccessControlEnumerable.sol";

contract HookTargetWhitelist is BaseHookTarget, AccessControlEnumerable {
    bytes32 public constant WILD_CARD_SELECTOR = bytes4(0);

    error HookTargetWhitelist__NotAllowed();

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Constructor to initialize the contract with the given admin.
    /// @notice Allows an address to call a specific selector.
    /// @param account The address to allow.
    /// @param selector The selector to allow for.
    function allowForSelector(address account, bytes4 selector) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(selector, account);
    }

    /// @notice Disallows a previousely allowed address from calling a specific selector.
    /// @param account The address to disallow.
    /// @param selector The selector to disallow for.
    function disallowForSelector(address account, bytes4 selector) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(selector, account);
    }

    /// @notice Allows an address to call any selector.
    /// @param account The address to allow.
    function allowForAll(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(WILD_CARD_SELECTOR, account);
    }

    /// @notice Disallows an address from calling any selector.
    /// @param account The address to disallow.
    function disallowForAll(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(WILD_CARD_SELECTOR, account);
    }

    /// @notice Fallback function to revert if the address is not allowed to call the selector.
    fallback() external {
        address msgSender = getAddressFromMsgData();

        // Don't revert if whitelisted for wildcard or specific selector
        if (hasRole(WILD_CARD_SELECTOR, msgSender) || hasRole(msg.sig, msgSender)) return;

        // Otherwise, revert
        revert HookTargetWhitelist__NotAllowed();
    }
}
