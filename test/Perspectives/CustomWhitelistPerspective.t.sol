// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IPerspective} from "../../src/Perspectives/implementation/interfaces/IPerspective.sol";
import {CustomWhitelistPerspective} from "../../src/Perspectives/deployed/CustomWhitelistPerspective.sol";

contract CustomWhitelistPerspectiveTest is Test {
    function test_CustomWhitelistPerspective(uint8 size, uint256 seed) public {
        address[] memory whitelist = new address[](size);

        for (uint256 i = 0; i < size; i++) {
            whitelist[i] = address(uint160(uint256(keccak256(abi.encode(seed, i)))));
        }

        CustomWhitelistPerspective perspective = new CustomWhitelistPerspective(whitelist);

        assertEq(perspective.name(), "Custom Whitelist Perspective");

        for (uint256 i = 0; i < size; i++) {
            assertTrue(perspective.isVerified(whitelist[i]));
        }
        address[] memory verified = perspective.verifiedArray();
        assertEq(verified.length, size);
        for (uint256 i = 0; i < size; i++) {
            assertEq(verified[i], whitelist[i]);
        }
        assertEq(perspective.verifiedLength(), size);

        vm.expectRevert(
            abi.encodeWithSelector(
                IPerspective.PerspectiveError.selector, address(perspective), address(1), type(uint256).max
            )
        );
        perspective.perspectiveVerify(address(1), true);
    }
}
