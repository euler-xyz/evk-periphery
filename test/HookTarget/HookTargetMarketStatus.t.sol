// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {HookTargetMarketStatus} from "../../src/HookTarget/HookTargetMarketStatus.sol";
import {DataStreamsVerifier} from "../../src/Chainlink/DataStreamsVerifier.sol";

/// @title Real Verifier Proxy Interface
/// @notice Interface for the actual Chainlink verifier proxy on mainnet
interface IVerifierProxy {
    function verify(bytes calldata payload, bytes calldata parameterPayload) external payable returns (bytes memory);
    function s_feeManager() external view returns (address);
}

contract HookTargetMarketStatusTest is Test {
    HookTargetMarketStatus public hookTarget;

    address public authorizedCaller = makeAddr("authorizedCaller");
    address public unauthorizedCaller = makeAddr("unauthorizedCaller");
    address public verifierProxy;
    uint256 public forkId;
    bytes32 public feedId;
    bytes public fullReport;

    uint32 public constant MARKET_STATUS_CLOSED = 0;
    uint32 public constant MARKET_STATUS_OPEN = 1;
    uint32 public constant MARKET_STATUS_PAUSED = 2;

    function setUp() public {
        forkId = vm.createSelectFork("https://sepolia.drpc.org", 9027340);
        verifierProxy = 0x4e9935be37302B9C97Ff4ae6868F1b566ade26d2;
        feedId = 0x0008b8ad9dc4061d1064033c3abc8a4e3f056e5b61d8533e8190eb96ef3b330b;
        fullReport =
            hex"00090d9e8d96765a0c49e03a6ae05c82e8f8de70cf179baa632f18313e54bd6900000000000000000000000000000000000000000000000000000000017bb160000000000000000000000000000000000000000000000000000000030000000100000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000280000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001200008b8ad9dc4061d1064033c3abc8a4e3f056e5b61d8533e8190eb96ef3b330b0000000000000000000000000000000000000000000000000000000068a61c3f0000000000000000000000000000000000000000000000000000000068a61c3f000000000000000000000000000000000000000000000000000043baeb9411f3000000000000000000000000000000000000000000000000002c120032ecd8be0000000000000000000000000000000000000000000000000000000068cda93f000000000000000000000000000000000000000000000000185d8f0234afbb4000000000000000000000000000000000000000000000000c40ef6663854c00000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000274e2c23e2b06d8b046ca61c703d795292cb65bef37dd1fc2531178ab6295b67c2ece305fb66c24656f5b4a31e114a1b6e890b40b21055df4ff4f15bb49f192eb000000000000000000000000000000000000000000000000000000000000000264f15301dfe51cd05948018b169ae3e52586a3fd51fc2a86a6be1fe2192c616310728c33f7d7e2dd5e49342ca4a6be2b615c6f3ddc99ca0df29ed6e9a6d19e45";

        hookTarget = new HookTargetMarketStatus(authorizedCaller, payable(verifierProxy), feedId);
    }

    function test_Constructor() public view {
        assertEq(hookTarget.AUTHORIZED_CALLER(), authorizedCaller);
        assertEq(address(hookTarget.VERIFIER_PROXY()), verifierProxy);
        assertEq(hookTarget.FEED_ID(), feedId);
        assertEq(hookTarget.marketStatus(), 0);
        assertEq(hookTarget.lastUpdatedTimestamp(), 0);
    }

    function test_IsHookTarget() public view {
        assertEq(hookTarget.isHookTarget(), hookTarget.isHookTarget.selector);
    }

    function test_SetMarketStatus_OwnerOnly() public {
        vm.startPrank(authorizedCaller);
        vm.expectRevert(); // Not owner
        hookTarget.setMarketStatus(MARKET_STATUS_OPEN);
        vm.stopPrank();

        vm.prank(address(this)); // this contract is owner
        hookTarget.setMarketStatus(MARKET_STATUS_OPEN);
        assertEq(hookTarget.marketStatus(), MARKET_STATUS_OPEN);
    }

    function test_Update_UnauthorizedCaller() public {
        vm.prank(unauthorizedCaller);
        vm.expectRevert(DataStreamsVerifier.UnauthorizedCaller.selector);
        hookTarget.update("");
    }

    function test_Update_WithRealReport() public {
        // Store initial state
        uint32 initialMarketStatus = hookTarget.marketStatus();
        uint64 initialTimestamp = hookTarget.lastUpdatedTimestamp();

        // Call update with the real report and expect the event
        vm.prank(authorizedCaller);
        vm.expectEmit(true, false, false, true);
        emit HookTargetMarketStatus.MarketStatusUpdated(MARKET_STATUS_PAUSED, 1755716669381000000);
        hookTarget.update(fullReport);

        // Check if the market status was updated
        uint32 newMarketStatus = hookTarget.marketStatus();
        uint64 newTimestamp = hookTarget.lastUpdatedTimestamp();

        // Verify that both market status and timestamp were updated
        assertTrue(newMarketStatus != initialMarketStatus, "Market status should have been updated");
        assertTrue(newTimestamp != initialTimestamp, "Timestamp should have been updated");
    }

    function test_Update_FeedIdMismatch() public {
        // Create a hook target with a different feed ID than what we'll send
        bytes32 wrongFeedId = keccak256("wrong-feed-id");
        HookTargetMarketStatus wrongFeedHook =
            new HookTargetMarketStatus(authorizedCaller, payable(verifierProxy), wrongFeedId);

        // Use the real report data - this should fail at the feed ID check
        // since the report contains the correct feed ID but the contract expects a different one
        vm.prank(authorizedCaller);
        vm.expectRevert(HookTargetMarketStatus.FeedIdMismatch.selector);
        wrongFeedHook.update(fullReport);
    }

    function test_Update_InvalidVersion() public {
        bytes memory invalidVersionRequest = _createMockVerifyRequestWithVersion(7); // V7 instead of V8

        vm.prank(authorizedCaller);
        vm.expectRevert(DataStreamsVerifier.InvalidPriceFeedVersion.selector);
        hookTarget.update(invalidVersionRequest);
    }

    function test_Fallback_MarketPaused() public {
        // Set market to paused
        vm.prank(address(this));
        hookTarget.setMarketStatus(MARKET_STATUS_PAUSED);

        // Try to call fallback function
        (bool success,) = address(hookTarget).call("");
        assertTrue(success);
    }

    function test_Fallback_MarketNotPaused() public {
        // Market is closed by default, so fallback should revert
        vm.expectRevert(HookTargetMarketStatus.MarketPaused.selector);
        (bool success,) = address(hookTarget).call("");
        assertTrue(success);
    }

    // ============ Helper Functions ============

    function _createMockVerifyRequestWithVersion(uint16 version) internal pure returns (bytes memory) {
        // Create a mock request with a specific version for testing version validation
        bytes32[3] memory reportContext = [bytes32(0), bytes32(0), bytes32(0)];
        bytes memory reportData = abi.encodePacked(
            version,
            bytes30(0) // padding
        );

        return abi.encode(reportContext, reportData);
    }
}
