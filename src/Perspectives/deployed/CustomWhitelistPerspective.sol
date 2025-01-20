// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {BasePerspective} from "../implementation/BasePerspective.sol";

/// @title CustomWhitelistPerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that verifies whether a vault is on the defined whitelist.
contract CustomWhitelistPerspective is BasePerspective {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Creates a new CustomWhitelistPerspective instance.
    /// @param whitelist An array of addresses to be added to the whitelist.
    constructor(address[] memory whitelist) BasePerspective(address(0)) {
        for (uint256 i = 0; i < whitelist.length; ++i) {
            verified.add(whitelist[i]);
            emit PerspectiveVerified(whitelist[i]);
        }
    }

    /// @inheritdoc BasePerspective
    function name() public pure virtual override returns (string memory) {
        return "Custom Whitelist Perspective";
    }

    /// @inheritdoc BasePerspective
    function perspectiveVerifyInternal(address) internal virtual override {
        testProperty(false, type(uint256).max);
    }
}
