// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable, Context} from "openzeppelin-contracts/access/Ownable.sol";
import {EnumerableSet} from "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import {IEVC} from "ethereum-vault-connector/interfaces/IEthereumVaultConnector.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {BaseHookTarget} from "./BaseHookTarget.sol";
import {TermsOfUseSigner} from "../TermsOfUseSigner/TermsOfUseSigner.sol";

/// @title HookTargetTermsOfUse
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Hook target contract that allows interaction only when user signed terms of use. Bypassed accounts are
/// exempt from the terms of use check.
contract HookTargetTermsOfUse is BaseHookTarget, EVCUtil, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The address of the TermsOfUseSigner contract.
    address public immutable termsOfUseContract;

    /// @notice The hash of the terms of use that must be signed.
    bytes32 public termsOfUseHash;

    /// @notice Set of addresses that are exempt from the terms of use check.
    EnumerableSet.AddressSet internal bypassList;

    /// @notice Emitted when the terms of use hash is updated.
    /// @param termsOfUseHash The new terms of use hash.
    event SetTermsOfUseHash(bytes32 termsOfUseHash);

    /// @notice Emitted when an address is added to the bypass list.
    /// @param account The address added to the bypass list.
    event BypassListAdded(address indexed account);

    /// @notice Emitted when an address is removed from the bypass list.
    /// @param account The address removed from the bypass list.
    event BypassListRemoved(address indexed account);

    /// @notice Error thrown when the user has not signed the terms of use.
    error TermsOfUseNotSigned();

    /// @notice Initializes the HookTargetTermsOfUseGuard contract.
    /// @param _evc The address of the EVC.
    /// @param _owner The address of the contract owner.
    /// @param _eVaultFactory The address of the EVault factory.
    /// @param _termsOfUseContract The address of the TermsOfUseSigner contract.
    /// @param _termsOfUseHash The initial terms of use hash.
    constructor(address _evc, address _owner, address _eVaultFactory, address _termsOfUseContract, bytes32 _termsOfUseHash)
        BaseHookTarget(_eVaultFactory)
        Ownable(_owner)
        EVCUtil(_evc)
    {
        termsOfUseContract = _termsOfUseContract;
        termsOfUseHash = _termsOfUseHash;

        emit SetTermsOfUseHash(_termsOfUseHash);
    }

    /// @notice Sets a new terms of use hash.
    /// @param _termsOfUseHash The new terms of use hash.
    function setTermsOfUseHash(bytes32 _termsOfUseHash) external onlyOwner {
        termsOfUseHash = _termsOfUseHash;
        emit SetTermsOfUseHash(_termsOfUseHash);
    }

    /// @notice Adds an address to the bypass list.
    /// @param account The address to add.
    function addBypass(address account) external onlyOwner {
        if (bypassList.add(account)) {
            emit BypassListAdded(account);
        }
    }

    /// @notice Removes an address from the bypass list.
    /// @param account The address to remove.
    function removeBypass(address account) external onlyOwner {
        if (bypassList.remove(account)) {
            emit BypassListRemoved(account);
        }
    }

    /// @notice Returns the number of addresses in the bypass list.
    /// @return The number of bypassed addresses.
    function bypassListLength() external view returns (uint256) {
        return bypassList.length();
    }

    /// @notice Returns the address at a given index in the bypass list.
    /// @param index The index to query.
    /// @return The address at the given index.
    function bypassListAt(uint256 index) external view returns (address) {
        return bypassList.at(index);
    }

    /// @notice Returns all addresses in the bypass list.
    /// @return The array of bypassed addresses.
    function bypassListValues() external view returns (address[] memory) {
        return bypassList.values();
    }

    /// @notice Fallback function to revert if the address has not accepted the terms of use.
    fallback() external {
        _checkTermsOfUse();
    }

    /// @notice Checks whether the sender's EVC owner has signed the terms of use or is on the bypass list.
    function _checkTermsOfUse() internal view {
        address senderOwner = evc.getAccountOwner(_msgSender());

        if (bypassList.contains(senderOwner)) return;

        uint256 signatureTimestamp =
            TermsOfUseSigner(termsOfUseContract).lastTermsOfUseSignatureTimestamp(senderOwner, termsOfUseHash);

        if (signatureTimestamp == 0) revert TermsOfUseNotSigned();
    }

    /// @notice Retrieves the effective sender. Account calling the hooked vault, or direct caller,
    /// possibly authenticated through EVC (for owner functions) 
    /// @return The address of the message sender.
    function _msgSender() internal view override(BaseHookTarget, Context, EVCUtil) returns (address) {
        address msgSender = BaseHookTarget._msgSender();
        return msg.sender == msgSender ? EVCUtil._msgSender() : msgSender;
    }
}
