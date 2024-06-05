// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {AdapterRegistry} from "../../src/OracleFactory/AdapterRegistry.sol";

uint160 constant ADDRESS_ORDER = 10;

function boundAddr(address a) pure returns (address) {
    return address(uint160(a) % ADDRESS_ORDER);
}

contract AdapterRegistryHarness is Test {
    AdapterRegistry public immutable registry;

    struct AdapterConfig {
        address adapter;
        address base;
        address quote;
        uint256 timestamp;
    }

    AdapterConfig[] internal addHistory;
    address[] internal revokeHistory;

    constructor(address owner) {
        registry = new AdapterRegistry(owner);
    }

    function getAddHistory() external view returns (AdapterConfig[] memory) {
        return addHistory;
    }

    function getRevokeHistory() external view returns (address[] memory) {
        return revokeHistory;
    }

    function addAdapter(address adapter, address base, address quote) external {
        adapter = boundAddr(adapter);
        vm.prank(msg.sender);
        registry.addAdapter(adapter, base, quote);
        addHistory.push(AdapterConfig(adapter, base, quote, block.timestamp));
    }

    function revokeAdapter(address adapter) external {
        adapter = boundAddr(adapter);
        vm.prank(msg.sender);
        registry.revokeAdapter(adapter);
        revokeHistory.push(adapter);
    }

    function skipTime(uint256 delta) external {
        delta = _bound(delta, 1, 1 days);
        skip(delta);
    }
}

contract AdapterRegistryInvariantTest is Test {
    AdapterRegistryHarness internal harness;
    AdapterRegistry internal registry;
    address internal OWNER;

    function setUp() public {
        OWNER = makeAddr("OWNER");

        harness = new AdapterRegistryHarness(OWNER);
        registry = harness.registry();
        targetContract(address(harness));
        targetSender(OWNER);

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = AdapterRegistryHarness.addAdapter.selector;
        selectors[1] = AdapterRegistryHarness.revokeAdapter.selector;
        selectors[2] = AdapterRegistryHarness.skipTime.selector;
        targetSelector(FuzzSelector(address(harness), selectors));

        vm.warp(365 days);
    }

    /// @dev An adapter can only be added once.
    /// forge-config: default.invariant.runs = 50
    /// forge-config: default.invariant.depth = 200
    function invariant_AddAtMostOnce() public view {
        AdapterRegistryHarness.AdapterConfig[] memory addHistory = harness.getAddHistory();
        uint256 length = addHistory.length;
        if (length < 2) return;

        for (uint256 i = 0; i < length; ++i) {
            address added_i = addHistory[i].adapter;
            for (uint256 j = i + 1; j < length - 1; ++j) {
                address added_j = addHistory[j].adapter;
                vm.assertNotEq(added_i, added_j);
            }
        }
    }

    /// @dev An adapter can only be revoked once.
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

    /// @dev If an adapter is revoked then it must have been added.
    /// forge-config: default.invariant.runs = 50
    /// forge-config: default.invariant.depth = 200
    function invariant_IfRevokeThenExistsAdd() public view {
        AdapterRegistryHarness.AdapterConfig[] memory addHistory = harness.getAddHistory();
        address[] memory revokeHistory = harness.getRevokeHistory();

        for (uint256 i = 0; i < revokeHistory.length; ++i) {
            address revoked_i = revokeHistory[i];
            bool found;
            for (uint256 j = 0; j < addHistory.length; ++j) {
                address added_j = addHistory[j].adapter;
                if (added_j == revoked_i) {
                    found = true;
                    break;
                }
            }
            assertTrue(found);
        }
    }

    /// @dev If an adapter has been added, then addedAt > 0.
    /// forge-config: default.invariant.runs = 50
    /// forge-config: default.invariant.depth = 200
    function invariant_AddPostState() public view {
        AdapterRegistryHarness.AdapterConfig[] memory addHistory = harness.getAddHistory();

        for (uint256 i = 0; i < addHistory.length; ++i) {
            address added_i = addHistory[i].adapter;
            (uint128 addedAt,) = registry.entries(added_i);
            assertGt(addedAt, 0);
        }
    }

    /// @dev If an adapter has been revoked, then revokedAt >= addedAt > 0.
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

    /// @dev `getValidAdapters` returns the adapter at the timestamp.
    /// It returns the same array for (base, quote) and (quote, base).
    /// forge-config: default.invariant.runs = 50
    /// forge-config: default.invariant.depth = 200
    function invariant_ValidAdapterList() public view {
        AdapterRegistryHarness.AdapterConfig[] memory addHistory = harness.getAddHistory();

        for (uint256 i = 0; i < addHistory.length; ++i) {
            address[] memory validAdapters =
                registry.getValidAdapters(addHistory[i].base, addHistory[i].quote, addHistory[i].timestamp);
            address[] memory validAdaptersInv =
                registry.getValidAdapters(addHistory[i].quote, addHistory[i].base, addHistory[i].timestamp);
            assertEq(keccak256(abi.encode(validAdapters)), keccak256(abi.encode(validAdaptersInv)));
            (uint128 addedAt, uint128 revokedAt) = registry.entries(addHistory[i].adapter);
            if (revokedAt == addedAt) continue;
            assertEq(validAdapters[validAdapters.length - 1], addHistory[i].adapter);
            assertEq(validAdapters[validAdapters.length - 1], addHistory[i].adapter);
        }
    }
}
