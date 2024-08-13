// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EulerBasePerspective} from "../../src/Perspectives/deployed/EulerBasePerspective.sol";

contract EulerBasePerspectiveHarness is EulerBasePerspective {
    constructor(
        address vaultFactory_,
        address routerFactory_,
        address adapterRegistry_,
        address externalVaultRegistry_,
        address irmFactory_,
        address irmRegistry
    )
        EulerBasePerspective(
            vaultFactory_,
            routerFactory_,
            adapterRegistry_,
            externalVaultRegistry_,
            irmFactory_,
            irmRegistry,
            new address[](0)
        )
    {}

    function verifyCollateralPricingHarness(address router, address vault, address unitOfAccount) external {
        verifyCollateralPricing(router, vault, unitOfAccount);
    }

    function verifyAssetPricingHarness(address router, address asset, address unitOfAccount) external {
        verifyAssetPricing(router, asset, unitOfAccount);
    }

    function testProperty(bool condition, uint256) internal pure override {
        if (!condition) revert("harness: testProperty failed");
    }
}
