// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {SelectorAccessControl} from "../AccessControl/SelectorAccessControl.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {AmountCap, AmountCapLib} from "evk/EVault/shared/types/AmountCap.sol";
import {IGovernance} from "evk/EVault/IEVault.sol";

/// @title CapRiskSteward
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A risk management contract that allows controlled adjustments to vault parameters within predefined safety
/// limits. This contract enables authorized users to modify supply and borrow caps with restricted adjustment ranges
/// and time-based cooldowns. It also provides functionality to update interest rate models while enforcing access
/// control checks.
contract CapRiskSteward is SelectorAccessControl {
    using AmountCapLib for AmountCap;

    /// @notice The multiplier used to calculate the maximum allowable cap adjustment
    uint256 public constant MAX_ADJUST_FACTOR = 1.5e18;

    /// @notice The time needed to recharge the adjustment factor to the maximum
    uint256 public constant CHARGE_INTERVAL = 3 days;

    /// @notice The address of the governor contract that will execute the actual parameter changes
    address public immutable governor;

    /// @notice Tracks the last time caps were updated for each vault
    mapping(address vault => uint256 timestamp) public lastCapUpdate;

    /// @notice Error thrown when a cap adjustment is outside the allowed range
    /// @param vault The address of the vault for which the invalid cap adjustment was attempted
    error CapAdjustmentInvalid(address vault);

    /// @notice Error thrown when the message data is invalid
    error MsgDataInvalid();

    /// @notice Error thrown when a call to the governor fails without returning error data
    error EmptyError();

    /// @notice Initializes the RiskSteward contract
    /// @param governorAccessControl The address of the governor contract that will execute parameter changes
    /// @param admin The address to be granted admin privileges in the SelectorAccessControl contract
    constructor(address governorAccessControl, address admin)
        SelectorAccessControl(EVCUtil(governorAccessControl).EVC(), admin)
    {
        governor = governorAccessControl;
    }

    /// @notice Adjusts the supply and borrow caps for a vault within limited bounds
    /// @param supplyCap The new supply cap value to set
    /// @param borrowCap The new borrow cap value to set
    function setCaps(uint16 supplyCap, uint16 borrowCap) external onlyEVCAccountOwner {
        _authenticateCaller();

        // Fetch current caps
        address vault = _targetContract();
        (uint16 currentSupplyCap, uint16 currentBorrowCap) = IGovernance(vault).caps();

        // Calculate the allowed adjust factor based on time elapsed, capped to MAX_ADJUST_FACTOR.
        uint256 elapsed = block.timestamp - lastCapUpdate[vault];
        uint256 allowedAdjustFactor = 1e18 + (MAX_ADJUST_FACTOR - 1e18) * elapsed / CHARGE_INTERVAL;
        if (allowedAdjustFactor > MAX_ADJUST_FACTOR) {
            allowedAdjustFactor = MAX_ADJUST_FACTOR;
        }

        // Validate cap changes
        _validateCap(vault, currentSupplyCap, supplyCap, allowedAdjustFactor);
        _validateCap(vault, currentBorrowCap, borrowCap, allowedAdjustFactor);

        lastCapUpdate[vault] = block.timestamp;
        _call();
    }

    /// @notice Updates the interest rate model for a vault
    function setInterestRateModel(address) external onlyEVCAccountOwner {
        _authenticateCaller();
        _call();
    }

    /// @notice Returns the selector of this function to identify this contract as a CapRiskSteward contract instance
    function isCapRiskSteward() external pure returns (bytes4) {
        return this.isCapRiskSteward.selector;
    }

    /// @notice Forwards the current call to the governor contract
    function _call() internal {
        (bool success, bytes memory result) = governor.call(msg.data);

        if (!success) {
            if (result.length != 0) {
                assembly {
                    revert(add(32, result), mload(result))
                }
            }
            revert EmptyError();
        }
    }

    /// @notice Extracts the target contract address from the calldata.
    /// @return targetContract The address of the target contract
    function _targetContract() internal view virtual returns (address targetContract) {
        if (msg.data.length <= 20) revert MsgDataInvalid();

        assembly {
            targetContract := shr(96, calldataload(sub(calldatasize(), 20)))
        }
    }

    /// @notice Validates that the configured cap is within the allowed range.
    function _validateCap(address vault, uint16 currentCap, uint16 nextCap, uint256 allowedAdjustFactor)
        internal
        pure
    {
        // Resolve caps to absolute units
        uint256 currentCapResolved = AmountCap.wrap(currentCap).resolve();
        uint256 nextCapResolved = AmountCap.wrap(nextCap).resolve();

        // Calculate the maximum and minimum caps
        uint256 maxCap = currentCapResolved * allowedAdjustFactor / 1e18;
        uint256 minCap = currentCapResolved * 1e18 / allowedAdjustFactor;

        // Validate the cap adjustment
        if (nextCapResolved > maxCap || nextCapResolved < minCap) {
            revert CapAdjustmentInvalid(vault);
        }
    }
}
