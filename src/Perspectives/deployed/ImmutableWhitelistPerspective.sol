// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {BasePerspective} from "../implementation/BasePerspective.sol";

contract ImmutableWhitelistPerspective is BasePerspective {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(address[] memory whitelist) BasePerspective(address(0)) {
        for (uint256 i = 0; i < whitelist.length; ++i) {
            verified.add(whitelist[i]);
            emit PerspectiveVerified(whitelist[i]);
        }
    }

    function name() public pure virtual override returns (string memory) {
        return "Immutable Whitelist Perspective";
    }

    function perspectiveVerifyInternal(address vault) internal virtual override {
        revert PerspectiveError(address(this), vault, 0);
    }
}
