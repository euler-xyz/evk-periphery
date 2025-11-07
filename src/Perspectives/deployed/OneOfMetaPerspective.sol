// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {BasePerspective} from "../implementation/BasePerspective.sol";

/// @title OneOfMetaPerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that verifies whether a vault is verified by any of the configured perspectives
contract OneOfMetaPerspective is BasePerspective {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal perspectives;

    error NoPerspectivesProvided();
    error BadAddress();

    /// @notice Creates a new OneOfMetaPerspective instance.
    /// @param _perspectives Addresses of the underlying perspectives
    constructor(address[] memory _perspectives) BasePerspective(address(0)) {
        if (_perspectives.length == 0) revert NoPerspectivesProvided();

        for (uint256 i = 0; i < _perspectives.length; i++) {
            if (_perspectives[i] == address(0)) revert BadAddress();
            perspectives.add(_perspectives[i]);
        }
    }

    /// @inheritdoc BasePerspective
    function name() public pure virtual override returns (string memory) {
        return "One-of Meta Perspective";
    }

    /// @inheritdoc BasePerspective
    function perspectiveVerifyInternal(address) internal virtual override {
        testProperty(false, type(uint256).max);
    }

    /// @inheritdoc BasePerspective
    function isVerified(address vault) public view virtual override returns (bool) {
        address[] memory cache = perspectives.values();
        for (uint256 i = 0; i < cache.length; i++) {
            if (BasePerspective(cache[i]).isVerified(vault)) return true;
        }
        return false;
    }

    /// @notice Returns the number of underlying perspectives.
    /// @return The number of underlying perspectives.
    function perspectivesLength() public view virtual returns (uint256) {
        return perspectives.length();
    }

    /// @notice Returns an array of addresses of all underlying perspectives.
    /// @return An array of addresses of underlying perspectives.
    function perspectivesArray() public view virtual returns (address[] memory) {
        return perspectives.values();
    }
}
