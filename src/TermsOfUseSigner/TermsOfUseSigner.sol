// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

/// By accessing or using Euler's products and services, I agree to the
/// - [Terms of Use](https://www.euler.finance/terms),
/// - [Privacy Policy](https://www.euler.finance/privacy-policy), and
/// - [Risk Disclosures](https://www.euler.finance/risk-disclosures).

/// @title TermsOfUseSigner
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that allows users to sign the terms of use.
contract TermsOfUseSigner is EVCUtil {
    /// @notice Mapping to store timestamp of last signature for each account and terms of use hash
    mapping(address => mapping(bytes32 => uint256)) internal termsOfUseLastSignatureTimestamps;

    /// @notice Emitted when the terms of use is signed by an account
    /// @param account The address of the account that signed the terms of use
    /// @param termsOfUseHash The hash of the terms of use that was signed
    /// @param timestamp The timestamp of the block when the terms of use was signed
    /// @param message Acknowledgement of the terms of use
    event TermsOfUseSigned(address indexed account, bytes32 indexed termsOfUseHash, uint256 timestamp, string message);

    /// @notice Error thrown when the provided terms of use hash does not match the expected hash
    /// @param actualTermsOfUseHash The hash provided by the user
    /// @param expectedTermsOfUseHash The hash calculated from the message
    error InvalidTermsOfUseHash(bytes32 actualTermsOfUseHash, bytes32 expectedTermsOfUseHash);

    /// @notice Constructs the TermsOfUseSigned contract
    /// @param _evc The address of the EVC contract
    constructor(address _evc) EVCUtil(_evc) {}

    /// @notice Allows an account owner to sign the terms of use
    /// @param termsOfUseMessage The terms of use message to be signed
    /// @param termsOfUseHash The hash of the terms of use to sign
    function signTermsOfUse(string calldata termsOfUseMessage, bytes32 termsOfUseHash) external onlyEVCAccountOwner {
        bytes32 expectedTermsOfUseHash = keccak256(abi.encodePacked(termsOfUseMessage));
        if (termsOfUseHash != expectedTermsOfUseHash) {
            revert InvalidTermsOfUseHash(termsOfUseHash, expectedTermsOfUseHash);
        }

        address owner = _msgSender();
        termsOfUseLastSignatureTimestamps[owner][termsOfUseHash] = block.timestamp;
        emit TermsOfUseSigned(owner, termsOfUseHash, block.timestamp, termsOfUseMessage);
    }

    /// @notice Checks the timestamp of the last signature for a given account and terms of use hash
    /// @param account The address of the account to check
    /// @param termsOfUseHash The hash of the terms of use to check
    /// @return The timestamp of the last signature for the given terms of use hash
    function lastTermsOfUseSignatureTimestamp(address account, bytes32 termsOfUseHash)
        external
        view
        returns (uint256)
    {
        return termsOfUseLastSignatureTimestamps[account][termsOfUseHash];
    }
}
