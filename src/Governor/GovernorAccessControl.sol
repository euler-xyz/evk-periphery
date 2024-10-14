// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {SelectorAccessControl} from "../AccessControl/SelectorAccessControl.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";

/// @title GovernorAccessControl
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A limited governor contract that allows whitelisted callers to call specific functions on target contracts.
contract GovernorAccessControl is SelectorAccessControl {
    /// @notice Error thrown when the message data is invalid.
    error MsgDataInvalid();

    /// @notice Constructor
    /// @param evc The address of the EVC.
    /// @param admin The address to be granted the DEFAULT_ADMIN_ROLE.
    constructor(address evc, address admin) SelectorAccessControl(evc, admin) {}

    /// @notice Fallback function to forward calls to target contracts.
    /// @dev This function authenticates the caller, extracts the target contract address from the calldata, and
    /// forwards the call to the target contract.
    fallback() external {
        _authenticateCaller();

        if (msg.data.length <= 20) revert MsgDataInvalid();

        assembly {
            let forwardDataSize := sub(calldatasize(), 20)
            let targetContract := shr(96, calldataload(forwardDataSize))
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
}
