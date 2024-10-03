// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {AccessControlEnumerable} from "openzeppelin-contracts/access/extensions/AccessControlEnumerable.sol";
import {Context} from "openzeppelin-contracts/utils/Context.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";
import {IGovernance} from "evk/EVault/IEVault.sol";

/// @title GovernorAccessControlled
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A limited EVault governor contract that allows certain roles to call specific functions.
contract GovernorAccessControlled is EVCUtil, AccessControlEnumerable {
    /// @notice Role for managing Loan-to-Value (LTV) parameters
    bytes32 public constant LTV_MANAGER_ROLE = keccak256("LTV_MANAGER_ROLE");

    /// @notice Role for managing Interest Rate Model (IRM) parameters
    bytes32 public constant IRM_MANAGER_ROLE = keccak256("IRM_MANAGER_ROLE");

    /// @notice Role for managing hook configurations
    bytes32 public constant HOOK_MANAGER_ROLE = keccak256("HOOK_MANAGER_ROLE");

    /// @notice Role for managing caps
    bytes32 public constant CAPS_MANAGER_ROLE = keccak256("CAPS_MANAGER_ROLE");

    /// @notice Error thrown when an invalid selector is provided
    /// @param expected Expected selector
    /// @param actual Actual selector provided
    error InvalidSelector(bytes4 expected, bytes4 actual);

    /// @notice Constructor
    /// @param _evc The address of the EVC.
    /// @param admin The address of the initial admin.
    constructor(address _evc, address admin) EVCUtil(_evc) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /// @notice Executes a call to specified targets with provided data (admin only)
    /// @param target The target address to call
    /// @param data The calldata to be executed on the target
    function adminCall(address target, bytes calldata data) external onlyEVCAccountOwner onlyRole(DEFAULT_ADMIN_ROLE) {
        _targetCallWithSelectorCheck(target, data, 0);
    }

    /// @notice Sets LTV parameters for a specified target
    /// @param target The target address to call
    /// @param data The calldata containing LTV parameters
    function setLTV(address target, bytes calldata data) external onlyEVCAccountOwner onlyRole(LTV_MANAGER_ROLE) {
        _targetCallWithSelectorCheck(target, data, IGovernance.setLTV.selector);
    }

    /// @notice Sets Interest Rate Model for a specified target
    /// @param target The target address to call
    /// @param data The calldata containing IRM parameters
    function setInterestRateModel(address target, bytes calldata data)
        external
        onlyEVCAccountOwner
        onlyRole(IRM_MANAGER_ROLE)
    {
        _targetCallWithSelectorCheck(target, data, IGovernance.setInterestRateModel.selector);
    }

    /// @notice Sets hook configurations for a specified target
    /// @param target The target address to call
    /// @param data The calldata containing hook configurations
    function setHookConfig(address target, bytes calldata data)
        external
        onlyEVCAccountOwner
        onlyRole(HOOK_MANAGER_ROLE)
    {
        _targetCallWithSelectorCheck(target, data, IGovernance.setHookConfig.selector);
    }

    /// @notice Sets caps for a specified target
    /// @param target The target address to call
    /// @param data The calldata containing cap configurations
    function setCaps(address target, bytes calldata data) external onlyEVCAccountOwner onlyRole(CAPS_MANAGER_ROLE) {
        _targetCallWithSelectorCheck(target, data, IGovernance.setCaps.selector);
    }

    /// @notice Internal function to execute a call with a selector check
    /// @param target The target address to call
    /// @param data The calldata to be executed on the target
    /// @param expectedSelector Expected function selector (0 for no check)
    function _targetCallWithSelectorCheck(address target, bytes calldata data, bytes4 expectedSelector) internal {
        if (expectedSelector != 0 && expectedSelector != bytes4(data)) {
            revert InvalidSelector(expectedSelector, bytes4(data));
        }

        (bool success, bytes memory result) = target.call(data);
        if (!success) RevertBytes.revertBytes(result);
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view override (Context, EVCUtil) returns (address) {
        return EVCUtil._msgSender();
    }
}
