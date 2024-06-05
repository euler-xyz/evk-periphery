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
    address internal BASE_A;
    address internal BASE_B;
    address internal QUOTE_A;
    address internal QUOTE_B;
    AdapterRegistry internal registry;

    function setUp() public {
        OWNER = makeAddr("OWNER");
        ADAPTER_A = makeAddr("ADAPTER_A");
        ADAPTER_B = makeAddr("ADAPTER_B");
        ADAPTER_C = makeAddr("ADAPTER_C");
        BASE_A = makeAddr("BASE_A");
        BASE_B = makeAddr("BASE_B");
        QUOTE_A = makeAddr("QUOTE_A");
        QUOTE_B = makeAddr("QUOTE_B");

        registry = new AdapterRegistry(OWNER);
    }

    /// @dev Owner is set to `msg.sender` in constructor.
    function testInitalizeOwner() public view {
        assertEq(registry.owner(), OWNER);
    }

    /// @dev Adapter can be added by the owner.
    function testAdd(address adapter, address base, address quote, uint256 timestamp0, uint256 timestamp1) public {
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);
        vm.warp(timestamp0);

        // Event emitted
        vm.expectEmit();
        emit AdapterRegistry.AdapterAdded(adapter, base < quote ? base : quote, base < quote ? quote : base, timestamp0);
        vm.prank(OWNER);
        registry.addAdapter(adapter, base, quote);

        // Entry saved
        (uint128 addedAt, uint128 revokedAt) = registry.entries(adapter);
        assertEq(addedAt, timestamp0);
        assertEq(revokedAt, 0);

        // Valid now
        assertSingleAdapter(adapter, base, quote, timestamp0, true);
        // Valid in the future
        assertSingleAdapter(adapter, base, quote, timestamp1, true);
    }

    /// @dev Many adapter can be added for the same base and quote. They can be queried by base and quote.
    /// forge-config: default.fuzz.runs = 100
    function testAddMany(uint256 length, address base, address quote, uint256 timestamp0, uint256 timestamp1) public {
        length = bound(length, 2, 100);
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);
        vm.warp(timestamp0);

        address[] memory adapters = new address[](length);

        for (uint256 i = 0; i < length; ++i) {
            address adapter = address(uint160(uint256(keccak256(abi.encode(base, quote, i)))));
            adapters[i] = adapter;

            // Event emitted
            vm.expectEmit();
            emit AdapterRegistry.AdapterAdded(
                adapter, base < quote ? base : quote, base < quote ? quote : base, timestamp0
            );
            vm.prank(OWNER);
            registry.addAdapter(adapter, base, quote);

            // Entry saved
            (uint128 addedAt, uint128 revokedAt) = registry.entries(adapter);
            assertEq(addedAt, timestamp0);
            assertEq(revokedAt, 0);

            address[] memory validAdaptersAt0 = registry.getValidAdapters(base, quote, timestamp0);
            address[] memory validAdaptersAt0Inv = registry.getValidAdapters(quote, base, timestamp0);
            address[] memory validAdaptersAt1 = registry.getValidAdapters(base, quote, timestamp1);
            address[] memory validAdaptersAt1Inv = registry.getValidAdapters(quote, base, timestamp1);

            // Valid at timestamp0 and timestamp 1 independent of key order.
            assertEq(validAdaptersAt0.length, i + 1);
            assertEq(validAdaptersAt0Inv.length, i + 1);
            assertEq(validAdaptersAt1.length, i + 1);
            assertEq(validAdaptersAt1Inv.length, i + 1);

            // Verify adapter list up to now
            for (uint256 k = 0; k < i + 1; k++) {
                assertEq(validAdaptersAt0[k], adapters[k]);
                assertEq(validAdaptersAt0Inv[k], adapters[k]);
                assertEq(validAdaptersAt1[k], adapters[k]);
                assertEq(validAdaptersAt1Inv[k], adapters[k]);
            }
        }
    }

    /// @dev Adapter can be added by anyone other than the owner.
    function testAddUnauthorized(address caller, address adapter, address base, address quote, uint256 timestamp)
        public
    {
        vm.assume(caller != OWNER);
        timestamp = bound(timestamp, 1, type(uint128).max);
        vm.warp(timestamp);

        // Try to add an adapter from an unauthorized account
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        registry.addAdapter(adapter, base, quote);
    }

    /// @dev Adapter cannot be added twice.
    function testAddDuplicate(address adapter, address base, address quote, uint256 timestamp0, uint256 timestamp1)
        public
    {
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);
        vm.warp(timestamp0);

        // Add an adapter
        vm.startPrank(OWNER);
        registry.addAdapter(adapter, base, quote);

        // Reject duplicate now
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter, base, quote);
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter, quote, base);
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter, address(1), address(2));

        // Reject duplicate in the future
        vm.warp(timestamp1);
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter, base, quote);
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter, quote, base);
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter, address(1), address(2));
    }

    /// @dev Adapter can be revoked.
    function testRevoke(
        address adapter,
        address base,
        address quote,
        uint256 timestamp0,
        uint256 timestamp1,
        uint256 timestamp2
    ) public {
        timestamp0 = bound(timestamp0, 1, type(uint128).max - 2);
        timestamp1 = bound(timestamp1, timestamp0 + 1, type(uint128).max - 1);
        timestamp2 = bound(timestamp2, timestamp1 + 1, type(uint128).max);
        vm.startPrank(OWNER);

        // Add adapter
        vm.warp(timestamp0);
        registry.addAdapter(adapter, base, quote);

        // Revoke after time
        vm.warp(timestamp2);
        registry.revokeAdapter(adapter);

        // Valid at add time
        assertSingleAdapter(adapter, base, quote, timestamp0, true);

        // Valid in the middle
        assertSingleAdapter(adapter, base, quote, timestamp1, true);

        // Invalid in the end
        assertSingleAdapter(adapter, base, quote, timestamp2, false);
    }

    /// @dev Adapter can be revoked by anyone other than the owner.
    function testRevokeUnauthorized(
        address caller,
        address adapter,
        address base,
        address quote,
        uint256 timestamp0,
        uint256 timestamp1
    ) public {
        vm.assume(caller != OWNER);
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);

        // Add adapter
        vm.warp(timestamp0);
        vm.prank(OWNER);
        registry.addAdapter(adapter, base, quote);

        // Try to revoke it from an unauthorized account
        vm.warp(timestamp1);
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        registry.revokeAdapter(adapter);
    }

    /// @dev Adapter can be revoked immediately.
    function testRevokeImmediately(address adapter, address base, address quote, uint256 timestamp0, uint256 timestamp1)
        public
    {
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);
        vm.warp(timestamp0);

        vm.startPrank(OWNER);
        // Add and revoke immediately
        registry.addAdapter(adapter, base, quote);
        registry.revokeAdapter(adapter);

        // Invalid now
        assertSingleAdapter(adapter, base, quote, timestamp0, false);
        // Invalid in the future
        assertSingleAdapter(adapter, base, quote, timestamp1, false);
    }

    /// @dev Adapter cannot be re-added after being revoked.
    function testAddAfterRevoke(
        address adapter,
        address base,
        address quote,
        uint256 timestamp0,
        uint256 timestamp1,
        uint256 timestamp2
    ) public {
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);
        timestamp2 = bound(timestamp2, timestamp1, type(uint128).max);

        vm.startPrank(OWNER);

        vm.warp(timestamp0);
        registry.addAdapter(adapter, base, quote);

        vm.warp(timestamp1);
        registry.revokeAdapter(adapter);

        // Reject re-add immediately
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter, base, quote);
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter, quote, base);
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter, address(1), address(2));

        // Reject re-add in the future
        vm.warp(timestamp2);
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter, base, quote);
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter, quote, base);
        vm.expectRevert(AdapterRegistry.Registry_AlreadyAdded.selector);
        registry.addAdapter(adapter, address(1), address(2));
    }

    /// @dev Adapter cannot be revoked if it wasn't added.
    function testRevokeNotAdded(address adapter, uint256 timestamp) public {
        timestamp = bound(timestamp, 1, type(uint128).max);
        vm.warp(timestamp);
        vm.prank(OWNER);
        vm.expectRevert(AdapterRegistry.Registry_NotAdded.selector);
        registry.revokeAdapter(adapter);
    }

    /// @dev Assert that a given adapter is valid or invalid at a timestamp and it is the single one for (base, quote)
    /// independent of order.
    function assertSingleAdapter(address adapter, address base, address quote, uint256 timestamp, bool isValid)
        internal
        view
    {
        assertEq(registry.isValidAdapter(adapter, timestamp), isValid);
        address[] memory validAdapters = registry.getValidAdapters(base, quote, timestamp);
        address[] memory validAdaptersInv = registry.getValidAdapters(quote, base, timestamp);
        uint256 expectedLength = isValid ? 1 : 0;
        assertEq(validAdapters.length, expectedLength);
        assertEq(validAdaptersInv.length, expectedLength);
        if (isValid) {
            assertEq(validAdapters[0], adapter);
            assertEq(validAdaptersInv[0], adapter);
        }
    }
}
