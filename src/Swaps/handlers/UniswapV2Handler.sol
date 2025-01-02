// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseHandler} from "./BaseHandler.sol";
import {IUniswapV2Router01} from "../vendor/ISwapRouterV2.sol";

/// @title UniswapV2Handler
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Swap handler executing exact output trades on Uniswap V2
abstract contract UniswapV2Handler is BaseHandler {
    address public immutable uniswapRouterV2;

    error UniswapV2Handler_InvalidPath();

    constructor(address _uniswapRouterV2) {
        uniswapRouterV2 = _uniswapRouterV2;
    }

    function swapUniswapV2(SwapParams memory params) internal virtual {
        if (params.mode == MODE_EXACT_IN) revert Swapper_UnsupportedMode();
        if (params.data.length < 64 || params.data.length % 32 != 0) revert UniswapV2Handler_InvalidPath();

        setMaxAllowance(params.tokenIn, uniswapRouterV2);
        // process params according to the mode and current state
        (uint256 amountOut, address receiver) = resolveParams(params);

        if (amountOut > 0) {
            (bool success, bytes memory result) = uniswapRouterV2.call(
                abi.encodeCall(
                    IUniswapV2Router01.swapTokensForExactTokens,
                    (amountOut, type(uint256).max, abi.decode(params.data, (address[])), receiver, block.timestamp)
                )
            );
            if (!success || (result.length == 0 && uniswapRouterV2.code.length == 0)) {
                revert Swapper_SwapError(uniswapRouterV2, result);
            }
        }
    }
}
