// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";

/// @title AdapterRegistry
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Revokeable append-only registry for oracle adapters.
contract AdapterRegistry is Ownable {
    struct Entry {
        /// @notice The timestamp when the adapter was added.
        uint128 addedAt;
        /// @notice The timestamp when the adapter was revoked.
        uint128 revokedAt;
    }

    /// @notice List of adapters by their base and quote asset.
    /// @dev The keys are lexicographically sorted (asset0 < asset1)
    mapping(address asset0 => mapping(address asset1 => address[] adapters)) internal adapterMap;

    /// @notice Adapters configured by the registry.
    mapping(address adapter => Entry) public entries;

    /// @notice An adapter was added to the registry.
    /// @param adapter The address of the adapter.
    /// @param addedAt The timestamp when the adapter was added.
    event AdapterAdded(address indexed adapter, uint256 addedAt);
    /// @notice An adapter was revoked from the registry.
    /// @param adapter The address of the adapter.
    /// @param revokedAt The timestamp when the adapter was revoked.
    event AdapterRevoked(address indexed adapter, uint256 revokedAt);

    /// @notice The adapter cannot be added because it already exists in the registry.
    error Registry_AlreadyAdded();
    /// @notice The adapter cannot be revoked because it does not exist in the registry.
    error Registry_NotAdded();
    /// @notice The adapter cannot be revoked because it was already revoked from the registry.
    error Registry_AlreadyRevoked();

    /// @notice Deploy AdapterRegistry.
    /// @param _owner The address of the owner.
    constructor(address _owner) Ownable(_owner) {}

    /// @notice Adds an adapter to the registry.
    /// @param adapter The address of the adapter.
    /// @param base The adapter's base asset.
    /// @param quote The adapter's quote asset.
    /// @dev Only callable by the owner.
    function addAdapter(address adapter, address base, address quote) external onlyOwner {
        Entry storage entry = entries[adapter];
        if (entry.addedAt != 0) revert Registry_AlreadyAdded();
        entry.addedAt = uint128(block.timestamp);

        (address asset0, address asset1) = _sort(base, quote);
        adapterMap[asset0][asset1].push(adapter);
        
        emit AdapterAdded(adapter, block.timestamp);
    }

    /// @notice Revokes an adapter from the registry.
    /// @param adapter The address of the adapter.
    /// @dev Only callable by the owner.
    function revokeAdapter(address adapter) external onlyOwner {
        Entry storage entry = entries[adapter];
        if (entry.addedAt == 0) revert Registry_NotAdded();
        if (entry.revokedAt != 0) revert Registry_AlreadyRevoked();
        entry.revokedAt = uint128(block.timestamp);
        emit AdapterRevoked(adapter, block.timestamp);
    }

    /// @notice Returns whether an adapter was valid at a point in time.
    /// @param adapter The address of the adapter.
    /// @param snapshotTime The timestamp to check.
    /// @dev Returns false if:
    /// - adapter was never added,
    /// - adapter was added after the timestamp,
    /// - adapter was revoked before or at the timestamp.
    /// @return Whether `adapter` was valid at `snapshotTime`.
    function isValidAdapter(address adapter, uint256 snapshotTime) public view returns (bool) {
        uint256 addedAt = entries[adapter].addedAt;
        uint256 revokedAt = entries[adapter].revokedAt;

        if (addedAt == 0 || addedAt > snapshotTime) return false;
        if (revokedAt != 0 && revokedAt <= snapshotTime) return false;
        return true;
    }

    /// @notice Returns the all valid adapters for a given base and quote.
    /// @param base The address of the base asset.
    /// @param quote The address of the quote asset.
    /// @param snapshotTime The timestamp to check.
    /// @dev Order of base and quote does not matter.
    /// @return All adapters for base and quote valid at `snapshotTime`.
    function getValidAdapters(address base, address quote, uint256 snapshotTime) external view returns (address[] memory) {
        (address asset0, address asset1) = _sort(base, quote);
        address[] memory adapters = adapterMap[asset0][asset1];
        address[] memory validAdapters = new address[](adapters.length);

        uint256 numValidAdapters = 0;
        for (uint256 i = 0; i < adapters.length; ++i) {
            if (isValidAdapter(adapter, snapshotTime)) {
                validAdapters[numValidAdapters++] = adapter;
            }
        }

        /// @solidity memory-safe-assembly
        assembly {
            mstore(validAdapters, numValidAdapters)
        }
        return validAdapters;
    }

    /// @notice Lexicographically sort two addresses.
    /// @param assetA One of the assets in the pair.
    /// @param assetB The other asset in the pair.
    /// @return The address first in lexicographic order.
    /// @return The address second in lexicographic order.
    function _sort(address assetA, address assetB) internal pure returns (address, address) {
        return assetA < assetB ? (assetA, assetB) : (assetB, assetA);
    }
}
