// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {BatchBuilder} from "../utils/ScriptUtils.s.sol";

abstract contract CustomScriptBase is BatchBuilder {
    function run() public {
        execute();
        saveAddresses();
    }

    function execute() public virtual {}
}
