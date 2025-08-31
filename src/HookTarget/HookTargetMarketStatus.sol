// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {DataStreamsVerifier} from "../Chainlink/DatastreamsVerifier.sol";
import {IHookTarget} from "evk/interfaces/IHookTarget.sol";

/// @title HookTargetMarketStatus
/// @notice Contract for verifying V8 reports and managing market status
contract HookTargetMarketStatus is DataStreamsVerifier, IHookTarget {
    /// @notice Thrown when the liquidator is not authorized
    error NotAuthorized();

    /// @notice Thrown when the feed ID in the report doesn't match the contract's feed ID
    error FeedIdMismatch();

    /// @notice Thrown when the price data is invalid (e.g., expired or not yet valid)
    error PriceDataInvalid();

    /// @notice Thrown when the market status is invalid
    error MarketStatusInvalid();

    /// @notice Thrown when the market is paused and operations are not allowed
    error MarketPaused();

    /// @notice Emitted when the market status is updated
    /// @param marketStatus The new market status value
    /// @param lastUpdatedTimestamp The timestamp of the last update
    event MarketStatusUpdated(uint256 indexed marketStatus, uint256 lastUpdatedTimestamp);

    /// @notice Market status value representing "open"
    uint32 public constant MARKET_STATUS_OPEN = 2;

    /// @notice The unique identifier for this price feed
    bytes32 public immutable FEED_ID;

    /// @notice Address authorized to call liquidate function
    address public immutable AUTHORIZED_LIQUIDATOR;

    /// @notice Current market status (0 = unknown, 1 = closed, 2 = open)
    uint32 public marketStatus;

    /// @notice Last updated timestamp
    uint64 public lastUpdatedTimestamp;

    /// @notice Initializes the contract with required parameters
    /// @param _authorizedLiquidator Address authorized to call liquidate function
    /// @param _authorizedUpdater Address authorized to call update function
    /// @param _verifierProxy Address of the verifier proxy contract
    /// @param _feedId Unique identifier for the price feed
    constructor(address _authorizedLiquidator, address _authorizedUpdater, address _verifierProxy, bytes32 _feedId)
        DataStreamsVerifier(_authorizedUpdater, _verifierProxy, 8)
    {
        FEED_ID = _feedId;
        AUTHORIZED_LIQUIDATOR = _authorizedLiquidator;
    }

    /// @notice Fallback function that only allows execution when market is open
    fallback() external {
        _verifyMarketStatus();
    }

    /// @notice Intercepts EVault liquidate operations to authenticate the caller (liquidator)
    function liquidate(address, address, uint256, uint256) external view {
        address msgSender;
        assembly {
            msgSender := shr(96, calldataload(sub(calldatasize(), 20)))
        }

        if (msgSender != AUTHORIZED_LIQUIDATOR && msgSender != owner()) revert NotAuthorized();

        _verifyMarketStatus();
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

    /// @notice Updates market status by verifying a V8 report and applying the result
    /// @param _rawReport Raw report data from Data Streams
    function update(bytes memory _rawReport) external override {
        bytes memory returnDataCall = _verify(_rawReport);

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

    /// @notice Sets the market status and emits an event if changed and timestamp is not stale
    /// @param _marketStatus The new market status to set
    /// @param _lastUpdatedTimestamp The timestamp from the report
    function _setMarketStatus(uint32 _marketStatus, uint64 _lastUpdatedTimestamp) internal {
        if (marketStatus != _marketStatus && lastUpdatedTimestamp < _lastUpdatedTimestamp) {
            marketStatus = _marketStatus;
            lastUpdatedTimestamp = _lastUpdatedTimestamp;
            emit MarketStatusUpdated(_marketStatus, _lastUpdatedTimestamp);
        } else {
            revert MarketStatusInvalid();
        }
    }

    /// @notice Verifies that the market is open
    function _verifyMarketStatus() internal view {
        if (marketStatus != MARKET_STATUS_OPEN) revert MarketPaused();
    }
}
