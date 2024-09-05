// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";

/// By accessing or using Euler's products and services, I agree to the
/// [Terms of Use](https://www.euler.finance/terms),
/// [Privacy Policy](https://www.euler.finance/privacy-policy), and
/// [Risk Disclosures](https://www.euler.finance/risk-disclosures).

/// @title TermsOfServiceSigner
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice A contract that allows users to sign the terms of service.
contract TermsOfServiceSigner is EVCUtil {
    /// @notice Mapping to store signed terms of service hashes for each account
    mapping(address => mapping(bytes32 => uint256)) public termsOfServiceSignedTimestamps;

    /// @notice Emitted when the terms of service is signed by an account
    /// @param account The address of the account that signed the terms of service
    /// @param termsOfServiceHash The hash of the terms of service that was signed
    /// @param timestamp The timestamp of the block when the terms of service was signed
    /// @param message Acknowledgement of the terms of service
    event TermsOfServiceSigned(
        address indexed account, bytes32 indexed termsOfServiceHash, uint256 timestamp, string message
    );

    /// @notice Error thrown when the provided terms of service hash does not match the expected hash
    /// @param actualTermsOfServiceHash The hash provided by the user
    /// @param expectedTermsOfServiceHash The hash calculated from the message
    error InvalidTermsOfServiceHash(bytes32 actualTermsOfServiceHash, bytes32 expectedTermsOfServiceHash);

    /// @notice Constructs the TermsOfServiceSigned contract
    /// @param _evc The address of the EVC contract
    constructor(address _evc) EVCUtil(_evc) {}

    /// @notice Allows an account owner to sign the terms of service
    /// @param termsOfServiceHash The hash of the terms of service to sign
    /// @param message The message to be signed
    function signTermsOfService(bytes32 termsOfServiceHash, string calldata message) external onlyEVCAccountOwner {
        bytes32 expectedTermsOfServiceHash = keccak256(abi.encodePacked(message));
        if (termsOfServiceHash != expectedTermsOfServiceHash) {
            revert InvalidTermsOfServiceHash(termsOfServiceHash, expectedTermsOfServiceHash);
        }

        address owner = _msgSender();
        if (termsOfServiceSignedTimestamps[owner][termsOfServiceHash] == 0) {
            termsOfServiceSignedTimestamps[owner][termsOfServiceHash] = block.timestamp;
            emit TermsOfServiceSigned(owner, termsOfServiceHash, block.timestamp, message);
        }
    }

    /// @notice Checks if the terms of service has been signed by a specific account
    /// @param account The address of the account to check
    /// @param termsOfServiceHash The hash of the terms of service to check
    /// @return bool True if the hash has been signed by the account, false otherwise
    function isTermsOfServiceSigned(address account, bytes32 termsOfServiceHash) external view returns (bool) {
        return termsOfServiceSignedTimestamps[account][termsOfServiceHash] != 0;
    }
}
