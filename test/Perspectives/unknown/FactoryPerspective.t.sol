// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {IPerspective} from "../../../src/Perspectives/interfaces/IPerspective.sol";
import {PerspectiveErrors} from "../../../src/Perspectives/PerspectiveErrors.sol";
import {FactoryPerspective} from "../../../src/Perspectives/unknown/FactoryPerspective.sol";

contract FactoryPerspectiveTest is EVaultTestBase, PerspectiveErrors {
    FactoryPerspective perspective;

    function setUp() public virtual override {
        super.setUp();

        perspective = new FactoryPerspective(address(factory));
    }

    function test_FactoryPerspective(uint8 size) public {
        assertEq(perspective.name(), "Unknown.Unknown.FactoryPerspective");

        uint256 currentLength = factory.getProxyListLength();
        assertEq(currentLength, perspective.verifiedLength());

        address[] memory vaults = new address[](size);
        for (uint256 i = 0; i < size; i++) {
            vaults[i] =
                factory.createProxy(address(0), false, abi.encodePacked(address(assetTST), address(0), address(0)));
            assertEq(perspective.verifiedLength(), currentLength + i + 1);
            assertTrue(perspective.isVerified(vaults[i]));

            // doesn't revert
            perspective.perspectiveVerify(vaults[i], true);
        }

        address[] memory verified = perspective.verifiedArray();
        assertEq(verified.length, currentLength + size);
        for (uint256 i = 0; i < vaults.length; i++) {
            assertEq(vaults[i], verified[currentLength + i]);
        }
        assertEq(verified[0], address(eTST));
        assertEq(verified[1], address(eTST2));

        assertFalse(perspective.isVerified(address(1)));

        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector, address(perspective), address(1), ERROR__FACTORY
            )
        );
        perspective.perspectiveVerify(address(1), true);
    }
}
