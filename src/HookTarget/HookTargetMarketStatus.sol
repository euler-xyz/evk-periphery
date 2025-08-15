// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/extensions/ERC20Wrapper.sol";
import {Ownable, Context} from "openzeppelin-contracts/access/Ownable.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";

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

/// @title HookTargetMarketStatus
/// @notice Contract for verifying V8 reports and managing market status
contract HookTargetMarketStatus is Ownable, IHookTarget {
    using SafeERC20 for IERC20;

    /// @notice Thrown when an unauthorized address attempts to call updateMarketStatus
    error UnauthorizedCaller();

    /// @notice Thrown when the feed ID in the report doesn't match the contract's feed ID
    error FeedIdMismatch();

    /// @notice Thrown when the price data is invalid (e.g., expired or not yet valid)
    error PriceDataInvalid();

    /// @notice Thrown when the report version doesn't match the expected V8 version
    error InvalidPriceFeedVersion();

    /// @notice Thrown when the market is paused and operations are not allowed
    error MarketPaused();

    /// @notice Emitted when the market status is updated
    /// @param marketStatus The new market status value
    /// @param lastUpdatedTimestamp The timestamp of the last update
    event MarketStatusUpdated(uint256 indexed marketStatus, uint256 lastUpdatedTimestamp);

    /// @notice Expected version of the report (V8 = 8)
    uint16 public constant EXPECTED_VERSION = 8;

    /// @notice Market status when the market is paused
    uint32 public constant MARKET_STATUS_PAUSED = 2;

    /// @notice Address authorized to call updateMarketStatus function
    address public immutable AUTHORIZED_CALLER;

    /// @notice Address of the VerifierProxy contract for report verification
    IVerifierProxy public immutable VERIFIER_PROXY;

    /// @notice The unique identifier for this price feed
    bytes32 public immutable FEED_ID;

    /// @notice Cached LINK token address for fee management
    address public immutable LINK_TOKEN;

    /// @notice Current market status (0 = closed, 1 = open, 2 = paused)
    uint32 public marketStatus;

    /// @notice Last updated timestamp
    uint64 public lastUpdatedTimestamp;

    /// @notice Initializes the contract with required parameters
    /// @param _authorizedCaller Address authorized to call updateMarketStatus function
    /// @param _verifierProxy Address of the verifier proxy contract
    /// @param _feedId Unique identifier for the price feed
    constructor(address _authorizedCaller, address payable _verifierProxy, bytes32 _feedId) Ownable(msg.sender) {
        AUTHORIZED_CALLER = _authorizedCaller;
        VERIFIER_PROXY = IVerifierProxy(_verifierProxy);
        FEED_ID = _feedId;

        // Set up fee management if available
        address feeManager = VERIFIER_PROXY.s_feeManager();
        if (feeManager != address(0)) {
            LINK_TOKEN = IFeeManager(feeManager).i_linkAddress();
            address rewardManager = IFeeManager(feeManager).i_rewardManager();
            IERC20(LINK_TOKEN).forceApprove(rewardManager, type(uint256).max);
        }
    }

    /// @notice Fallback function that only allows execution when market is not paused
    fallback() external {
        if (marketStatus != MARKET_STATUS_PAUSED) revert MarketPaused();
    }

    /// @notice Checks if this contract is a valid hook target.
    /// @return The selector for the isHookTarget function.
    function isHookTarget() external pure override returns (bytes4) {
        return this.isHookTarget.selector;
    }

    /// @notice Sets the market status (owner only)
    /// @param _marketStatus The new market status to set
    function setMarketStatus(uint32 _marketStatus) external onlyOwner {
        _setMarketStatus(_marketStatus, uint64(block.timestamp));
    }

    /// @notice Updates market status by verifying a V8 report
    /// @param _rawReport Raw report data from Data Streams
    function updateMarketStatus(bytes memory _rawReport) external {
        // Check if caller is authorized
        if (_msgSender() != AUTHORIZED_CALLER) revert UnauthorizedCaller();

        // Decode the reportData from the request
        (, bytes memory reportData) = abi.decode(_rawReport, (bytes32[3], bytes));

        // Extract and validate report version
        uint16 reportVersion = (uint16(uint8(reportData[0])) << 8) | uint16(uint8(reportData[1]));
        if (reportVersion != EXPECTED_VERSION) revert InvalidPriceFeedVersion();

        // Verify the report on-chain using Chainlink's verifier
        bytes memory returnDataCall =
            VERIFIER_PROXY.verify{value: 0}(_rawReport, LINK_TOKEN == address(0) ? bytes("") : abi.encode(LINK_TOKEN));

        // Decode the V8 return data structure
        (
            bytes32 _feedId,
            uint32 _validFromTimestamp,
            ,
            ,
            ,
            uint32 _expiresAt,
            uint64 _lastUpdatedTimestamp,
            ,
            uint32 _marketStatus
        ) = abi.decode(returnDataCall, (bytes32, uint32, uint32, uint192, uint192, uint32, uint64, int192, uint32));

        // Verify that the feed ID matches the contract's feed ID
        if (_feedId != FEED_ID) revert FeedIdMismatch();

        // Validate the expiration times
        if (block.timestamp < _validFromTimestamp || block.timestamp > _expiresAt) {
            revert PriceDataInvalid();
        }

        // Update market status
        _setMarketStatus(_marketStatus, _lastUpdatedTimestamp);
    }

    /// @notice Sets the market status and emits an event if changed
    /// @param _marketStatus The new market status to set
    function _setMarketStatus(uint32 _marketStatus, uint64 _lastUpdatedTimestamp) internal {
        if (marketStatus != _marketStatus && lastUpdatedTimestamp <= _lastUpdatedTimestamp) {
            marketStatus = _marketStatus;
            lastUpdatedTimestamp = _lastUpdatedTimestamp;
            emit MarketStatusUpdated(_marketStatus, _lastUpdatedTimestamp);
        }
    }
}
