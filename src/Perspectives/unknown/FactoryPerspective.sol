// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {BasePerspective} from "../BasePerspective.sol";

contract FactoryPerspective is BasePerspective {
    constructor(address vaultFactory_) BasePerspective(vaultFactory_) {}

    function name() public pure virtual override returns (string memory) {
        return "Unknown.Unknown.FactoryPerspective";
    }

    function perspectiveVerifyInternal(address vault) internal virtual override {
        if (!vaultFactory.isProxy(vault)) {
            revert PerspectiveError(address(this), vault, ERROR__FACTORY);
        }
    }

    function isVerified(address vault) public view virtual override returns (bool) {
        return vaultFactory.isProxy(vault);
    }

    function verifiedLength() public view virtual override returns (uint256) {
        return vaultFactory.getProxyListLength();
    }

    function verifiedArray() public view virtual override returns (address[] memory) {
        return vaultFactory.getProxyListSlice(0, type(uint256).max);
    }
}
