// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {ISwapper} from "../ISwapper.sol";
import {IEVault, IERC20} from "evk/EVault/IEVault.sol";
import {SafeERC20Lib} from "evk/EVault/shared/lib/SafeERC20Lib.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";

abstract contract BaseHandler is ISwapper {
    uint256 internal constant MODE_EXACT_IN = 0;
    uint256 internal constant MODE_EXACT_OUT = 1;
    uint256 internal constant MODE_TARGET_DEBT = 2;
    uint256 internal constant MODE_MAX_VALUE = 3;

    error Swapper_UnsupportedMode();
    error Swapper_TargetDebt();
    error Swapper_TargetDebtBalance();

    function resolveParams(SwapParams memory params) internal view returns (uint256 amountOut, address receiver) {
        amountOut = params.amountOut;
        receiver = params.receiver;

        if (params.mode == MODE_EXACT_IN) return (amountOut, receiver);

        uint256 balanceOut = IERC20(params.tokenOut).balanceOf(address(this));

        // for combined exact output swaps, which accumulate the output in the swapper, check how much is already
        // available
        if (params.mode == MODE_EXACT_OUT && params.receiver == address(this)) {
            amountOut = balanceOut >= amountOut ? 0 : amountOut - balanceOut;
        }

        if (params.mode == MODE_TARGET_DEBT) {
            uint256 debt = IEVault(params.receiver).debtOf(params.account);

            // amountOut is the target debt
            if (amountOut > debt) revert Swapper_TargetDebt();

            // reuse params.amountOut to hold repay
            amountOut = params.amountOut = debt - amountOut;

            // check if balance is already sufficient to repay
            amountOut = balanceOut >= amountOut ? 0 : amountOut - balanceOut;

            // collect output in the swapper for repay
            receiver = address(this);
        }
    }

    function setMaxAllowance(address token, address spender) internal returns (uint256) {
        uint256 balance = IERC20(token).balanceOf(address(this));
        uint256 allowance = IERC20(token).allowance(address(this), spender);
        if (allowance < balance) safeApproveWithRetry(token, spender, type(uint256).max);

        return balance;
    }

    function trySafeApprove(address token, address to, uint256 value) internal returns (bool, bytes memory) {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20.approve.selector, to, value));
        return (success && (data.length == 0 || abi.decode(data, (bool))), data);
    }

    function safeApproveWithRetry(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = trySafeApprove(token, to, value);

        // some tokens, like USDT, require the allowance to be set to 0 first
        if (!success) {
            (success,) = trySafeApprove(token, to, 0);
            if (success) {
                (success,) = trySafeApprove(token, to, value);
            }
        }

        if (!success) RevertBytes.revertBytes(data);
    }
}
