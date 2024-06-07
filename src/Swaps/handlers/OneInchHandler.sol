// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseHandler} from "./BaseHandler.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";
import {ISwapper} from "../ISwapper.sol";

/// @title OneInchHandler
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Swap handler executing trades through 1Inch
abstract contract OneInchHandler is BaseHandler {
    address public immutable oneInchAggregator;

    constructor(address _oneInchAggregator) {
        oneInchAggregator = _oneInchAggregator;
    }

    function swapOneInch(SwapParams memory params) internal virtual {
        if (params.mode != MODE_EXACT_IN) revert Swapper_UnsupportedMode();

        setMaxAllowance(params.tokenIn, oneInchAggregator);

        (bool success, bytes memory result) = oneInchAggregator.call(params.data);
        if (!success) RevertBytes.revertBytes(result);
    }
}
