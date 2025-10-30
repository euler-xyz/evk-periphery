// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {EthereumVaultConnector, Errors} from "ethereum-vault-connector/EthereumVaultConnector.sol";
import {SnapshotRegistry} from "../../src/SnapshotRegistry/SnapshotRegistry.sol";

contract SnapshotRegistryTest is Test {
    address internal OWNER;
    address internal ELEMENT_A;
    address internal ELEMENT_B;
    address internal ELEMENT_C;
    address internal BASE_A;
    address internal BASE_B;
    address internal QUOTE_A;
    address internal QUOTE_B;
    EthereumVaultConnector internal evc;
    SnapshotRegistry internal registry;

    function setUp() public {
        OWNER = makeAddr("OWNER");
        ELEMENT_A = makeAddr("ELEMENT_A");
        ELEMENT_B = makeAddr("ELEMENT_B");
        ELEMENT_C = makeAddr("ELEMENT_C");
        BASE_A = makeAddr("BASE_A");
        BASE_B = makeAddr("BASE_B");
        QUOTE_A = makeAddr("QUOTE_A");
        QUOTE_B = makeAddr("QUOTE_B");
        evc = new EthereumVaultConnector();

        registry = new SnapshotRegistry(address(evc), OWNER);
    }

    /// @dev EVC address is stored and the owner is set to `msg.sender` in constructor.
    function testInitialize() public view {
        assertEq(registry.EVC(), address(evc));
        assertEq(registry.owner(), OWNER);
    }

    /// @dev Element can be added by the owner.
    function testAdd(address element, address base, address quote, uint256 timestamp0, uint256 timestamp1) public {
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);
        vm.warp(timestamp0);

        uint256 snapshot = vm.snapshot();

        // Event emitted
        vm.expectEmit();
        emit SnapshotRegistry.Added(element, base < quote ? base : quote, base < quote ? quote : base, timestamp0);
        vm.prank(OWNER);
        registry.add(element, base, quote);

        // Entry saved
        (uint128 addedAt, uint128 revokedAt) = registry.entries(element);
        assertEq(addedAt, timestamp0);
        assertEq(revokedAt, 0);

        // Valid now
        assertSingleElement(element, base, quote, timestamp0, true);
        // Valid in the future
        assertSingleElement(element, base, quote, timestamp1, true);

        vm.revertTo(snapshot);

        // Try via the EVC
        // Event emitted
        vm.expectEmit();
        emit SnapshotRegistry.Added(element, base < quote ? base : quote, base < quote ? quote : base, timestamp0);
        vm.prank(OWNER);
        evc.call(address(registry), OWNER, 0, abi.encodeCall(registry.add, (element, base, quote)));

        // Entry saved
        (addedAt, revokedAt) = registry.entries(element);
        assertEq(addedAt, timestamp0);
        assertEq(revokedAt, 0);

        // Valid now
        assertSingleElement(element, base, quote, timestamp0, true);
        // Valid in the future
        assertSingleElement(element, base, quote, timestamp1, true);
    }

    /// @dev Many elements can be added for the same base and quote. They can be queried by base and quote.
    /// forge-config: default.fuzz.runs = 100
    function testAddMany(uint256 length, address base, address quote, uint256 timestamp0, uint256 timestamp1) public {
        length = bound(length, 2, 100);
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);
        vm.warp(timestamp0);

        address[] memory elements = new address[](length);

        for (uint256 i = 0; i < length; ++i) {
            address element = address(uint160(uint256(keccak256(abi.encode(base, quote, i)))));
            elements[i] = element;

            // Event emitted
            vm.expectEmit();
            emit SnapshotRegistry.Added(element, base < quote ? base : quote, base < quote ? quote : base, timestamp0);
            vm.prank(OWNER);
            registry.add(element, base, quote);

            // Entry saved
            (uint128 addedAt, uint128 revokedAt) = registry.entries(element);
            assertEq(addedAt, timestamp0);
            assertEq(revokedAt, 0);

            address[] memory validElementsAt0 = registry.getValidAddresses(base, quote, timestamp0);
            address[] memory validElementsAt0Inv = registry.getValidAddresses(quote, base, timestamp0);
            address[] memory validElementsAt1 = registry.getValidAddresses(base, quote, timestamp1);
            address[] memory validElementsAt1Inv = registry.getValidAddresses(quote, base, timestamp1);

            // Valid at timestamp0 and timestamp 1 independent of key order.
            assertEq(validElementsAt0.length, i + 1);
            assertEq(validElementsAt0Inv.length, i + 1);
            assertEq(validElementsAt1.length, i + 1);
            assertEq(validElementsAt1Inv.length, i + 1);

            // Verify element list up to now
            for (uint256 k = 0; k < i + 1; k++) {
                assertEq(validElementsAt0[k], elements[k]);
                assertEq(validElementsAt0Inv[k], elements[k]);
                assertEq(validElementsAt1[k], elements[k]);
                assertEq(validElementsAt1Inv[k], elements[k]);
            }
        }
    }

    /// @dev Element can be added by anyone other than the owner.
    function testAddUnauthorized(address caller, address element, address base, address quote, uint256 timestamp)
        public
    {
        vm.assume(caller != address(evc) && caller != OWNER);
        timestamp = bound(timestamp, 1, type(uint128).max);
        vm.warp(timestamp);

        // Try to add an element from an unauthorized account
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        registry.add(element, base, quote);

        vm.prank(address(evc));
        vm.expectRevert(abi.encodeWithSelector(Errors.EVC_OnBehalfOfAccountNotAuthenticated.selector));
        registry.add(element, base, quote);
    }

    /// @dev Element cannot be added twice.
    function testAddDuplicate(address element, address base, address quote, uint256 timestamp0, uint256 timestamp1)
        public
    {
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);
        vm.warp(timestamp0);

        // Add an element
        vm.startPrank(OWNER);
        registry.add(element, base, quote);

        // Reject duplicate now
        vm.expectRevert(SnapshotRegistry.Registry_AlreadyAdded.selector);
        registry.add(element, base, quote);
        vm.expectRevert(SnapshotRegistry.Registry_AlreadyAdded.selector);
        registry.add(element, quote, base);
        vm.expectRevert(SnapshotRegistry.Registry_AlreadyAdded.selector);
        registry.add(element, address(1), address(2));

        // Reject duplicate in the future
        vm.warp(timestamp1);
        vm.expectRevert(SnapshotRegistry.Registry_AlreadyAdded.selector);
        registry.add(element, base, quote);
        vm.expectRevert(SnapshotRegistry.Registry_AlreadyAdded.selector);
        registry.add(element, quote, base);
        vm.expectRevert(SnapshotRegistry.Registry_AlreadyAdded.selector);
        registry.add(element, address(1), address(2));
    }

    /// @dev Element can be revoked.
    function testRevoke(
        address element,
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

        // Add element
        vm.warp(timestamp0);
        registry.add(element, base, quote);

        // Revoke after time
        vm.warp(timestamp2);

        uint256 snapshot = vm.snapshot();
        registry.revoke(element);

        // Valid at add time
        assertSingleElement(element, base, quote, timestamp0, true);

        // Valid in the middle
        assertSingleElement(element, base, quote, timestamp1, true);

        // Invalid in the end
        assertSingleElement(element, base, quote, timestamp2, false);

        vm.revertTo(snapshot);

        // Try via the EVC
        evc.call(address(registry), OWNER, 0, abi.encodeCall(registry.revoke, (element)));

        // Valid at add time
        assertSingleElement(element, base, quote, timestamp0, true);

        // Valid in the middle
        assertSingleElement(element, base, quote, timestamp1, true);

        // Invalid in the end
        assertSingleElement(element, base, quote, timestamp2, false);
    }

    /// @dev Element can be revoked by anyone other than the owner.
    function testRevokeUnauthorized(
        address caller,
        address element,
        address base,
        address quote,
        uint256 timestamp0,
        uint256 timestamp1
    ) public {
        vm.assume(caller != address(evc) && caller != OWNER);
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);

        // Add element
        vm.warp(timestamp0);
        vm.prank(OWNER);
        registry.add(element, base, quote);

        // Try to revoke it from an unauthorized account
        vm.warp(timestamp1);
        vm.prank(caller);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
        registry.revoke(element);

        vm.prank(address(evc));
        vm.expectRevert(abi.encodeWithSelector(Errors.EVC_OnBehalfOfAccountNotAuthenticated.selector));
        registry.revoke(element);
    }

    /// @dev Element can be revoked immediately.
    function testRevokeImmediately(address element, address base, address quote, uint256 timestamp0, uint256 timestamp1)
        public
    {
        timestamp0 = bound(timestamp0, 1, type(uint128).max);
        timestamp1 = bound(timestamp1, timestamp0, type(uint128).max);
        vm.warp(timestamp0);

        vm.startPrank(OWNER);
        // Add and revoke immediately
        registry.add(element, base, quote);
        registry.revoke(element);

        // Invalid now
        assertSingleElement(element, base, quote, timestamp0, false);
        // Invalid in the future
        assertSingleElement(element, base, quote, timestamp1, false);
    }

    /// @dev Element cannot be re-added after being revoked.
    function testAddAfterRevoke(
        address element,
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
        registry.add(element, base, quote);

        vm.warp(timestamp1);
        registry.revoke(element);

        // Reject re-add immediately
        vm.expectRevert(SnapshotRegistry.Registry_AlreadyAdded.selector);
        registry.add(element, base, quote);
        vm.expectRevert(SnapshotRegistry.Registry_AlreadyAdded.selector);
        registry.add(element, quote, base);
        vm.expectRevert(SnapshotRegistry.Registry_AlreadyAdded.selector);
        registry.add(element, address(1), address(2));

        // Reject re-add in the future
        vm.warp(timestamp2);
        vm.expectRevert(SnapshotRegistry.Registry_AlreadyAdded.selector);
        registry.add(element, base, quote);
        vm.expectRevert(SnapshotRegistry.Registry_AlreadyAdded.selector);
        registry.add(element, quote, base);
        vm.expectRevert(SnapshotRegistry.Registry_AlreadyAdded.selector);
        registry.add(element, address(1), address(2));
    }

    /// @dev Element cannot be revoked if it wasn't added.
    function testRevokeNotAdded(address element, uint256 timestamp) public {
        timestamp = bound(timestamp, 1, type(uint128).max);
        vm.warp(timestamp);
        vm.prank(OWNER);
        vm.expectRevert(SnapshotRegistry.Registry_NotAdded.selector);
        registry.revoke(element);
    }

    function testRenounceTransferOwnership() public {
        address OWNER2 = makeAddr("OWNER2");
        address OWNER3 = makeAddr("OWNER3");

        assertEq(registry.owner(), OWNER);

        vm.prank(OWNER2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, OWNER2));
        registry.renounceOwnership();

        vm.prank(OWNER2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, OWNER2));
        registry.transferOwnership(OWNER2);

        vm.prank(OWNER);
        registry.transferOwnership(OWNER2);
        assertEq(registry.owner(), OWNER2);

        vm.prank(OWNER2);
        registry.transferOwnership(OWNER3);
        assertEq(registry.owner(), OWNER3);

        vm.prank(OWNER2);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, OWNER2));
        registry.renounceOwnership();

        vm.prank(OWNER3);
        registry.renounceOwnership();
        assertEq(registry.owner(), address(0));
    }

    /// @dev Assert that a given element is valid or invalid at a timestamp and it is the single one for (base, quote)
    /// independent of order.
    function assertSingleElement(address element, address base, address quote, uint256 timestamp, bool isValid)
        internal
        view
    {
        assertEq(registry.isValid(element, timestamp), isValid);
        address[] memory validElements = registry.getValidAddresses(base, quote, timestamp);
        address[] memory validElementsInv = registry.getValidAddresses(quote, base, timestamp);
        uint256 expectedLength = isValid ? 1 : 0;
        assertEq(validElements.length, expectedLength);
        assertEq(validElementsInv.length, expectedLength);
        if (isValid) {
            assertEq(validElements[0], element);
            assertEq(validElementsInv[0], element);
        }
    }
}
