// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {SelectorAccessControl} from "../AccessControl/SelectorAccessControl.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";
import {AmountCap, AmountCapLib} from "evk/EVault/shared/types/AmountCap.sol";
import {IGovernance} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

/// @title GovernorAccessControl
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A limited governor contract that allows whitelisted callers to call specific functions on target contracts.
contract GovernorAccessControl is SelectorAccessControl {
    using AmountCapLib for AmountCap;

    /// @notice Role identifier for emergency borrow LTV adjustments
    bytes32 public constant LTV_EMERGENCY_ROLE = keccak256("LTV_EMERGENCY_ROLE");

    /// @notice Role identifier for emergency vault operations disabling
    bytes32 public constant HOOK_EMERGENCY_ROLE = keccak256("HOOK_EMERGENCY_ROLE");

    /// @notice Role identifier for emergency supply and borrow caps adjustments
    bytes32 public constant CAPS_EMERGENCY_ROLE = keccak256("CAPS_EMERGENCY_ROLE");

    /// @notice Error thrown when the message data is invalid.
    error MsgDataInvalid();

    /// @notice Constructor
    /// @param evc The address of the EVC.
    /// @param admin The address to be granted the DEFAULT_ADMIN_ROLE.
    constructor(address evc, address admin) SelectorAccessControl(evc, admin) {}

    /// @dev Emergency process allows authorized users to lower borrow LTV without changing liquidation LTV. The
    /// emergency process uses current ramp duration if active, or applies changes immediately if no ramp is ongoing,
    /// effectively overriding passed rampDuration parameter if necessary.
    function setLTV(address collateral, uint16 borrowLTV, uint16 liquidationLTV, uint32 rampDuration)
        external
        virtual
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
    function setHookConfig(address newHookTarget, uint32 newHookedOps) external virtual {
        IGovernance vault = IGovernance(_targetContract());
        bool isEmergency = newHookTarget == address(0) && newHookedOps == OP_MAX_VALUE - 1;

        if (!isEmergency || !hasRole(HOOK_EMERGENCY_ROLE, _msgSender())) {
            _authenticateCaller();
        }

        vault.setHookConfig(newHookTarget, newHookedOps);
    }

    /// @dev Emergency process allows authorized users to lower the caps.
    function setCaps(uint16 supplyCap, uint16 borrowCap) external virtual {
        IGovernance vault = IGovernance(_targetContract());
        uint256 supplyCapResolved = AmountCap.wrap(supplyCap).resolve();
        uint256 borrowCapResolved = AmountCap.wrap(borrowCap).resolve();
        (uint256 currentSupplyCapResolved, uint256 currentBorrowCapResolved) = vault.caps();
        currentSupplyCapResolved = AmountCap.wrap(uint16(currentSupplyCapResolved)).resolve();
        currentBorrowCapResolved = AmountCap.wrap(uint16(currentBorrowCapResolved)).resolve();

        bool isEmergency = (
            supplyCapResolved <= currentSupplyCapResolved || borrowCapResolved <= currentBorrowCapResolved
        ) && (supplyCapResolved <= currentSupplyCapResolved && borrowCapResolved <= currentBorrowCapResolved);

        if (!isEmergency || !hasRole(CAPS_EMERGENCY_ROLE, _msgSender())) {
            _authenticateCaller();
        }

        vault.setCaps(supplyCap, borrowCap);
    }

    /// @notice Fallback function to forward calls to target contracts.
    /// @dev This function authenticates the caller, extracts the target contract address from the calldata, and
    /// forwards the call to the target contract.
    fallback() external {
        _authenticateCaller();

        address targetContract = _targetContract();

        assembly {
            let forwardDataSize := sub(calldatasize(), 20)
            calldatacopy(0, 0, forwardDataSize)

            let result := call(gas(), targetContract, 0, 0, forwardDataSize, 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /// @notice Authenticates the caller based on their role and the function selector. In case of authentication
    /// through the EVC, it ensures that the caller is the EVC account owner.
    /// @inheritdoc SelectorAccessControl
    function _authenticateCaller() internal view virtual override onlyEVCAccountOwner {
        super._authenticateCaller();
    }

    /// @notice Extracts the target contract address from the calldata.
    /// @return targetContract The address of the target contract
    function _targetContract() internal view virtual returns (address targetContract) {
        if (msg.data.length <= 20) revert MsgDataInvalid();

        assembly {
            targetContract := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }
}
