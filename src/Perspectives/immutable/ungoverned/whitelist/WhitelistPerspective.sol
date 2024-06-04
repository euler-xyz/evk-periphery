// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {BasePerspective} from "../../../BasePerspective.sol";

contract WhitelistPerspective is BasePerspective {
    constructor(address[] memory whitelist) BasePerspective(address(0)) {
        for (uint256 i = 0; i < whitelist.length; ++i) {
            perspectiveVerify(whitelist[i], true);
        }
    }

    function name() public pure virtual override returns (string memory) {
        return "Immutable.Ungoverned.WhitelistPerspective";
    }
}
