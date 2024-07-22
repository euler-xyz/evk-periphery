// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {BasePerspective} from "../implementation/BasePerspective.sol";
import {DefaultPerspective} from "../implementation/DefaultPerspective.sol";

/// @title EulerBasePerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that verifies whether a vault has the properties of a base default vault. It allows collaterals
/// to be recognized by the default or the escrow perspective.
contract EulerBasePerspective is DefaultPerspective {
    constructor(
        address vaultFactory_,
        address routerFactory_,
        address adapterRegistry_,
        address externalVaultRegistry_,
        address irmFactory_,
        address escrowPerspective_
    )
        DefaultPerspective(
            vaultFactory_,
            routerFactory_,
            adapterRegistry_,
            externalVaultRegistry_,
            irmFactory_,
            new address[](0)
        )
    {
        require(
            keccak256(bytes(BasePerspective(escrowPerspective_).name())) == keccak256("Escrow Perspective"),
            "Invalid escrow perspective"
        );

        recognizedCollateralPerspectives.push(escrowPerspective_);
        recognizedCollateralPerspectives.push(address(0));
    }

    /// @inheritdoc BasePerspective
    function name() public pure override returns (string memory) {
        return "Euler Base Perspective";
    }
}
