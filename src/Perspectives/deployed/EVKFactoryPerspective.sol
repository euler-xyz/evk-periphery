// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {BasePerspective} from "../implementation/BasePerspective.sol";

/// @title EVKFactoryPerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that verifies whether a vault was deployed by the EVK Factory.
contract EVKFactoryPerspective is BasePerspective {
    /// @notice Creates a new EVKFactoryPerspective instance.
    /// @param vaultFactory_ The address of the GenericFactory contract.
    constructor(address vaultFactory_) BasePerspective(vaultFactory_) {}

    /// @inheritdoc BasePerspective
    function name() public pure virtual override returns (string memory) {
        return "EVK Factory Perspective";
    }

    /// @inheritdoc BasePerspective
    function perspectiveVerifyInternal(address vault) internal virtual override {
        testProperty(vaultFactory.isProxy(vault), ERROR__FACTORY);
    }

    /// @inheritdoc BasePerspective
    function isVerified(address vault) public view virtual override returns (bool) {
        return vaultFactory.isProxy(vault);
    }

    /// @inheritdoc BasePerspective
    function verifiedLength() public view virtual override returns (uint256) {
        return vaultFactory.getProxyListLength();
    }

    /// @inheritdoc BasePerspective
    function verifiedArray() public view virtual override returns (address[] memory) {
        return vaultFactory.getProxyListSlice(0, type(uint256).max);
    }
}
