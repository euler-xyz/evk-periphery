// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseHandler} from "./BaseHandler.sol";
import {ISwapRouterV3} from "../vendor/ISwapRouterV3.sol";

/// @title UniswapV3Handler
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Swap handler executing exact output trades on Uniswap V3
abstract contract UniswapV3Handler is BaseHandler {
    address public immutable uniswapRouterV3;

    error UniswapV3Handler_InvalidPath();

    constructor(address _uniswapRouterV3) {
        uniswapRouterV3 = _uniswapRouterV3;
    }

    function swapUniswapV3(SwapParams memory params) internal virtual {
        if (params.mode == MODE_EXACT_IN) revert Swapper_UnsupportedMode();
        unchecked {
            if (params.data.length < 43 || (params.data.length - 20) % 23 != 0) revert UniswapV3Handler_InvalidPath();
        }

        setMaxAllowance(params.tokenIn, uniswapRouterV3);
        // update amountOut and receiver according to the mode and current state
        (uint256 amountOut, address receiver) = resolveParams(params);

        if (amountOut > 0) {
            (bool success, bytes memory result) = uniswapRouterV3.call(
                abi.encodeCall(
                    ISwapRouterV3.exactOutput,
                    ISwapRouterV3.ExactOutputParams({
                        path: params.data,
                        recipient: receiver,
                        amountOut: amountOut,
                        amountInMaximum: type(uint256).max,
                        deadline: block.timestamp
                    })
                )
            );
            if (!success || (result.length == 0 && uniswapRouterV3.code.length == 0)) {
                revert Swapper_SwapError(uniswapRouterV3, result);
            }
        }
    }
}
