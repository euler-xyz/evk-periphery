// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {WhitelistPerspective} from
    "../../../../../src/Perspectives/immutable/ungoverned/whitelist/WhitelistPerspective.sol";

contract WhitelistPerspectiveTest is Test {
    function test_WhitelistPerspective(uint8 size, uint256 seed) public {
        address[] memory whitelist = new address[](size);

        for (uint256 i = 0; i < size; i++) {
            whitelist[i] = address(uint160(uint256(keccak256(abi.encode(seed, i)))));
        }

        WhitelistPerspective perspective = new WhitelistPerspective(whitelist);

        assertEq(perspective.name(), "Immutable.Ungoverned.WhitelistPerspective");

        for (uint256 i = 0; i < size; i++) {
            assertTrue(perspective.isVerified(whitelist[i]));
        }
        address[] memory verified = perspective.verifiedArray();
        assertEq(verified.length, size);
        for (uint256 i = 0; i < size; i++) {
            assertEq(verified[i], whitelist[i]);
        }
        assertEq(perspective.verifiedLength(), size);
    }
}
