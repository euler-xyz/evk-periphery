// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {HookTargetAccessControl} from "../../src/HookTarget/HookTargetAccessControl.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";

contract HookTargetAccessControlTest is EVaultTestBase {
    HookTargetAccessControl public hookTargetAccessControl;
    address public user1;
    address public user1SubAccount;

    function setUp() public override {
        super.setUp();
        user1 = makeAddr("user1");
        user1SubAccount = address(uint160(user1) ^ 100);
        hookTargetAccessControl = new HookTargetAccessControl(address(evc), admin, address(factory));
    }

    function test_isHookTarget() public {
        vm.prank(address(eTST));
        assertEq(hookTargetAccessControl.isHookTarget(), hookTargetAccessControl.isHookTarget.selector);

        vm.prank(user1);
        assertEq(hookTargetAccessControl.isHookTarget(), 0);
    }

    function test_allowSelector() public {
        bytes memory data = abi.encodeWithSignature("foo()");
        bytes memory anyData = abi.encodeWithSignature("bar()");
        bytes4 selector = bytes4(data);

        vm.startPrank(admin);
        hookTargetAccessControl.grantRole(selector, user1);
        assertTrue(hookTargetAccessControl.hasRole(selector, user1));
        hookTargetAccessControl.grantRole(selector, user1SubAccount);
        assertTrue(hookTargetAccessControl.hasRole(selector, user1SubAccount));
        vm.stopPrank();

        vm.prank(address(eTST));
        (bool success,) = address(hookTargetAccessControl).call(abi.encodePacked(data, user1));
        assertTrue(success);

        vm.prank(address(eTST));
        (success,) = address(hookTargetAccessControl).call(abi.encodePacked(anyData, user1));
        assertFalse(success);

        vm.prank(user1);
        evc.call(address(hookTargetAccessControl), address(user1), 0, data);

        vm.prank(user1);
        vm.expectRevert();
        evc.call(address(hookTargetAccessControl), address(user1), 0, anyData);

        vm.prank(user1);
        evc.call(address(hookTargetAccessControl), address(user1SubAccount), 0, data);

        vm.prank(user1);
        vm.expectRevert();
        evc.call(address(hookTargetAccessControl), address(user1SubAccount), 0, anyData);

        vm.prank(user1);
        (success,) = address(hookTargetAccessControl).call(data);
        assertTrue(success);

        vm.prank(user1);
        (success,) = address(hookTargetAccessControl).call(anyData);
        assertFalse(success);
    }

    function test_allowAllSelectors() public {
        bytes memory data = abi.encodeWithSignature("foo()");
        bytes memory anyData = abi.encodeWithSignature("bar()");
        bytes32 wildcard = hookTargetAccessControl.WILD_CARD();

        vm.startPrank(admin);
        hookTargetAccessControl.grantRole(wildcard, user1);
        assertTrue(hookTargetAccessControl.hasRole(wildcard, user1));
        hookTargetAccessControl.grantRole(wildcard, user1SubAccount);
        assertTrue(hookTargetAccessControl.hasRole(wildcard, user1SubAccount));
        vm.stopPrank();

        vm.prank(address(eTST));
        (bool success,) = address(hookTargetAccessControl).call(abi.encodePacked(data, user1));
        assertTrue(success);

        vm.prank(address(eTST));
        (success,) = address(hookTargetAccessControl).call(abi.encodePacked(anyData, user1));
        assertTrue(success);

        vm.prank(user1);
        evc.call(address(hookTargetAccessControl), address(user1), 0, data);

        vm.prank(user1);
        evc.call(address(hookTargetAccessControl), address(user1), 0, anyData);

        vm.prank(user1);
        evc.call(address(hookTargetAccessControl), address(user1SubAccount), 0, data);

        vm.prank(user1);
        evc.call(address(hookTargetAccessControl), address(user1SubAccount), 0, anyData);

        vm.prank(user1);
        (success,) = address(hookTargetAccessControl).call(data);
        assertTrue(success);

        vm.prank(user1);
        (success,) = address(hookTargetAccessControl).call(anyData);
        assertTrue(success);
    }

    function test_revert_notAdmin() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, bytes32(0))
        );
        hookTargetAccessControl.grantRole(0, user1);
    }

    function test_revert_initializeTwice() public {
        vm.expectRevert();
        hookTargetAccessControl.initialize(admin);
    }
}
