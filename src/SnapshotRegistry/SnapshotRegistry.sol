// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Context} from "openzeppelin-contracts/utils/Context.sol";
import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

/// @title SnapshotRegistry
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Revokeable append-only registry of addresses.
contract SnapshotRegistry is EVCUtil, Ownable {
    struct Entry {
        /// @notice The timestamp when the address was added.
        uint128 addedAt;
        /// @notice The timestamp when the address was revoked.
        uint128 revokedAt;
    }

    /// @notice List of addresses by their base and quote asset.
    /// @dev The keys are lexicographically sorted (asset0 < asset1).
    mapping(address asset0 => mapping(address asset1 => address[])) internal map;

    /// @notice Addresses added to the registry.
    mapping(address => Entry) public entries;

    /// @notice An address was added to the registry.
    /// @param element The address added.
    /// @param asset0 The smaller address out of (base, quote).
    /// @param asset1 The larger address out of (base, quote).
    /// @param addedAt The timestamp when the address was added.
    event Added(address indexed element, address indexed asset0, address indexed asset1, uint256 addedAt);
    /// @notice An address was revoked from the registry.
    /// @param element The address revoked.
    /// @param revokedAt The timestamp when the address was revoked.
    event Revoked(address indexed element, uint256 revokedAt);

    /// @notice The address cannot be added because it already exists in the registry.
    error Registry_AlreadyAdded();
    /// @notice The address cannot be revoked because it does not exist in the registry.
    error Registry_NotAdded();
    /// @notice The address cannot be revoked because it was already revoked from the registry.
    error Registry_AlreadyRevoked();

    /// @notice Deploy SnapshotRegistry.
    /// @param _evc The address of the EVC.
    /// @param _owner The address of the owner.
    constructor(address _evc, address _owner) EVCUtil(_evc) Ownable(_owner) {}

    /// @notice Adds an address to the registry.
    /// @param element The address to add.
    /// @param base The corresponding base asset.
    /// @param quote The corresponding quote asset.
    /// @dev Only callable by the owner.
    function add(address element, address base, address quote) external onlyEVCAccountOwner onlyOwner {
        Entry storage entry = entries[element];
        if (entry.addedAt != 0) revert Registry_AlreadyAdded();
        entry.addedAt = uint128(block.timestamp);

        (address asset0, address asset1) = _sort(base, quote);
        map[asset0][asset1].push(element);

        emit Added(element, asset0, asset1, block.timestamp);
    }

    /// @notice Revokes an address from the registry.
    /// @param element The address to revoke.
    /// @dev Only callable by the owner.
    function revoke(address element) external onlyEVCAccountOwner onlyOwner {
        Entry storage entry = entries[element];
        if (entry.addedAt == 0) revert Registry_NotAdded();
        if (entry.revokedAt != 0) revert Registry_AlreadyRevoked();
        entry.revokedAt = uint128(block.timestamp);
        emit Revoked(element, block.timestamp);
    }

    /// @notice Returns the all valid addresses for a given base and quote.
    /// @param base The address of the base asset.
    /// @param quote The address of the quote asset.
    /// @param snapshotTime The timestamp to check.
    /// @dev Order of base and quote does not matter.
    /// @return All addresses for base and quote valid at `snapshotTime`.
    function getValidAddresses(address base, address quote, uint256 snapshotTime)
        external
        view
        returns (address[] memory)
    {
        (address asset0, address asset1) = _sort(base, quote);
        address[] memory elements = map[asset0][asset1];
        address[] memory validElements = new address[](elements.length);

        uint256 numValid = 0;
        for (uint256 i = 0; i < elements.length; ++i) {
            address element = elements[i];
            if (isValid(element, snapshotTime)) {
                validElements[numValid++] = element;
            }
        }

        /// @solidity memory-safe-assembly
        assembly {
            // update the length
            mstore(validElements, numValid)
        }
        return validElements;
    }

    /// @notice Returns whether an address was valid at a point in time.
    /// @param element The address to check.
    /// @param snapshotTime The timestamp to check.
    /// @dev Returns false if:
    /// - address was never added,
    /// - address was added after the timestamp,
    /// - address was revoked before or at the timestamp.
    /// @return Whether `element` was valid at `snapshotTime`.
    function isValid(address element, uint256 snapshotTime) public view returns (bool) {
        uint256 addedAt = entries[element].addedAt;
        uint256 revokedAt = entries[element].revokedAt;

        if (addedAt == 0 || addedAt > snapshotTime) return false;
        if (revokedAt != 0 && revokedAt <= snapshotTime) return false;
        return true;
    }

    /// @notice Lexicographically sort two addresses.
    /// @param assetA One of the assets in the pair.
    /// @param assetB The other asset in the pair.
    /// @return The address first in lexicographic order.
    /// @return The address second in lexicographic order.
    function _sort(address assetA, address assetB) internal pure returns (address, address) {
        return assetA < assetB ? (assetA, assetB) : (assetB, assetA);
    }

    /// @dev Leaves the contract without owner. It will not be possible to call `onlyOwner` functions. Can only be
    /// called by the current owner.
    /// NOTE: Renouncing ownership will leave the contract without an owner, thereby disabling any functionality that is
    /// only available to the owner.
    function renounceOwnership() public virtual override onlyEVCAccountOwner {
        super.renounceOwnership();
    }

    /// @dev Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.
    function transferOwnership(address newOwner) public virtual override onlyEVCAccountOwner {
        super.transferOwnership(newOwner);
    }

    /// @notice Retrieves the message sender in the context of the EVC.
    /// @dev This function returns the account on behalf of which the current operation is being performed, which is
    /// either msg.sender or the account authenticated by the EVC.
    /// @return The address of the message sender.
    function _msgSender() internal view override (Context, EVCUtil) returns (address) {
        return EVCUtil._msgSender();
    }
}
