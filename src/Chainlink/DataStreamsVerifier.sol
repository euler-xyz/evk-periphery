// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Ownable} from "openzeppelin-contracts/access/Ownable.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Verifier Proxy Interface
/// @notice Interface for interacting with Chainlink's verifier proxy contract
interface IVerifierProxy {
    /// @notice Verifies a signed report on-chain
    /// @param payload The raw report data to verify
    /// @param parameterPayload Additional parameters for verification
    /// @return The decoded verification result
    function verify(bytes calldata payload, bytes calldata parameterPayload) external payable returns (bytes memory);

    /// @notice Returns the address of the fee manager contract
    /// @return The fee manager contract address
    function s_feeManager() external view returns (address);
}

/// @title Fee Manager Interface
/// @notice Interface for managing fees and rewards in the system
interface IFeeManager {
    /// @notice Returns the LINK token address
    /// @return The LINK token contract address
    function i_linkAddress() external view returns (address);

    /// @notice Returns the reward manager address
    /// @return The reward manager contract address
    function i_rewardManager() external view returns (address);
}

/// @title DataStreamsVerifier
/// @notice Abstract contract for verifying Chainlink Data Streams reports and managing authorization/fee logic
abstract contract DataStreamsVerifier is Ownable {
    using SafeERC20 for IERC20;

    /// @notice Thrown when an unauthorized address attempts to call update
    error UnauthorizedCaller();

    /// @notice Thrown when the report version doesn't match the expected version
    error InvalidPriceFeedVersion();

    /// @notice Address authorized to call update function
    address public immutable AUTHORIZED_CALLER;

    /// @notice Address of the VerifierProxy contract for report verification
    IVerifierProxy public immutable VERIFIER_PROXY;

    /// @notice Expected version of the report
    uint16 public immutable EXPECTED_VERSION;

    /// @notice Address of the FeeManager contract for fee management
    address public immutable FEE_MANAGER;

    /// @notice Cached LINK token address for fee management
    address public immutable LINK_TOKEN;

    /// @notice Initializes the contract with required parameters
    /// @param _authorizedCaller Address authorized to verify reports
    /// @param _verifierProxy Address of the verifier proxy contract
    /// @param _expectedVersion Expected version of the report
    constructor(address _authorizedCaller, address _verifierProxy, uint16 _expectedVersion) Ownable(msg.sender) {
        AUTHORIZED_CALLER = _authorizedCaller;
        VERIFIER_PROXY = IVerifierProxy(_verifierProxy);
        EXPECTED_VERSION = _expectedVersion;

        // Set up fee management if available
        address feeManager = VERIFIER_PROXY.s_feeManager();
        if (feeManager != address(0)) {
            FEE_MANAGER = feeManager;
            LINK_TOKEN = IFeeManager(feeManager).i_linkAddress();
            address rewardManager = IFeeManager(feeManager).i_rewardManager();
            IERC20(LINK_TOKEN).forceApprove(rewardManager, type(uint256).max);
        }
    }

    /// @notice Allows the owner to recover any ERC20 tokens sent to this contract
    /// @param _token The address of the token to recover
    /// @param _to The address to send the tokens to
    /// @param _amount The amount of tokens to recover
    function recoverToken(address _token, address _to, uint256 _amount) external onlyOwner {
        IERC20(_token).safeTransfer(_to, _amount);
    }

    /// @notice Updates state by verifying a Data Streams report
    /// @param _rawReport Raw report data from Data Streams
    function update(bytes memory _rawReport) external virtual;

    /// @notice Verifies a Chainlink Data Streams report, checks version and authorization, and returns the decoded
    /// result.
    /// @param _rawReport The raw report data from Data Streams.
    /// @return result The decoded verification result from the VerifierProxy.
    function _verify(bytes memory _rawReport) internal returns (bytes memory result) {
        // Check if caller is authorized
        if (_msgSender() != AUTHORIZED_CALLER) revert UnauthorizedCaller();

        // Decode the reportData from the request
        (, bytes memory reportData) = abi.decode(_rawReport, (bytes32[3], bytes));

        // Extract and validate report version
        uint16 reportVersion = (uint16(uint8(reportData[0])) << 8) | uint16(uint8(reportData[1]));
        if (reportVersion != EXPECTED_VERSION) revert InvalidPriceFeedVersion();

        // Verify the report on-chain using Chainlink's verifier
        return VERIFIER_PROXY.verify(_rawReport, FEE_MANAGER == address(0) ? bytes("") : abi.encode(LINK_TOKEN));
    }
}
