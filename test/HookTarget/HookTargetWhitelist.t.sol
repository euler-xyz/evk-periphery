// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {HookTargetWhitelist} from "../../src/HookTarget/HookTargetWhitelist.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";

contract HookTargetWhitelistTests is Test {
    HookTargetWhitelist public hookTargetWhitelist;
    address public admin;
    address public user1;
    address public user2;

    function setUp() public {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        hookTargetWhitelist = new HookTargetWhitelist(admin);
    }

    function test_allowForSelector() public {
        bytes4 selector = bytes4(keccak256("foo()"));

        vm.startPrank(admin);
        hookTargetWhitelist.allowForSelector(user1, selector);
        assertTrue(hookTargetWhitelist.hasRole(selector, user1));
        vm.stopPrank();
    }

    function test_allowForSelector_revert_notAdmin() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, bytes32(0))
        );
        hookTargetWhitelist.allowForSelector(user1, bytes4(keccak256("foo()")));
        vm.stopPrank();
    }

    function test_allowForAll() public {
        vm.startPrank(admin);
        hookTargetWhitelist.allowForAll(user1);
        assertTrue(hookTargetWhitelist.hasRole(hookTargetWhitelist.WILD_CARD_SELECTOR(), user1));
        vm.stopPrank();
    }

    function test_allowForAll_revert_notAdmin() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, bytes32(0))
        );
        hookTargetWhitelist.allowForAll(user1);
        vm.stopPrank();
    }

    function test_disallowForSelector() public {
        bytes4 selector = bytes4(keccak256("foo()"));
        vm.startPrank(admin);
        hookTargetWhitelist.allowForSelector(user1, selector);
        hookTargetWhitelist.disallowForSelector(user1, selector);
        assertFalse(hookTargetWhitelist.hasRole(selector, user1));
        vm.stopPrank();
    }

    function test_disallowForSelector_revert_notAdmin() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, bytes32(0))
        );
        hookTargetWhitelist.disallowForSelector(user1, bytes4(keccak256("foo()")));
        vm.stopPrank();
    }

    function test_allowedForSelector() public {
        bytes4 selector = bytes4(keccak256("foo()"));
        vm.startPrank(admin);
        hookTargetWhitelist.allowForSelector(user1, selector);
        assertTrue(hookTargetWhitelist.hasRole(selector, user1));
        vm.stopPrank();

        (bool success,) = address(hookTargetWhitelist).call(abi.encode(selector, user1));
        assertTrue(success);
    }

    function test_allowedForSelector_revert_notAllowed() public {
        bytes4 selector = bytes4(keccak256("foo()"));
        (bool success, bytes memory data) = address(hookTargetWhitelist).call(abi.encode(selector, user1));
        assertFalse(success);
        assertEq(data, abi.encodePacked(HookTargetWhitelist.HookTargetWhitelist__NotAllowed.selector));
    }

    function testAllowedForAll() public {
        bytes4 selector = bytes4(keccak256("foo()"));
        vm.startPrank(admin);
        hookTargetWhitelist.allowForAll(user1);
        assertTrue(hookTargetWhitelist.hasRole(hookTargetWhitelist.WILD_CARD_SELECTOR(), user1));
        vm.stopPrank();

        (bool success,) = address(hookTargetWhitelist).call(abi.encode(selector, user1));
        assertTrue(success);
    }

    function test_disallowForAll() public {
        vm.startPrank(admin);
        hookTargetWhitelist.allowForAll(user1);
        assertTrue(hookTargetWhitelist.hasRole(hookTargetWhitelist.WILD_CARD_SELECTOR(), user1));

        hookTargetWhitelist.disallowForAll(user1);
        assertFalse(hookTargetWhitelist.hasRole(hookTargetWhitelist.WILD_CARD_SELECTOR(), user1));
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("foo()"));
        (bool success,) = address(hookTargetWhitelist).call(abi.encode(selector, user1));
        assertFalse(success);
    }

    function test_AllowedForBoth() public {
        bytes4 selector = bytes4(keccak256("foo()"));
        vm.startPrank(admin);
        hookTargetWhitelist.allowForSelector(user1, selector);
        hookTargetWhitelist.allowForAll(user1);
        assertTrue(hookTargetWhitelist.hasRole(selector, user1));
        assertTrue(hookTargetWhitelist.hasRole(hookTargetWhitelist.WILD_CARD_SELECTOR(), user1));
        vm.stopPrank();

        (bool success,) = address(hookTargetWhitelist).call(abi.encode(selector, user1));
        assertTrue(success);
    }
}
