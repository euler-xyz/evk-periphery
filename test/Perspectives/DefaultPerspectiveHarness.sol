// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {DefaultPerspective} from "../../src/Perspectives/implementation/DefaultPerspective.sol";

contract DefaultPerspectiveHarness is DefaultPerspective {
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
    {}

    function verifyCollateralPricingHarness(address router, address vault, address unitOfAccount) external {
        verifyCollateralPricing(router, vault, unitOfAccount);
    }

    function verifyAssetPricingHarness(address router, address asset, address unitOfAccount) external {
        verifyAssetPricing(router, asset, unitOfAccount);
    }

    function name() public pure override returns (string memory) {
        return "DefaultPerspectiveHarness";
    }

    function testProperty(bool condition, uint256) internal pure override {
        if (!condition) revert("harness: testProperty failed");
    }
}
