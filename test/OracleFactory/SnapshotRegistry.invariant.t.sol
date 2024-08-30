// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {SnapshotRegistry} from "../../src/SnapshotRegistry/SnapshotRegistry.sol";

uint160 constant ADDRESS_ORDER = 10;

function boundAddr(address a) pure returns (address) {
    return address(uint160(a) % ADDRESS_ORDER);
}

contract SnapshotRegistryHarness is Test {
    SnapshotRegistry public immutable registry;

    struct ElementConfig {
        address element;
        address base;
        address quote;
        uint256 timestamp;
    }

    ElementConfig[] internal addHistory;
    address[] internal revokeHistory;

    constructor(address owner) {
        registry = new SnapshotRegistry(address(1), owner);
    }

    function getAddHistory() external view returns (ElementConfig[] memory) {
        return addHistory;
    }

    function getRevokeHistory() external view returns (address[] memory) {
        return revokeHistory;
    }

    function add(address element, address base, address quote) external {
        element = boundAddr(element);
        vm.prank(msg.sender);
        registry.add(element, base, quote);
        addHistory.push(ElementConfig(element, base, quote, block.timestamp));
    }

    function revoke(address element) external {
        element = boundAddr(element);
        vm.prank(msg.sender);
        registry.revoke(element);
        revokeHistory.push(element);
    }

    function skipTime(uint256 delta) external {
        delta = _bound(delta, 1, 1 days);
        skip(delta);
    }
}

contract SnapshotRegistryInvariantTest is Test {
    SnapshotRegistryHarness internal harness;
    SnapshotRegistry internal registry;
    address internal OWNER;

    function setUp() public {
        OWNER = makeAddr("OWNER");

        harness = new SnapshotRegistryHarness(OWNER);
        registry = harness.registry();
        targetContract(address(harness));
        targetSender(OWNER);

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = SnapshotRegistryHarness.add.selector;
        selectors[1] = SnapshotRegistryHarness.revoke.selector;
        selectors[2] = SnapshotRegistryHarness.skipTime.selector;
        targetSelector(FuzzSelector(address(harness), selectors));

        vm.warp(365 days);
    }

    /// @dev An element can only be added once.
    /// forge-config: default.invariant.runs = 50
    /// forge-config: default.invariant.depth = 200
    function invariant_AddAtMostOnce() public view {
        SnapshotRegistryHarness.ElementConfig[] memory addHistory = harness.getAddHistory();
        uint256 length = addHistory.length;
        if (length < 2) return;

        for (uint256 i = 0; i < length; ++i) {
            address added_i = addHistory[i].element;
            for (uint256 j = i + 1; j < length - 1; ++j) {
                address added_j = addHistory[j].element;
                vm.assertNotEq(added_i, added_j);
            }
        }
    }

    /// @dev An element can only be revoked once.
    /// forge-config: default.invariant.runs = 50
    /// forge-config: default.invariant.depth = 200
    function invariant_RevokeAtMostOnce() public view {
        address[] memory revokeHistory = harness.getRevokeHistory();
        uint256 length = revokeHistory.length;
        if (length < 2) return;

        for (uint256 i = 0; i < length; ++i) {
            address revoked_i = revokeHistory[i];
            for (uint256 j = i + 1; j < length - 1; ++j) {
                address revoked_j = revokeHistory[j];
                vm.assertNotEq(revoked_i, revoked_j);
            }
        }
    }

    /// @dev If an element is revoked then it must have been added.
    /// forge-config: default.invariant.runs = 50
    /// forge-config: default.invariant.depth = 200
    function invariant_IfRevokeThenExistsAdd() public view {
        SnapshotRegistryHarness.ElementConfig[] memory addHistory = harness.getAddHistory();
        address[] memory revokeHistory = harness.getRevokeHistory();

        for (uint256 i = 0; i < revokeHistory.length; ++i) {
            address revoked_i = revokeHistory[i];
            bool found;
            for (uint256 j = 0; j < addHistory.length; ++j) {
                address added_j = addHistory[j].element;
                if (added_j == revoked_i) {
                    found = true;
                    break;
                }
            }
            assertTrue(found);
        }
    }

    /// @dev If an element has been added, then addedAt > 0.
    /// forge-config: default.invariant.runs = 50
    /// forge-config: default.invariant.depth = 200
    function invariant_AddPostState() public view {
        SnapshotRegistryHarness.ElementConfig[] memory addHistory = harness.getAddHistory();

        for (uint256 i = 0; i < addHistory.length; ++i) {
            address added_i = addHistory[i].element;
            (uint128 addedAt,) = registry.entries(added_i);
            assertGt(addedAt, 0);
        }
    }

    /// @dev If an element has been revoked, then revokedAt >= addedAt > 0.
    /// forge-config: default.invariant.runs = 50
    /// forge-config: default.invariant.depth = 200
    function invariant_RevokePostState() public view {
        address[] memory revokeHistory = harness.getRevokeHistory();

        for (uint256 i = 0; i < revokeHistory.length; ++i) {
            address revoked_i = revokeHistory[i];
            (uint128 addedAt, uint128 revokedAt) = registry.entries(revoked_i);
            assertGe(revokedAt, addedAt);
            assertGt(addedAt, 0);
        }
    }

    /// @dev `getValidAddresses` returns the element at the timestamp.
    /// It returns the same array for (base, quote) and (quote, base).
    /// forge-config: default.invariant.runs = 50
    /// forge-config: default.invariant.depth = 200
    function invariant_ValidElementList() public view {
        SnapshotRegistryHarness.ElementConfig[] memory addHistory = harness.getAddHistory();

        for (uint256 i = 0; i < addHistory.length; ++i) {
            address[] memory validElements =
                registry.getValidAddresses(addHistory[i].base, addHistory[i].quote, addHistory[i].timestamp);
            address[] memory validElementsInv =
                registry.getValidAddresses(addHistory[i].quote, addHistory[i].base, addHistory[i].timestamp);
            assertEq(keccak256(abi.encode(validElements)), keccak256(abi.encode(validElementsInv)));
            (uint128 addedAt, uint128 revokedAt) = registry.entries(addHistory[i].element);
            if (revokedAt == addedAt) continue;
            assertEq(validElements[validElements.length - 1], addHistory[i].element);
            assertEq(validElements[validElements.length - 1], addHistory[i].element);
        }
    }
}
