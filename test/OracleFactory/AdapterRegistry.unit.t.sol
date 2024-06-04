// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {AdapterRegistry} from "../../src/OracleFactory/AdapterRegistry.sol";

contract AdapterRegistryTest is Test {
    address internal OWNER;
    address internal ADAPTER_A;
    address internal ADAPTER_B;
    address internal ADAPTER_C;
    AdapterRegistry internal registry;

    function setUp() public {
        OWNER = makeAddr("OWNER");
        ADAPTER_A = makeAddr("ADAPTER_A");
        ADAPTER_B = makeAddr("ADAPTER_B");
        ADAPTER_C = makeAddr("ADAPTER_C");

        registry = new AdapterRegistry(OWNER);
    }

    /// @dev Owner is set to `msg.sender` in constructor.
    function testInitalizeOwner() public view {
        assertEq(registry.owner(), OWNER);
    }

    /// @dev Adapter can be added by the owner.
    function testAdd(address adapter, uint256 timestamp0, uint256 timestamp1) public {
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);
        vm.warp(timestamp0);

        // Event emitted
        vm.expectEmit();
        emit AdapterRegistry.AdapterAdded(adapter, timestamp0);
        vm.prank(OWNER);
        registry.addAdapter(adapter);

        // Entry saved
        (uint128 addedAt, uint128 revokedAt) = registry.entries(adapter);
        assertEq(addedAt, timestamp0);
        assertEq(revokedAt, 0);

        // Valid now
        assertTrue(registry.isValidAdapter(adapter, timestamp0));
        // Valid in the future
        assertTrue(registry.isValidAdapter(adapter, timestamp1));
    }

    /// @dev Adapter can be added by anyone other than the owner.
    function testAddUnauthorized(address caller, address adapter, uint256 timestamp) public {
        vm.assume(caller != OWNER);
        timestamp = bound(timestamp, 1, type(uint128).max);
        vm.warp(timestamp);

        // Try to add an adapter from an unauthorized account
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        registry.addAdapter(adapter);
    }

    /// @dev Adapter cannot be added twice.
    function testAddDuplicate(address adapter, uint256 timestamp0, uint256 timestamp1) public {
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);
        vm.warp(timestamp0);

        // Add an adapter
        vm.startPrank(OWNER);
        registry.addAdapter(adapter);

        // Reject duplicate now
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter);

        // Reject duplicate in the future
        vm.warp(timestamp1);
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter);
    }

    /// @dev Adapter can be revoked.
    function testRevoke(address adapter, uint256 timestamp0, uint256 timestamp1, uint256 timestamp2) public {
        timestamp0 = bound(timestamp0, 1, type(uint128).max - 2);
        timestamp1 = bound(timestamp1, timestamp0 + 1, type(uint128).max - 1);
        timestamp2 = bound(timestamp2, timestamp1 + 1, type(uint128).max);
        vm.startPrank(OWNER);

        // Add adapter
        vm.warp(timestamp0);
        registry.addAdapter(adapter);

        // Revoke after time
        vm.warp(timestamp2);
        registry.revokeAdapter(adapter);

        // Valid at add time
        assertTrue(registry.isValidAdapter(adapter, timestamp0));
        // Valid in the middle
        assertTrue(registry.isValidAdapter(adapter, timestamp1));
        // Invalid in the end
        assertFalse(registry.isValidAdapter(adapter, timestamp2));
    }

    /// @dev Adapter can be revoked by anyone other than the owner.
    function testRevokeUnauthorized(address caller, address adapter, uint256 timestamp0, uint256 timestamp1) public {
        vm.assume(caller != OWNER);
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);

        // Add adapter
        vm.warp(timestamp0);
        vm.prank(OWNER);
        registry.addAdapter(adapter);

        // Try to revoke it from an unauthorized account
        vm.warp(timestamp1);
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        registry.revokeAdapter(adapter);
    }

    /// @dev Adapter can be revoked immediately.
    function testRevokeImmediately(address adapter, uint256 timestamp0, uint256 timestamp1) public {
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);
        vm.warp(timestamp0);

        vm.startPrank(OWNER);
        // Add and revoke immediately
        registry.addAdapter(adapter);
        registry.revokeAdapter(adapter);

        // Invalid now
        assertFalse(registry.isValidAdapter(adapter, timestamp0));
        // Invalid in the future
        assertFalse(registry.isValidAdapter(adapter, timestamp1));
    }
    /// @dev Adapter cannot be re-added after being revoked.

    function testAddAfterRevoke(address adapter, uint256 timestamp0, uint256 timestamp1, uint256 timestamp2) public {
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);
        timestamp2 = bound(timestamp2, timestamp1, type(uint128).max);

        vm.startPrank(OWNER);

        vm.warp(timestamp0);
        registry.addAdapter(adapter);

        vm.warp(timestamp1);
        registry.revokeAdapter(adapter);

        // Reject re-add immediately
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter);

        // Reject re-add in the future
        vm.warp(timestamp2);
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter);
    }

    /// @dev Adapter cannot be revoked if it wasn't added.
    function testRevokeNotAdded(address adapter, uint256 timestamp) public {
        timestamp = bound(timestamp, 1, type(uint128).max);
        vm.warp(timestamp);
        vm.prank(OWNER);
        vm.expectRevert(AdapterRegistry.Registry_NotAdded.selector);
        registry.revokeAdapter(adapter);
    }
}
