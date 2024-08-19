// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {IEVault} from "evk/EVault/IEVault.sol";

import {BasePerspective} from "../implementation/BasePerspective.sol";
import {EulerBasePerspective} from "../deployed/EulerBasePerspective.sol";

/// @title EulerBasePlusPerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that verifies whether a vault has the properties of a base vault, but additionally it ensures
/// that at least one collateral in the vault is verified by the "must have" collateral perspective.
contract EulerBasePlusPerspective is EulerBasePerspective {
    address public immutable mustHaveCollateralPerspective;

    /// @notice Creates a new EulerBasePlusPerspective instance.
    /// @param nameString_ The name string for the perspective.
    /// @param vaultFactory_ The address of the GenericFactory contract.
    /// @param routerFactory_ The address of the EulerRouterFactory contract.
    /// @param adapterRegistry_ The address of the adapter registry contract.
    /// @param externalVaultRegistry_ The address of the external vault registry contract.
    /// @param irmFactory_ The address of the EulerKinkIRMFactory contract.
    /// @param irmRegistry_ The address of the IRM registry contract.
    /// @param recognizedCollateralPerspectives_ The addresses of the recognized collateral perspectives. address(0) for
    /// self.
    /// @param mustHaveCollateralPerspective_ The address of the perspective that must verify at least one collateral.
    /// address(0) for self.
    constructor(
        string memory nameString_,
        address vaultFactory_,
        address routerFactory_,
        address adapterRegistry_,
        address externalVaultRegistry_,
        address irmFactory_,
        address irmRegistry_,
        address[] memory recognizedCollateralPerspectives_,
        address mustHaveCollateralPerspective_
    )
        EulerBasePerspective(
            nameString_,
            vaultFactory_,
            routerFactory_,
            adapterRegistry_,
            externalVaultRegistry_,
            irmFactory_,
            irmRegistry_,
            recognizedCollateralPerspectives_
        )
    {
        mustHaveCollateralPerspective = mustHaveCollateralPerspective_;
    }

    /// @inheritdoc BasePerspective
    function perspectiveVerifyInternal(address vault) internal virtual override {
        super.perspectiveVerifyInternal(vault);

        // at least one collateral must be verified by the "must have" collateral perspective
        address perspective = resolveRecognizedPerspective(mustHaveCollateralPerspective);
        address[] memory ltvList = IEVault(vault).LTVList();
        uint256 ltvListLength = ltvList.length;

        bool verified;
        for (uint256 i = 0; i < ltvListLength; ++i) {
            address collateral = ltvList[i];

            if (BasePerspective(perspective).isVerified(collateral)) {
                verified = true;
                break;
            }
        }

        testProperty(verified, ERROR__LTV_COLLATERAL_RECOGNITION);
    }
}
