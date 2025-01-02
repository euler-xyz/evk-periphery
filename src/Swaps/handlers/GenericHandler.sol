// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseHandler} from "./BaseHandler.sol";

/// @title GenericHandler
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Swap handler executing arbitrary trades on arbitrary target
abstract contract GenericHandler is BaseHandler {
    /// @dev the handler expects SwapParams.data to contain an abi encoded tuple: target contract address and call data
    function swapGeneric(SwapParams memory params) internal virtual {
        (address target, bytes memory payload) = abi.decode(params.data, (address, bytes));

        if (params.mode == MODE_TARGET_DEBT) resolveParams(params); // set repay amount in params.amountOut

        setMaxAllowance(params.tokenIn, target);

        (bool success, bytes memory result) = target.call(payload);
        if (!success || (result.length == 0 && target.code.length == 0)) revert Swapper_SwapError(target, result);
    }
}
