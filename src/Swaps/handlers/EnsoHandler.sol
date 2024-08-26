// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BaseHandler} from "./BaseHandler.sol";
import {RevertBytes} from "evk/EVault/shared/lib/RevertBytes.sol";

abstract contract EnsoHandler is BaseHandler {
    address public immutable ensoAggregator;

    constructor(address _ensoAggregator) {
        ensoAggregator = _ensoAggregator;
    }

    function swapEnso(SwapParams memory params) internal virtual {
        if (params.mode != MODE_EXACT_IN) revert Swapper_UnsupportedMode();

        setMaxAllowance(params.tokenIn, ensoAggregator);

        (bool success, bytes memory result) = ensoAggregator.call(params.data);
        if (!success) RevertBytes.revertBytes(result);
    }
}
