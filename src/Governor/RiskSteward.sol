// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {SelectorAccessControl} from "../AccessControl/SelectorAccessControl.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {AmountCap, AmountCapLib} from "evk/EVault/shared/types/AmountCap.sol";
import {IGovernance} from "evk/EVault/IEVault.sol";

/// @title RiskSteward
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A risk management contract that allows controlled adjustments to vault parameters within predefined safety
/// limits. This contract enables authorized users to modify supply and borrow caps with restricted adjustment ranges
/// and time-based cooldowns. It also provides functionality to update interest rate models while enforcing access
/// control checks.
contract RiskSteward is SelectorAccessControl {
    using AmountCapLib for AmountCap;

    /// @notice The multiplier used to calculate the maximum allowable cap adjustment
    uint256 public constant ADJUST_FACTOR = 10;

    /// @notice The base value for cap adjustment calculations
    uint256 public constant ADJUST_ONE = 100;

    /// @notice The minimum time interval required between cap adjustments for the same vault
    uint256 public constant ADJUST_INTERVAL = 1 days;

    /// @notice The address of the governor contract that will execute the actual parameter changes
    address public immutable governor;

    /// @notice Tracks the last time caps were updated for each vault
    mapping(address vault => uint256 timestamp) public lastCapUpdate;

    /// @notice Error thrown when attempting to adjust caps before the cooldown period has elapsed
    /// @param vault The address of the vault for which adjustment was attempted too early
    error CapAdjustmentTooEarly(address vault);

    /// @notice Error thrown when a supply cap adjustment is outside the allowed range
    /// @param vault The address of the vault for which the invalid supply cap adjustment was attempted
    error SupplyCapAdjustmentInvalid(address vault);

    /// @notice Error thrown when a borrow cap adjustment is outside the allowed range
    /// @param vault The address of the vault for which the invalid borrow cap adjustment was attempted
    error BorrowCapAdjustmentInvalid(address vault);

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

        uint256 supplyCapResolved = AmountCap.wrap(supplyCap).resolve();
        uint256 borrowCapResolved = AmountCap.wrap(borrowCap).resolve();

        address vault = _targetContract();
        (uint256 currentSupplyCapResolved, uint256 currentBorrowCapResolved) = IGovernance(vault).caps();
        currentSupplyCapResolved = AmountCap.wrap(uint16(currentSupplyCapResolved)).resolve();
        currentBorrowCapResolved = AmountCap.wrap(uint16(currentBorrowCapResolved)).resolve();

        uint256 maxSupplyCap = currentSupplyCapResolved * ADJUST_FACTOR / ADJUST_ONE;
        uint256 minSupplyCap = currentSupplyCapResolved * ADJUST_ONE / ADJUST_FACTOR;
        uint256 maxBorrowCap = currentBorrowCapResolved * ADJUST_FACTOR / ADJUST_ONE;
        uint256 minBorrowCap = currentBorrowCapResolved * ADJUST_ONE / ADJUST_FACTOR;

        if (block.timestamp < lastCapUpdate[vault] + ADJUST_INTERVAL) {
            revert CapAdjustmentTooEarly(vault);
        }

        if (supplyCapResolved > maxSupplyCap || supplyCapResolved < minSupplyCap) {
            revert SupplyCapAdjustmentInvalid(vault);
        }

        if (borrowCapResolved > maxBorrowCap || borrowCapResolved < minBorrowCap) {
            revert BorrowCapAdjustmentInvalid(vault);
        }

        lastCapUpdate[vault] = block.timestamp;
        _call();
    }

    /// @notice Updates the interest rate model for a vault
    function setInterestRateModel(address) external onlyEVCAccountOwner {
        _authenticateCaller();
        _call();
    }

    /// @notice Returns the selector of this function to identify this contract as a RiskSteward contract instance
    function isRiskSteward() external pure returns (bytes4) {
        return this.isRiskSteward.selector;
    }

    /// @notice Extracts the target contract address from the calldata.
    /// @return targetContract The address of the target contract
    function _targetContract() internal view virtual returns (address targetContract) {
        if (msg.data.length <= 20) revert MsgDataInvalid();

        assembly {
            targetContract := shr(96, calldataload(sub(calldatasize(), 20)))
        }
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
}
