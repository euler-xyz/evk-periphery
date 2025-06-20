// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {IEulerEarnFactory} from "euler-earn/interfaces/IEulerEarnFactory.sol";
import {BasePerspective} from "../implementation/BasePerspective.sol";

/// @title EulerEarnFactoryPerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that verifies whether a vault was deployed by the EulerEarnFactory Factory.
contract EulerEarnFactoryPerspective is BasePerspective {
    /// @notice Creates a new EulerEarnFactoryPerspective instance.
    /// @param vaultFactory_ The address of the EulerEarnFactory contract.
    constructor(address vaultFactory_) BasePerspective(vaultFactory_) {}

    /// @inheritdoc BasePerspective
    function name() public pure virtual override returns (string memory) {
        return "Euler Earn Factory Perspective";
    }

    /// @inheritdoc BasePerspective
    function perspectiveVerifyInternal(address vault) internal virtual override {
        testProperty(IEulerEarnFactory(address(vaultFactory)).isVault(vault), ERROR__FACTORY);
    }

    /// @inheritdoc BasePerspective
    function isVerified(address vault) public view virtual override returns (bool) {
        return IEulerEarnFactory(address(vaultFactory)).isVault(vault);
    }

    /// @inheritdoc BasePerspective
    function verifiedLength() public view virtual override returns (uint256) {
        return IEulerEarnFactory(address(vaultFactory)).getVaultListLength();
    }

    /// @inheritdoc BasePerspective
    function verifiedArray() public view virtual override returns (address[] memory) {
        return IEulerEarnFactory(address(vaultFactory)).getVaultListSlice(0, type(uint256).max);
    }
}
