// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EulerBasePerspective} from "../../src/Perspectives/deployed/EulerBasePerspective.sol";

contract EulerBasePerspectiveHarness is EulerBasePerspective {
    constructor(
        address vaultFactory_,
        address routerFactory_,
        address irmFactory_,
        address adapterRegistry_,
        address auxiliaryRegistry_
    )
        EulerBasePerspective(
            vaultFactory_,
            routerFactory_,
            irmFactory_,
            adapterRegistry_,
            auxiliaryRegistry_,
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
