// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {GovernorAccessControl} from "./GovernorAccessControl.sol";
import {AmountCap, AmountCapLib} from "evk/EVault/shared/types/AmountCap.sol";
import {IGovernance} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

/// @title GovernorAccessControlEmergency
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A limited governor contract that allows whitelisted callers to call specific functions on target contracts.
/// It special cases setting LTVs, setting hook config and setting caps to enable custom emergency flows.
contract GovernorAccessControlEmergency is GovernorAccessControl {
    using AmountCapLib for AmountCap;

    /// @notice Role identifier for emergency borrow LTV adjustments
    bytes32 public constant LTV_EMERGENCY_ROLE = keccak256("LTV_EMERGENCY_ROLE");

    /// @notice Role identifier for emergency vault operations disabling
    bytes32 public constant HOOK_EMERGENCY_ROLE = keccak256("HOOK_EMERGENCY_ROLE");

    /// @notice Role identifier for emergency supply and borrow caps adjustments
    bytes32 public constant CAPS_EMERGENCY_ROLE = keccak256("CAPS_EMERGENCY_ROLE");

    /// @notice Constructor
    /// @param evc The address of the EVC.
    /// @param admin The address to be granted the DEFAULT_ADMIN_ROLE.
    constructor(address evc, address admin) GovernorAccessControl(evc, admin) {}

    /// @dev Emergency process allows authorized users to lower borrow LTV without changing liquidation LTV. As with all
    /// changes to borrow LTV, this takes effect immediately. The current ramp state for liquidation LTV (if any) is
    /// preserved, overriding passed rampDuration parameter if necessary.
    function setLTV(address collateral, uint16 borrowLTV, uint16 liquidationLTV, uint32 rampDuration)
        external
        virtual
        onlyEVCAccountOwner
    {
        IGovernance vault = IGovernance(_targetContract());
        (uint16 currentBorrowLTV, uint16 currentLiquidationLTV,, uint48 currentTargetTimestamp,) =
            vault.LTVFull(collateral);
        bool isEmergency = borrowLTV < currentBorrowLTV && liquidationLTV == currentLiquidationLTV;

        if (isEmergency && hasRole(LTV_EMERGENCY_ROLE, _msgSender())) {
            rampDuration =
                currentTargetTimestamp <= block.timestamp ? 0 : uint32(currentTargetTimestamp - block.timestamp);
        } else {
            _authenticateCaller();
        }

        vault.setLTV(collateral, borrowLTV, liquidationLTV, rampDuration);
    }

    /// @dev Emergency process allows authorized users to disable all operations on the vault.
    function setHookConfig(address newHookTarget, uint32 newHookedOps) external virtual onlyEVCAccountOwner {
        IGovernance vault = IGovernance(_targetContract());
        bool isEmergency = newHookTarget == address(0) && newHookedOps == OP_MAX_VALUE - 1;

        if (!isEmergency || !hasRole(HOOK_EMERGENCY_ROLE, _msgSender())) {
            _authenticateCaller();
        }

        vault.setHookConfig(newHookTarget, newHookedOps);
    }

    /// @dev Emergency process allows authorized users to lower the caps.
    function setCaps(uint16 supplyCap, uint16 borrowCap) external virtual onlyEVCAccountOwner {
        IGovernance vault = IGovernance(_targetContract());
        uint256 supplyCapResolved = AmountCap.wrap(supplyCap).resolve();
        uint256 borrowCapResolved = AmountCap.wrap(borrowCap).resolve();
        (uint256 currentSupplyCapResolved, uint256 currentBorrowCapResolved) = vault.caps();
        currentSupplyCapResolved = AmountCap.wrap(uint16(currentSupplyCapResolved)).resolve();
        currentBorrowCapResolved = AmountCap.wrap(uint16(currentBorrowCapResolved)).resolve();

        bool isEmergency = (
            supplyCapResolved < currentSupplyCapResolved || borrowCapResolved < currentBorrowCapResolved
        ) && (supplyCapResolved <= currentSupplyCapResolved && borrowCapResolved <= currentBorrowCapResolved);

        if (!isEmergency || !hasRole(CAPS_EMERGENCY_ROLE, _msgSender())) {
            _authenticateCaller();
        }

        vault.setCaps(supplyCap, borrowCap);
    }
}
