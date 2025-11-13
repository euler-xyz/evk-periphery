// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IPerspective} from "../../src/Perspectives/implementation/interfaces/IPerspective.sol";
import {OneOfMetaPerspective} from "../../src/Perspectives/deployed/OneOfMetaPerspective.sol";
import {CustomWhitelistPerspective} from "../../src/Perspectives/deployed/CustomWhitelistPerspective.sol";

contract OneOfMetaPerspectiveTest is Test {
    function test_OneOfMetaPerspective() public {
        vm.expectRevert(OneOfMetaPerspective.NoPerspectivesProvided.selector);
        new OneOfMetaPerspective(new address[](0));

        address[] memory p1Verified = new address[](2);
        p1Verified[0] = address(1);
        p1Verified[1] = address(2);

        address[] memory p2Verified = new address[](2);
        p2Verified[0] = address(2);
        p2Verified[1] = address(3);

        CustomWhitelistPerspective p1 = new CustomWhitelistPerspective(p1Verified);
        CustomWhitelistPerspective p2 = new CustomWhitelistPerspective(p2Verified);

        address[] memory perspectives = new address[](2);
        vm.expectRevert(OneOfMetaPerspective.BadAddress.selector);
        new OneOfMetaPerspective(perspectives);

        perspectives[0] = address(p1);
        perspectives[1] = address(p2);

        OneOfMetaPerspective perspective = new OneOfMetaPerspective(perspectives);

        assertEq(perspective.name(), "One-of Meta Perspective");

        vm.expectRevert();
        perspective.perspectiveVerify(address(4), true);

        assertTrue(perspective.isVerified(address(1)));
        assertTrue(perspective.isVerified(address(2)));
        assertTrue(perspective.isVerified(address(3)));
        assertFalse(perspective.isVerified(address(4)));

        assertEq(perspective.perspectivesLength(), 2);

        address[] memory arr = perspective.perspectivesArray();
        assertEq(arr.length, 2);
        assertEq(arr[0], address(p1));
        assertEq(arr[1], address(p2));
    }
}
