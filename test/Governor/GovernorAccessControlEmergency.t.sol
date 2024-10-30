// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVaultTestBase} from "evk-test/unit/evault/EVaultTestBase.t.sol";
import {
    GovernorAccessControl,
    GovernorAccessControlEmergency
} from "../../src/Governor/GovernorAccessControlEmergency.sol";
import {IAccessControl} from "openzeppelin-contracts/access/IAccessControl.sol";
import {IGovernance} from "evk/EVault/IEVault.sol";
import "evk/EVault/shared/Constants.sol";

contract MockTarget {
    function foo() external pure returns (uint256) {
        return 1;
    }

    function bar() external pure returns (bytes memory) {
        return abi.encode(2);
    }
}

contract GovernorAccessControlEmergencyTest is EVaultTestBase {
    MockTarget public mockTarget;
    GovernorAccessControlEmergency public governorAccessControl;
    address public user1;
    address public user2;
    address public user1SubAccount;

    function setUp() public override {
        super.setUp();
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user1SubAccount = address(uint160(user1) ^ 100);
        mockTarget = new MockTarget();
        governorAccessControl = new GovernorAccessControlEmergency(address(evc), admin);
    }

    function test_allowSelector() public {
        bytes memory data = abi.encodeCall(MockTarget.foo, ());
        bytes memory anyData = abi.encodeCall(MockTarget.bar, ());
        bytes4 selector = bytes4(data);

        vm.startPrank(admin);
        governorAccessControl.grantRole(selector, user1);
        assertTrue(governorAccessControl.hasRole(selector, user1));
        governorAccessControl.grantRole(selector, user1SubAccount);
        assertTrue(governorAccessControl.hasRole(selector, user1SubAccount));
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(GovernorAccessControl.MsgDataInvalid.selector));
        evc.call(address(governorAccessControl), address(user1), 0, abi.encodePacked(data));

        vm.prank(user1);
        bytes memory result =
            evc.call(address(governorAccessControl), address(user1), 0, abi.encodePacked(data, mockTarget));
        assertEq(abi.decode(result, (uint256)), 1);

        vm.prank(user1);
        vm.expectRevert();
        evc.call(address(governorAccessControl), address(user1), 0, abi.encodePacked(anyData, mockTarget));

        vm.prank(user1);
        vm.expectRevert();
        evc.call(address(governorAccessControl), address(user1SubAccount), 0, abi.encodePacked(data, mockTarget));

        vm.prank(user1);
        vm.expectRevert();
        evc.call(address(governorAccessControl), address(user1SubAccount), 0, abi.encodePacked(anyData, mockTarget));

        bool success;
        vm.prank(user1);
        (success, result) = address(governorAccessControl).call(data);
        assertFalse(success);

        vm.prank(user1);
        (success, result) = address(governorAccessControl).call(abi.encodePacked(data, mockTarget));
        assertTrue(success);
        assertEq(abi.decode(result, (uint256)), 1);

        vm.prank(user1);
        (success, result) = address(governorAccessControl).call(abi.encodePacked(anyData, mockTarget));
        assertFalse(success);
    }

    function test_allowAllSelectors() public {
        bytes memory data = abi.encodeCall(MockTarget.foo, ());
        bytes memory anyData = abi.encodeCall(MockTarget.bar, ());
        bytes32 wildcard = governorAccessControl.WILD_CARD();

        vm.startPrank(admin);
        governorAccessControl.grantRole(wildcard, user1);
        assertTrue(governorAccessControl.hasRole(wildcard, user1));
        governorAccessControl.grantRole(wildcard, user1SubAccount);
        assertTrue(governorAccessControl.hasRole(wildcard, user1SubAccount));
        vm.stopPrank();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(GovernorAccessControl.MsgDataInvalid.selector));
        evc.call(address(governorAccessControl), address(user1), 0, abi.encodePacked(data));

        vm.prank(user1);
        bytes memory result =
            evc.call(address(governorAccessControl), address(user1), 0, abi.encodePacked(data, mockTarget));
        assertEq(abi.decode(result, (uint256)), 1);

        vm.prank(user1);
        result = evc.call(address(governorAccessControl), address(user1), 0, abi.encodePacked(anyData, mockTarget));
        assertEq(keccak256(abi.decode(result, (bytes))), keccak256(abi.encode(2)));

        vm.prank(user1);
        vm.expectRevert();
        evc.call(address(governorAccessControl), address(user1SubAccount), 0, abi.encodePacked(data, mockTarget));

        vm.prank(user1);
        vm.expectRevert();
        evc.call(address(governorAccessControl), address(user1SubAccount), 0, abi.encodePacked(anyData, mockTarget));

        bool success;
        vm.prank(user1);
        (success, result) = address(governorAccessControl).call(data);
        assertFalse(success);

        vm.prank(user1);
        (success, result) = address(governorAccessControl).call(abi.encodePacked(data, mockTarget));
        assertTrue(success);
        assertEq(abi.decode(result, (uint256)), 1);

        vm.prank(user1);
        (success, result) = address(governorAccessControl).call(abi.encodePacked(anyData, mockTarget));
        assertTrue(success);
        assertEq(keccak256(abi.decode(result, (bytes))), keccak256(abi.encode(2)));
    }

    function test_revert_notAdmin() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, user1, bytes32(0))
        );
        governorAccessControl.grantRole(0, user1);
    }

    function test_revert_initializeTwice() public {
        vm.expectRevert();
        governorAccessControl.initialize(admin);
    }

    function test_setLTV() public {
        vm.warp(100);

        // no ramping scenario
        eTST.setLTV(address(eTST2), 100, 200, 0);
        eTST.setGovernorAdmin(address(governorAccessControl));

        // grant the emergency role to user1 and regular selector role to user2
        vm.startPrank(admin);
        governorAccessControl.grantRole(governorAccessControl.LTV_EMERGENCY_ROLE(), user1);
        governorAccessControl.grantRole(IGovernance.setLTV.selector, user2);
        assertTrue(governorAccessControl.hasRole(governorAccessControl.LTV_EMERGENCY_ROLE(), user1));
        assertTrue(governorAccessControl.hasRole(IGovernance.setLTV.selector, user2));
        vm.stopPrank();

        uint256 snapshot = vm.snapshot();

        // user1 can call the function in emergency mode
        vm.prank(user1);
        (bool success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setLTV, (address(eTST2), 0, 200, 0)), address(eTST))
        );
        assertTrue(success);
        assertEq(eTST.LTVBorrow(address(eTST2)), 0);
        assertEq(eTST.LTVLiquidation(address(eTST2)), 200);
        vm.revertTo(snapshot);

        // user2 can call the function in any mode
        vm.prank(user2);
        (success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setLTV, (address(eTST2), 0, 200, 0)), address(eTST))
        );
        assertTrue(success);
        assertEq(eTST.LTVBorrow(address(eTST2)), 0);
        assertEq(eTST.LTVLiquidation(address(eTST2)), 200);
        vm.revertTo(snapshot);

        // user1 cannot call the function in regular mode
        vm.prank(user1);
        (success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setLTV, (address(eTST2), 0, 0, 0)), address(eTST))
        );
        assertFalse(success);

        // user2 can call the function in any mode
        vm.prank(user2);
        (success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setLTV, (address(eTST2), 0, 0, 0)), address(eTST))
        );
        assertTrue(success);
        assertEq(eTST.LTVBorrow(address(eTST2)), 0);
        assertEq(eTST.LTVLiquidation(address(eTST2)), 0);
        vm.revertTo(snapshot);

        // ramping down scenario
        vm.prank(address(governorAccessControl));
        eTST.setLTV(address(eTST2), 100, 100, 100);
        vm.warp(150);
        snapshot = vm.snapshot();

        // user1 can call the function in emergency mode
        vm.prank(user1);
        (success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setLTV, (address(eTST2), 0, 100, 0)), address(eTST))
        );
        assertTrue(success);
        assertEq(eTST.LTVBorrow(address(eTST2)), 0);
        assertEq(eTST.LTVLiquidation(address(eTST2)), 150); // rampDuration was overridden
        vm.revertTo(snapshot);

        // user2 can call the function in any mode
        vm.prank(user2);
        (success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setLTV, (address(eTST2), 0, 100, 0)), address(eTST))
        );
        assertTrue(success);
        assertEq(eTST.LTVBorrow(address(eTST2)), 0);
        assertEq(eTST.LTVLiquidation(address(eTST2)), 100); // rampDuration was not overridden
        vm.revertTo(snapshot);

        // user1 cannot call the function in regular mode
        vm.prank(user1);
        (success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setLTV, (address(eTST2), 0, 0, 0)), address(eTST))
        );
        assertFalse(success);

        // user2 can call the function in any mode
        vm.prank(user2);
        (success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setLTV, (address(eTST2), 0, 0, 0)), address(eTST))
        );
        assertTrue(success);
        assertEq(eTST.LTVBorrow(address(eTST2)), 0);
        assertEq(eTST.LTVLiquidation(address(eTST2)), 0);
        vm.revertTo(snapshot);
    }

    function test_setHookConfig() public {
        eTST.setGovernorAdmin(address(governorAccessControl));

        // grant the emergency role to user1 and regular selector role to user2
        vm.startPrank(admin);
        governorAccessControl.grantRole(governorAccessControl.HOOK_EMERGENCY_ROLE(), user1);
        governorAccessControl.grantRole(IGovernance.setHookConfig.selector, user2);
        assertTrue(governorAccessControl.hasRole(governorAccessControl.HOOK_EMERGENCY_ROLE(), user1));
        assertTrue(governorAccessControl.hasRole(IGovernance.setHookConfig.selector, user2));
        vm.stopPrank();

        uint256 snapshot = vm.snapshot();

        // user1 can call the function in emergency mode
        vm.prank(user1);
        (bool success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setHookConfig, (address(0), OP_MAX_VALUE - 1)), address(eTST))
        );
        assertTrue(success);
        (address hookTarget, uint32 hookedOps) = eTST.hookConfig();
        assertEq(hookTarget, address(0));
        assertEq(hookedOps, OP_MAX_VALUE - 1);
        vm.revertTo(snapshot);

        // user2 can call the function in any mode
        vm.prank(user2);
        (success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setHookConfig, (address(0), OP_MAX_VALUE - 1)), address(eTST))
        );
        assertTrue(success);
        (hookTarget, hookedOps) = eTST.hookConfig();
        assertEq(hookTarget, address(0));
        assertEq(hookedOps, OP_MAX_VALUE - 1);
        vm.revertTo(snapshot);

        // user1 cannot call the function in regular mode
        vm.prank(user1);
        (success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setHookConfig, (address(0), 1)), address(eTST))
        );
        assertFalse(success);

        // user2 can call the function in any mode
        vm.prank(user2);
        (success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setHookConfig, (address(0), 1)), address(eTST))
        );
        assertTrue(success);
        (hookTarget, hookedOps) = eTST.hookConfig();
        assertEq(hookTarget, address(0));
        assertEq(hookedOps, 1);
        vm.revertTo(snapshot);
    }

    function test_setCaps() public {
        eTST.setCaps(uint16(1000 << 6), uint16(900 << 6));
        eTST.setGovernorAdmin(address(governorAccessControl));

        // grant the emergency role to user1 and regular selector role to user2
        vm.startPrank(admin);
        governorAccessControl.grantRole(governorAccessControl.CAPS_EMERGENCY_ROLE(), user1);
        governorAccessControl.grantRole(IGovernance.setCaps.selector, user2);
        assertTrue(governorAccessControl.hasRole(governorAccessControl.CAPS_EMERGENCY_ROLE(), user1));
        assertTrue(governorAccessControl.hasRole(IGovernance.setCaps.selector, user2));
        vm.stopPrank();

        uint256 snapshot = vm.snapshot();

        // user1 can call the function in emergency mode
        vm.prank(user1);
        (bool success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setCaps, (uint16(500 << 6), uint16(500 << 6))), address(eTST))
        );
        assertTrue(success);
        (uint16 supplyCap, uint16 borrowCap) = eTST.caps();
        assertEq(supplyCap, 500 << 6);
        assertEq(borrowCap, 500 << 6);
        vm.revertTo(snapshot);

        // user2 can call the function in any mode
        vm.prank(user2);
        (success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setCaps, (uint16(500 << 6), uint16(500 << 6))), address(eTST))
        );
        assertTrue(success);
        (supplyCap, borrowCap) = eTST.caps();
        assertEq(supplyCap, 500 << 6);
        assertEq(borrowCap, 500 << 6);
        vm.revertTo(snapshot);

        // user1 cannot call the function in regular mode
        vm.prank(user1);
        (success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setCaps, (uint16(1000 << 6), uint16(900 << 6))), address(eTST))
        );
        assertFalse(success);

        vm.prank(user1);
        (success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setCaps, (uint16(900 << 6), uint16(1000 << 6))), address(eTST))
        );
        assertFalse(success);

        // user2 can call the function in any mode
        vm.prank(user2);
        (success,) = address(governorAccessControl).call(
            abi.encodePacked(abi.encodeCall(IGovernance.setCaps, (uint16(900 << 6), uint16(1000 << 6))), address(eTST))
        );
        assertTrue(success);
        (supplyCap, borrowCap) = eTST.caps();
        assertEq(supplyCap, 900 << 6);
        assertEq(borrowCap, 1000 << 6);
        vm.revertTo(snapshot);
    }
}
