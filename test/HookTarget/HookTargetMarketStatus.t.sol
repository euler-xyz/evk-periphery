// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {Test, console} from "forge-std/Test.sol";
import {HookTargetMarketStatus} from "../../src/HookTarget/HookTargetMarketStatus.sol";
import {DataStreamsVerifier} from "../../src/Chainlink/DataStreamsVerifier.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {MockERC20Mintable} from "../../script/utils/MockERC20Mintable.sol";

/// @title Real Verifier Proxy Interface
/// @notice Interface for the actual Chainlink verifier proxy on mainnet
interface IVerifierProxy {
    function verify(bytes calldata payload, bytes calldata parameterPayload) external payable returns (bytes memory);
    function s_feeManager() external view returns (address);
}

/// @title Mock Fee Manager for testing
contract MockFeeManager {
    address public immutable i_linkAddress;
    address public immutable i_rewardManager;

    constructor(address _linkAddress, address _rewardManager) {
        i_linkAddress = _linkAddress;
        i_rewardManager = _rewardManager;
    }
}

contract HookTargetMarketStatusTest is Test {
    HookTargetMarketStatus public hookTarget;

    address public authorizedCaller = makeAddr("authorizedCaller");
    address public authorizedLiquidator = makeAddr("authorizedLiquidator");
    address public unauthorizedCaller = makeAddr("unauthorizedCaller");
    address public verifierProxy;
    uint256 public forkId;
    bytes32 public feedId;
    bytes public fullReport;

    uint32 public constant MARKET_STATUS_UNKNOWN = 0;
    uint32 public constant MARKET_STATUS_CLOSED = 1;
    uint32 public constant MARKET_STATUS_OPEN = 2;

    function setUp() public {
        forkId = vm.createSelectFork("https://sepolia.drpc.org", 9027340);
        verifierProxy = 0x4e9935be37302B9C97Ff4ae6868F1b566ade26d2;
        feedId = 0x0008b8ad9dc4061d1064033c3abc8a4e3f056e5b61d8533e8190eb96ef3b330b;
        fullReport =
            hex"00090d9e8d96765a0c49e03a6ae05c82e8f8de70cf179baa632f18313e54bd6900000000000000000000000000000000000000000000000000000000017bb160000000000000000000000000000000000000000000000000000000030000000100000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000000000000000000280000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001200008b8ad9dc4061d1064033c3abc8a4e3f056e5b61d8533e8190eb96ef3b330b0000000000000000000000000000000000000000000000000000000068a61c3f0000000000000000000000000000000000000000000000000000000068a61c3f000000000000000000000000000000000000000000000000000043baeb9411f3000000000000000000000000000000000000000000000000002c120032ecd8be0000000000000000000000000000000000000000000000000000000068cda93f000000000000000000000000000000000000000000000000185d8f0234afbb4000000000000000000000000000000000000000000000000c40ef6663854c00000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000274e2c23e2b06d8b046ca61c703d795292cb65bef37dd1fc2531178ab6295b67c2ece305fb66c24656f5b4a31e114a1b6e890b40b21055df4ff4f15bb49f192eb000000000000000000000000000000000000000000000000000000000000000264f15301dfe51cd05948018b169ae3e52586a3fd51fc2a86a6be1fe2192c616310728c33f7d7e2dd5e49342ca4a6be2b615c6f3ddc99ca0df29ed6e9a6d19e45";

        hookTarget = new HookTargetMarketStatus(authorizedLiquidator, authorizedCaller, verifierProxy, feedId);
    }

    function test_Constructor() public view {
        assertEq(hookTarget.AUTHORIZED_CALLER(), authorizedCaller);
        assertEq(hookTarget.AUTHORIZED_LIQUIDATOR(), authorizedLiquidator);
        assertEq(address(hookTarget.VERIFIER_PROXY()), verifierProxy);
        assertEq(hookTarget.EXPECTED_VERSION(), 8);
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
        emit HookTargetMarketStatus.MarketStatusUpdated(MARKET_STATUS_OPEN, 1755716669);
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
            new HookTargetMarketStatus(authorizedLiquidator, authorizedCaller, verifierProxy, wrongFeedId);

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

    function test_Fallback_MarketOpen() public {
        // Set market to open
        vm.prank(address(this));
        hookTarget.setMarketStatus(MARKET_STATUS_OPEN);

        // Try to call fallback function - should succeed when market is open
        (bool success,) = address(hookTarget).call("");
        assertTrue(success);
    }

    function test_Fallback_MarketNotOpen() public {
        // Market is unknown by default, so fallback should revert
        vm.expectRevert(HookTargetMarketStatus.MarketPaused.selector);
        (bool success,) = address(hookTarget).call("");
        assertTrue(success);
    }

    function test_Liquidate_AuthorizedLiquidator() public {
        // Set market to open
        vm.prank(address(this));
        hookTarget.setMarketStatus(MARKET_STATUS_OPEN);

        // Create calldata with the liquidate function call
        bytes memory liquidateCallData = abi.encodeWithSelector(
            hookTarget.liquidate.selector,
            address(0x1), // target
            address(0x2), // asset
            1000, // amount
            500 // maxIn
        );

        // Append the authorized liquidator address at the end
        bytes memory callDataWithSender = abi.encodePacked(liquidateCallData, authorizedLiquidator);

        // Call the function with the proper calldata structure
        (bool success,) = address(hookTarget).call(callDataWithSender);
        assertTrue(success);
    }

    function test_Liquidate_Owner() public {
        // Set market to open
        vm.prank(address(this));
        hookTarget.setMarketStatus(MARKET_STATUS_OPEN);

        // Create calldata with the liquidate function call
        bytes memory liquidateCallData = abi.encodeWithSelector(
            hookTarget.liquidate.selector,
            address(0x1), // target
            address(0x2), // asset
            1000, // amount
            500 // maxIn
        );

        // Append the owner address at the end
        bytes memory callDataWithSender = abi.encodePacked(liquidateCallData, address(this));

        // Call the function with the proper calldata structure
        (bool success,) = address(hookTarget).call(callDataWithSender);
        assertTrue(success);
    }

    function test_Liquidate_UnauthorizedCaller() public {
        // Set market to open
        vm.prank(address(this));
        hookTarget.setMarketStatus(MARKET_STATUS_OPEN);

        // Create calldata with the liquidate function call
        bytes memory liquidateCallData = abi.encodeWithSelector(
            hookTarget.liquidate.selector,
            address(0x1), // target
            address(0x2), // asset
            1000, // amount
            500 // maxIn
        );

        // Append an unauthorized caller address at the end
        bytes memory callDataWithSender = abi.encodePacked(liquidateCallData, unauthorizedCaller);

        // Call the function with the proper calldata structure - should revert
        vm.expectRevert(HookTargetMarketStatus.NotAuthorized.selector);
        (bool success,) = address(hookTarget).call(callDataWithSender);
        assertTrue(success);
    }

    function test_Liquidate_AuthorizedLiquidator_MarketClosed() public {
        // Set market to closed
        vm.prank(address(this));
        hookTarget.setMarketStatus(MARKET_STATUS_CLOSED);

        // Create calldata with the liquidate function call
        bytes memory liquidateCallData = abi.encodeWithSelector(
            hookTarget.liquidate.selector,
            address(0x1), // target
            address(0x2), // asset
            1000, // amount
            500 // maxIn
        );

        // Append the authorized liquidator address at the end
        bytes memory callDataWithSender = abi.encodePacked(liquidateCallData, authorizedLiquidator);

        // Call the function with the proper calldata structure - should revert due to market being closed
        vm.expectRevert(HookTargetMarketStatus.MarketPaused.selector);
        (bool success,) = address(hookTarget).call(callDataWithSender);
        assertTrue(success);
    }

    function test_Liquidate_Owner_MarketClosed() public {
        // Set market to closed
        vm.prank(address(this));
        hookTarget.setMarketStatus(MARKET_STATUS_CLOSED);

        // Create calldata with the liquidate function call
        bytes memory liquidateCallData = abi.encodeWithSelector(
            hookTarget.liquidate.selector,
            address(0x1), // target
            address(0x2), // asset
            1000, // amount
            500 // maxIn
        );

        // Append the owner address at the end
        bytes memory callDataWithSender = abi.encodePacked(liquidateCallData, address(this));

        // Call the function with the proper calldata structure - should revert due to market being closed
        vm.expectRevert(HookTargetMarketStatus.MarketPaused.selector);
        (bool success,) = address(hookTarget).call(callDataWithSender);
        assertTrue(success);
    }

    function test_Liquidate_AuthorizedLiquidator_MarketUnknown() public {
        // Market is unknown by default (status = 0)
        assertEq(hookTarget.marketStatus(), MARKET_STATUS_UNKNOWN);

        // Create calldata with the liquidate function call
        bytes memory liquidateCallData = abi.encodeWithSelector(
            hookTarget.liquidate.selector,
            address(0x1), // target
            address(0x2), // asset
            1000, // amount
            500 // maxIn
        );

        // Append the authorized liquidator address at the end
        bytes memory callDataWithSender = abi.encodePacked(liquidateCallData, authorizedLiquidator);

        // Call the function with the proper calldata structure - should revert due to market being unknown
        vm.expectRevert(HookTargetMarketStatus.MarketPaused.selector);
        (bool success,) = address(hookTarget).call(callDataWithSender);
        assertTrue(success);
    }

    function test_RecoverToken_OwnerOnly() public {
        // Test that non-owner cannot call recoverToken
        vm.prank(unauthorizedCaller);
        vm.expectRevert(); // Not owner
        hookTarget.recoverToken(address(0x1), unauthorizedCaller, 1000);
    }

    function test_RecoverToken_DifferentTokens() public {
        // Deploy multiple mock ERC20 tokens
        MockERC20Mintable token1 = new MockERC20Mintable(address(this), "Token1", "TK1", 18);
        MockERC20Mintable token2 = new MockERC20Mintable(address(this), "Token2", "TK2", 6);

        // Deploy a mock fee manager
        address mockRewardManager = makeAddr("mockRewardManager");
        MockFeeManager mockFeeManager = new MockFeeManager(address(token1), mockRewardManager);

        // Mock the s_feeManager call to return our mock fee manager
        vm.mockCall(
            verifierProxy,
            abi.encodeWithSelector(IVerifierProxy.s_feeManager.selector),
            abi.encode(address(mockFeeManager))
        );

        // Create a new hook target to test the constructor
        HookTargetMarketStatus newHookTarget =
            new HookTargetMarketStatus(authorizedLiquidator, authorizedCaller, verifierProxy, feedId);

        // Transfer some tokens to the contract
        uint256 amount1 = 1000e18;
        uint256 amount2 = 500e6;
        token1.mint(address(newHookTarget), amount1);
        token2.mint(address(newHookTarget), amount2);

        // Verify the contract has the tokens
        assertEq(token1.balanceOf(address(newHookTarget)), amount1);
        assertEq(token2.balanceOf(address(newHookTarget)), amount2);

        // Test recovering token1
        vm.prank(address(this)); // this contract is owner
        newHookTarget.recoverToken(address(token1), authorizedCaller, amount1);

        // Verify token1 was transferred
        assertEq(token1.balanceOf(authorizedCaller), amount1);
        assertEq(token1.balanceOf(address(newHookTarget)), 0);

        // Test recovering token2 to a different address
        address recipient2 = makeAddr("recipient2");
        vm.prank(address(this)); // this contract is owner
        newHookTarget.recoverToken(address(token2), recipient2, amount2);

        // Verify token2 was transferred
        assertEq(token2.balanceOf(recipient2), amount2);
        assertEq(token2.balanceOf(address(newHookTarget)), 0);
    }

    function test_LinkTokenAssignment() public {
        // Deploy a mock ERC20 token
        MockERC20Mintable linkToken = new MockERC20Mintable(address(this), "Chainlink", "LINK", 18);

        // Deploy a mock fee manager
        MockFeeManager mockFeeManager = new MockFeeManager(address(linkToken), makeAddr("mockRewardManager"));

        // Mock the s_feeManager call to return our mock fee manager
        vm.mockCall(
            verifierProxy,
            abi.encodeWithSelector(IVerifierProxy.s_feeManager.selector),
            abi.encode(address(mockFeeManager))
        );

        // Create a new hook target to test the constructor
        HookTargetMarketStatus newHookTarget =
            new HookTargetMarketStatus(authorizedLiquidator, authorizedCaller, verifierProxy, feedId);

        // Verify the LINK_TOKEN was assigned correctly
        assertEq(newHookTarget.LINK_TOKEN(), address(linkToken));
    }

    function test_LinkTokenApproval() public {
        // Deploy a mock ERC20 token
        MockERC20Mintable linkToken = new MockERC20Mintable(address(this), "Chainlink", "LINK", 18);

        // Deploy a mock fee manager
        address mockRewardManager = makeAddr("mockRewardManager");
        MockFeeManager mockFeeManager = new MockFeeManager(address(linkToken), mockRewardManager);

        // Mock the s_feeManager call to return our mock fee manager
        vm.mockCall(
            verifierProxy,
            abi.encodeWithSelector(IVerifierProxy.s_feeManager.selector),
            abi.encode(address(mockFeeManager))
        );

        // Create a new hook target to test the constructor
        HookTargetMarketStatus newHookTarget =
            new HookTargetMarketStatus(authorizedLiquidator, authorizedCaller, verifierProxy, feedId);

        // Verify the allowance was given to the reward manager
        uint256 allowance = linkToken.allowance(address(newHookTarget), mockRewardManager);
        assertEq(allowance, type(uint256).max);
    }

    function test_LinkTokenRecovery() public {
        // Deploy a mock ERC20 token
        MockERC20Mintable linkToken = new MockERC20Mintable(address(this), "Chainlink", "LINK", 18);

        // Deploy a mock fee manager
        address mockRewardManager = makeAddr("mockRewardManager");
        MockFeeManager mockFeeManager = new MockFeeManager(address(linkToken), mockRewardManager);

        // Mock the s_feeManager call to return our mock fee manager
        vm.mockCall(
            verifierProxy,
            abi.encodeWithSelector(IVerifierProxy.s_feeManager.selector),
            abi.encode(address(mockFeeManager))
        );

        // Create a new hook target to test the constructor
        HookTargetMarketStatus newHookTarget =
            new HookTargetMarketStatus(authorizedLiquidator, authorizedCaller, verifierProxy, feedId);

        // Transfer some tokens to the contract
        uint256 amount = 1000;
        linkToken.mint(address(newHookTarget), amount);

        // Verify the contract has the tokens
        assertEq(linkToken.balanceOf(address(newHookTarget)), amount);

        // Test the actual recovery
        vm.prank(address(this)); // this contract is owner
        newHookTarget.recoverToken(address(linkToken), authorizedCaller, amount);

        // Verify the tokens were transferred
        assertEq(linkToken.balanceOf(authorizedCaller), amount);
        assertEq(linkToken.balanceOf(address(newHookTarget)), 0);
    }

    function test_SetMarketStatus_SameStatus() public {
        // Set market to open first
        vm.prank(address(this));
        hookTarget.setMarketStatus(MARKET_STATUS_OPEN);

        vm.warp(block.timestamp + 1000);

        // Try to set the same status again - should revert
        vm.prank(address(this));
        vm.expectRevert(HookTargetMarketStatus.MarketStatusInvalid.selector);
        hookTarget.setMarketStatus(MARKET_STATUS_OPEN);
    }

    function test_SetMarketStatus_SameTimestamp() public {
        // Set market to open first
        vm.prank(address(this));
        hookTarget.setMarketStatus(MARKET_STATUS_OPEN);

        // Try to set the same status again - should revert
        vm.prank(address(this));
        vm.expectRevert(HookTargetMarketStatus.MarketStatusInvalid.selector);
        hookTarget.setMarketStatus(MARKET_STATUS_CLOSED);
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
