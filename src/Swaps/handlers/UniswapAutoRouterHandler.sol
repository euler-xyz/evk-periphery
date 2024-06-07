// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseHandler} from "./BaseHandler.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";
import {ISwapper} from "../ISwapper.sol";

/// @title UniswapAutoRouterHandler
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Swap handler executing trades encoded by Uniswap's Auto Router
abstract contract UniswapAutoRouterHandler is BaseHandler {
    address public immutable uniSwapRouter02;

    constructor(address _uniSwapRouter02) {
        uniSwapRouter02 = _uniSwapRouter02;
    }

    function swapAutoRouter(SwapParams memory params) internal virtual {
        if (params.mode == MODE_TARGET_DEBT) revert Swapper_UnsupportedMode();

        setMaxAllowance(params.tokenIn, uniSwapRouter02);

        (bool success, bytes memory result) = uniSwapRouter02.call(params.data);
        if (!success) RevertBytes.revertBytes(result);
    }
}
