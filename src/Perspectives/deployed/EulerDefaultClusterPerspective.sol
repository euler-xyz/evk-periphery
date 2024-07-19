// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {BasePerspective} from "../implementation/BasePerspective.sol";
import {DefaultClusterPerspective} from "../implementation/DefaultClusterPerspective.sol";

/// @title EulerDefaultClusterPerspective
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that verifies whether a vault has the properties of a cluster vault. It allows collaterals to be
/// recognized by the cluster or escrow perspective.
contract EulerDefaultClusterPerspective is DefaultClusterPerspective {
    constructor(
        address vaultFactory_,
        address routerFactory_,
        address adapterRegistry_,
        address externalVaultRegistry_,
        address irmFactory_,
        address escrowSingletonPerspective_
    )
        DefaultClusterPerspective(
            vaultFactory_,
            routerFactory_,
            adapterRegistry_,
            externalVaultRegistry_,
            irmFactory_,
            new address[](0)
        )
    {
        require(
            keccak256(bytes(BasePerspective(escrowSingletonPerspective_).name()))
                == keccak256("Escrow Singleton Perspective"),
            "Invalid escrow perspective"
        );

        recognizedCollateralPerspectives.push(escrowSingletonPerspective_);
        recognizedCollateralPerspectives.push(address(0));
    }

    /// @inheritdoc BasePerspective
    function name() public pure override returns (string memory) {
        return "Euler Default Cluster Perspective";
    }
}
