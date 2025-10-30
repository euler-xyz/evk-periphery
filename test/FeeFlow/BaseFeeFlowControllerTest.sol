// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "evc/EthereumVaultConnector.sol";
import "./lib/MockToken.sol";
import "./lib/ReenteringMockToken.sol";
import "./lib/PredictAddress.sol";
import "./lib/OverflowableEpochIdFeeFlowController.sol";
import "../../src/FeeFlow/FeeFlowControllerEVK.sol";
import {MockOFTAdapter} from "../OFT/lib/MockOFTAdapter.sol";

contract BaseFeeFlowControllerTest is Test {
    uint256 public constant INIT_PRICE = 1e18;
    uint256 public constant MIN_INIT_PRICE = 1e6;
    uint256 public constant EPOCH_PERIOD = 14 days;
    uint256 public constant PRICE_MULTIPLIER = 2e18;
    uint32 public constant DST_EID = 123;

    address public paymentReceiver = makeAddr("paymentReceiver");
    address public buyer = makeAddr("buyer");
    address public assetsReceiver = makeAddr("assetsReceiver");

    MockToken paymentToken;
    MockToken token1;
    MockToken token2;
    MockToken token3;
    MockToken token4;
    MockToken[] public tokens;

    IEVC public evc;

    MockHookTarget public mockHookTarget;

    MockOFTAdapter mockOFTAdapter;

    function setUp() public virtual {
        // Deploy tokens
        paymentToken = new MockToken("Payment Token", "PAY");
        vm.label(address(paymentToken), "paymentToken");
        token1 = new MockToken("Token 1", "T1");
        vm.label(address(token1), "token1");
        tokens.push(token1);
        token2 = new MockToken("Token 2", "T2");
        vm.label(address(token2), "token2");
        tokens.push(token2);
        token3 = new MockToken("Token 3", "T3");
        vm.label(address(token3), "token3");
        tokens.push(token3);
        token4 = new MockToken("Token 4", "T4");
        vm.label(address(token4), "token4");
        tokens.push(token4);

        // Deploy EVC
        evc = new EthereumVaultConnector();

        // Deploy mock hook target
        mockHookTarget = new MockHookTarget();
        mockOFTAdapter = new MockOFTAdapter(address(paymentToken));

        // Mint payment tokens to buyer
        paymentToken.mint(buyer, 1000000e18);
    }

    // Helper functions -----------------------------------------------------
    function mintTokensToBatchBuyer(address feeFlowController) public {
        for (uint256 i = 0; i < tokens.length; i++) {
            tokens[i].mint(feeFlowController, 1000000e18 * (i + 1));
        }
    }

    function mintAmounts() public view returns (uint256[] memory amounts) {
        amounts = new uint256[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            amounts[i] = 1000000e18 * (i + 1);
        }
        return amounts;
    }

    function assetsAddresses() public view returns (address[] memory addresses) {
        addresses = new address[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            addresses[i] = address(tokens[i]);
        }
        return addresses;
    }

    function assetsBalances(address who) public view returns (uint256[] memory result) {
        result = new uint256[](tokens.length);

        for (uint256 i = 0; i < tokens.length; i++) {
            result[i] = tokens[i].balanceOf(who);
        }

        return result;
    }

    function assertMintBalances(address who) public view {
        uint256[] memory mintAmounts_ = mintAmounts();
        uint256[] memory balances = assetsBalances(who);

        for (uint256 i = 0; i < tokens.length; i++) {
            assertEq(balances[i], mintAmounts_[i]);
        }
    }

    function assert0Balances(address who) public view {
        for (uint256 i = 0; i < tokens.length; i++) {
            uint256 balance = tokens[i].balanceOf(who);
            assertEq(balance, 0);
        }
    }
}

contract MockHookTarget {
    function mockHookTargetCallback() external {}
}
