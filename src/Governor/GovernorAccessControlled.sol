// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "openzeppelin-contracts/access/extensions/AccessControlEnumerable.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";
import {IGovernance} from "evk/EVault/IEVault.sol";

/// @title GovernorAccessControlled
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A limited EVault governor contract that allows certain roles to call specific functions.
contract GovernorAccessControlled is AccessControlEnumerable {
    /// @notice Role for managing Loan-to-Value (LTV) parameters
    bytes32 public constant LTV_MANAGER_ROLE = keccak256("LTV_MANAGER_ROLE");

    /// @notice Role for managing Interest Rate Model (IRM) parameters
    bytes32 public constant IRM_MANAGER_ROLE = keccak256("IRM_MANAGER_ROLE");

    /// @notice Role for managing hook configurations
    bytes32 public constant HOOK_MANAGER_ROLE = keccak256("HOOK_MANAGER_ROLE");

    /// @notice Role for managing caps
    bytes32 public constant CAPS_MANAGER_ROLE = keccak256("CAPS_MANAGER_ROLE");

    /// @notice Event emitted when a top-level call is made to the contract
    /// @param role The role of the caller making the top-level call
    /// @param caller The address of the account making the top-level call
    event TopLevelCall(bytes32 indexed role, address indexed caller);

    /// @notice Error thrown when input array lengths do not match
    /// @param a Length of the first array
    /// @param b Length of the second array
    error InputArraysLengthMismatch(uint256 a, uint256 b);

    /// @notice Error thrown when an invalid selector is provided
    /// @param i Index of the invalid selector
    /// @param expected Expected selector
    /// @param actual Actual selector provided
    error InvalidSelector(uint256 i, bytes4 expected, bytes4 actual);

    /// @notice Constructor to initialize the contract with the given admin.
    /// @param admin The address of the initial admin.
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Executes a call to specified targets with provided data (admin only)
    /// @param targets Array of target addresses to call
    /// @param datas Array of calldata to be executed on corresponding targets
    function adminCall(address[] calldata targets, bytes[] calldata datas) external onlyRole(DEFAULT_ADMIN_ROLE) {
        emit TopLevelCall(DEFAULT_ADMIN_ROLE, msg.sender);
        _targetCallWithSelectorCheck(targets, datas, 0);
    }

    /// @notice Sets LTV parameters for specified targets
    /// @param targets Array of target addresses to call
    /// @param datas Array of calldata containing LTV parameters
    function setLTV(address[] calldata targets, bytes[] calldata datas) external onlyRole(LTV_MANAGER_ROLE) {
        emit TopLevelCall(LTV_MANAGER_ROLE, msg.sender);
        _targetCallWithSelectorCheck(targets, datas, IGovernance.setLTV.selector);
    }

    /// @notice Sets Interest Rate Model for specified targets
    /// @param targets Array of target addresses to call
    /// @param datas Array of calldata containing IRM parameters
    function setInterestRateModel(address[] calldata targets, bytes[] calldata datas)
        external
        onlyRole(IRM_MANAGER_ROLE)
    {
        emit TopLevelCall(IRM_MANAGER_ROLE, msg.sender);
        _targetCallWithSelectorCheck(targets, datas, IGovernance.setInterestRateModel.selector);
    }

    /// @notice Sets hook configurations for specified targets
    /// @param targets Array of target addresses to call
    /// @param datas Array of calldata containing hook configurations
    function setHookConfig(address[] calldata targets, bytes[] calldata datas) external onlyRole(HOOK_MANAGER_ROLE) {
        emit TopLevelCall(HOOK_MANAGER_ROLE, msg.sender);
        _targetCallWithSelectorCheck(targets, datas, IGovernance.setHookConfig.selector);
    }

    /// @notice Sets caps for specified targets
    /// @param targets Array of target addresses to call
    /// @param datas Array of calldata containing cap configurations
    function setCaps(address[] calldata targets, bytes[] calldata datas) external onlyRole(CAPS_MANAGER_ROLE) {
        emit TopLevelCall(CAPS_MANAGER_ROLE, msg.sender);
        _targetCallWithSelectorCheck(targets, datas, IGovernance.setCaps.selector);
    }

    /// @notice Internal function to execute calls with selector checks
    /// @param targets Array of target addresses to call
    /// @param datas Array of calldata to be executed on corresponding targets
    /// @param expectedSelector Expected function selector (0 for no check)
    function _targetCallWithSelectorCheck(address[] calldata targets, bytes[] calldata datas, bytes4 expectedSelector)
        internal
    {
        if (targets.length != datas.length) revert InputArraysLengthMismatch(targets.length, datas.length);

        for (uint256 i = 0; i < targets.length; ++i) {
            bytes calldata data = datas[i];

            if (expectedSelector != 0 && expectedSelector != bytes4(data)) {
                revert InvalidSelector(i, expectedSelector, bytes4(data));
            }

            (bool success, bytes memory result) = targets[i].call(data);
            if (!success) RevertBytes.revertBytes(result);
        }
    }
}
