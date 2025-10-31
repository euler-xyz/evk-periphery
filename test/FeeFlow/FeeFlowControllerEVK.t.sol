// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "evc/EthereumVaultConnector.sol";
import "./lib/MockToken.sol";
import "./lib/ReenteringMockToken.sol";
import "./lib/PredictAddress.sol";
import "./lib/OverflowableEpochIdFeeFlowController.sol";
import "../../src/FeeFlow/FeeFlowControllerEVK.sol";
import "./BaseFeeFlowControllerTest.sol";

contract FeeFlowControllerEVKTest is BaseFeeFlowControllerTest {
    FeeFlowControllerEVK feeFlowController;

    function setUp() public virtual override {
        super.setUp();
        // Deploy FeeFlowControllerEVK
        feeFlowController = new FeeFlowControllerEVK(
            address(evc),
            INIT_PRICE,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE,
            address(0),
            0,
            address(mockHookTarget),
            MockHookTarget.mockHookTargetCallback.selector
        );
        // Approve payment token from buyer to FeeFlowControllerEVK
        vm.startPrank(buyer);
        paymentToken.approve(address(feeFlowController), type(uint256).max);
        vm.stopPrank();
    }

    function testConstructor() public view {
        FeeFlowControllerEVK.Slot0 memory slot0 = feeFlowController.getSlot0();
        assertEq(address(feeFlowController.EVC()), address(evc));
        assertEq(slot0.initPrice, uint128(INIT_PRICE));
        assertEq(slot0.startTime, block.timestamp);
        assertEq(address(feeFlowController.paymentToken()), address(paymentToken));
        assertEq(feeFlowController.paymentReceiver(), paymentReceiver);
        assertEq(feeFlowController.epochPeriod(), EPOCH_PERIOD);
        assertEq(feeFlowController.priceMultiplier(), PRICE_MULTIPLIER);
        assertEq(feeFlowController.minInitPrice(), MIN_INIT_PRICE);
    }

    function testConstructorInitPriceBelowMin() public {
        vm.expectRevert(FeeFlowControllerEVK.InitPriceBelowMin.selector);
        new FeeFlowControllerEVK(
            address(evc),
            MIN_INIT_PRICE - 1,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE,
            address(0),
            0,
            address(0),
            ""
        );
    }

    function testConstructorEpochPeriodBelowMin() public {
        uint256 minEpochPeriod = feeFlowController.MIN_EPOCH_PERIOD();
        vm.expectRevert(FeeFlowControllerEVK.EpochPeriodBelowMin.selector);
        new FeeFlowControllerEVK(
            address(evc),
            INIT_PRICE,
            address(paymentToken),
            paymentReceiver,
            minEpochPeriod - 1,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE,
            address(0),
            0,
            address(0),
            ""
        );
    }

    function testConstructorEpochPeriodExceedsMax() public {
        uint256 maxEpochPeriod = feeFlowController.MAX_EPOCH_PERIOD();
        vm.expectRevert(FeeFlowControllerEVK.EpochPeriodExceedsMax.selector);
        new FeeFlowControllerEVK(
            address(evc),
            INIT_PRICE,
            address(paymentToken),
            paymentReceiver,
            maxEpochPeriod + 1,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE,
            address(0),
            0,
            address(0),
            ""
        );
    }

    function testConstructorPriceMultiplierBelowMin() public {
        uint256 minPriceMultiplier = feeFlowController.MIN_PRICE_MULTIPLIER();
        vm.expectRevert(FeeFlowControllerEVK.PriceMultiplierBelowMin.selector);
        new FeeFlowControllerEVK(
            address(evc),
            INIT_PRICE,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            minPriceMultiplier - 1,
            MIN_INIT_PRICE,
            address(0),
            0,
            address(0),
            ""
        );
    }

    function testConstructorMinInitPriceBelowMin() public {
        uint256 absMinInitPrice = feeFlowController.ABS_MIN_INIT_PRICE();
        vm.expectRevert(FeeFlowControllerEVK.MinInitPriceBelowMin.selector);
        new FeeFlowControllerEVK(
            address(evc),
            INIT_PRICE,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            PRICE_MULTIPLIER,
            absMinInitPrice - 1,
            address(0),
            0,
            address(0),
            ""
        );
    }

    function testConstructorMinInitPriceExceedsABSMaxInitPrice() public {
        // Fails at init price check
        vm.expectRevert(FeeFlowControllerEVK.InitPriceExceedsMax.selector);
        new FeeFlowControllerEVK(
            address(evc),
            uint256(type(uint216).max) + 2,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            PRICE_MULTIPLIER,
            uint256(type(uint216).max) + 1,
            address(0),
            0,
            address(0),
            ""
        );
    }

    function testConstructorPaymentReceiverIsThis() public {
        address deployer = makeAddr("deployer");
        address expectedAddress = PredictAddress.calc(deployer, 0);

        vm.startPrank(deployer);
        vm.expectRevert(FeeFlowControllerEVK.PaymentReceiverIsThis.selector);
        new FeeFlowControllerEVK(
            address(evc),
            INIT_PRICE,
            address(paymentToken),
            expectedAddress,
            EPOCH_PERIOD,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE,
            address(0),
            0,
            address(0),
            ""
        );
        vm.stopPrank();
    }

    function testBuyStartOfAuction() public {
        mintTokensToBatchBuyer(address(feeFlowController));

        uint256 paymentReceiverBalanceBefore = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);

        uint256 expectedPrice = feeFlowController.getPrice();

        vm.startPrank(buyer);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();

        uint256 paymentReceiverBalanceAfter = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceAfter = paymentToken.balanceOf(buyer);
        FeeFlowControllerEVK.Slot0 memory slot0 = feeFlowController.getSlot0();

        // Assert token balances
        assert0Balances(address(feeFlowController));
        assertMintBalances(assetsReceiver);
        assertEq(expectedPrice, INIT_PRICE);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore + expectedPrice);
        assertEq(buyerBalanceAfter, buyerBalanceBefore - expectedPrice);

        // Assert new auctionState
        assertEq(slot0.epochId, uint8(1));
        assertEq(slot0.initPrice, uint128(INIT_PRICE * 2));
        assertEq(slot0.startTime, block.timestamp);
    }

    function testBuyEndOfAuction() public {
        mintTokensToBatchBuyer(address(feeFlowController));

        uint256 paymentReceiverBalanceBefore = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);

        // Skip to end of auction and then some
        skip(EPOCH_PERIOD + 1 days);
        uint256 expectedPrice = feeFlowController.getPrice();

        vm.startPrank(buyer);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();

        uint256 paymentReceiverBalanceAfter = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceAfter = paymentToken.balanceOf(buyer);
        FeeFlowControllerEVK.Slot0 memory slot0 = feeFlowController.getSlot0();

        // Assert token balances
        assert0Balances(address(feeFlowController));
        assertMintBalances(assetsReceiver);
        // Should have paid 0
        assertEq(expectedPrice, 0);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore);
        assertEq(buyerBalanceAfter, buyerBalanceBefore);

        // Assert new auctionState
        assertEq(slot0.epochId, uint8(1));
        assertEq(slot0.initPrice, MIN_INIT_PRICE);
        assertEq(slot0.startTime, block.timestamp);
    }

    function testBuyMiddleOfAuction() public {
        mintTokensToBatchBuyer(address(feeFlowController));

        uint256 paymentReceiverBalanceBefore = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceBefore = paymentToken.balanceOf(buyer);

        // Skip to middle of auction
        skip(EPOCH_PERIOD / 2);
        uint256 expectedPrice = feeFlowController.getPrice();

        vm.startPrank(buyer);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();

        uint256 paymentReceiverBalanceAfter = paymentToken.balanceOf(paymentReceiver);
        uint256 buyerBalanceAfter = paymentToken.balanceOf(buyer);
        FeeFlowControllerEVK.Slot0 memory slot0 = feeFlowController.getSlot0();

        // Assert token balances
        assert0Balances(address(feeFlowController));
        assertMintBalances(assetsReceiver);
        assertEq(expectedPrice, INIT_PRICE / 2);
        assertEq(paymentReceiverBalanceAfter, paymentReceiverBalanceBefore + expectedPrice);
        assertEq(buyerBalanceAfter, buyerBalanceBefore - expectedPrice);

        // Assert new auctionState
        assertEq(slot0.epochId, uint8(1));
        assertEq(slot0.initPrice, uint128(INIT_PRICE));
        assertEq(slot0.startTime, block.timestamp);
    }

    function testBuyDeadlinePassedShouldFail() public {
        mintTokensToBatchBuyer(address(feeFlowController));
        skip(365 days);

        vm.startPrank(buyer);
        vm.expectRevert(FeeFlowControllerEVK.DeadlinePassed.selector);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, 0, block.timestamp - 1 days, 1000000e18);
        vm.stopPrank();

        // Double check tokens haven't moved
        assertMintBalances(address(feeFlowController));
    }

    function testBuyEmptyAssetsShouldFail() public {
        mintTokensToBatchBuyer(address(feeFlowController));

        vm.startPrank(buyer);
        vm.expectRevert(FeeFlowControllerEVK.EmptyAssets.selector);
        feeFlowController.buy(new address[](0), assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();

        // Double check tokens haven't moved
        assertMintBalances(address(feeFlowController));
    }

    function testBuyWrongEpochShouldFail() public {
        mintTokensToBatchBuyer(address(feeFlowController));

        // Is actually at 0
        uint256 epochId = 1;

        vm.startPrank(buyer);
        vm.expectRevert(FeeFlowControllerEVK.EpochIdMismatch.selector);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, epochId, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();

        // Double check tokens haven't moved
        assertMintBalances(address(feeFlowController));
    }

    function testBuyPaymentAmountExceedsMax() public {
        mintTokensToBatchBuyer(address(feeFlowController));

        vm.startPrank(buyer);
        vm.expectRevert(FeeFlowControllerEVK.MaxPaymentTokenAmountExceeded.selector);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, 0, block.timestamp + 1 days, INIT_PRICE / 2);
        vm.stopPrank();

        // Double check tokens haven't moved
        assertMintBalances(address(feeFlowController));
    }

    function testBuyReenter() public {
        uint256 mintAmount = 1e18;

        // Setup reentering token
        ReenteringMockToken reenterToken = new ReenteringMockToken("ReenteringToken", "RET");
        reenterToken.mint(address(feeFlowController), mintAmount);
        reenterToken.setReenterTargetAndData(
            address(feeFlowController),
            abi.encodeWithSelector(
                feeFlowController.buy.selector, assetsAddresses(), assetsReceiver, block.timestamp + 1 days, 1000000e18
            )
        );

        address[] memory assets = new address[](1);
        assets[0] = address(reenterToken);

        vm.startPrank(buyer);
        // Token does not bubble up error so this is the expected error on reentry
        vm.expectRevert(FeeFlowControllerEVK.Reentrancy.selector);
        feeFlowController.buy(assets, assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();
    }

    function testBuyReenterGetPrice() public {
        uint256 mintAmount = 1e18;

        // Setup reentering token
        ReenteringMockToken reenterToken = new ReenteringMockToken("ReenteringToken", "RET");
        reenterToken.mint(address(feeFlowController), mintAmount);
        reenterToken.setReenterTargetAndData(
            address(feeFlowController), abi.encodeWithSelector(feeFlowController.getPrice.selector)
        );

        address[] memory assets = new address[](1);
        assets[0] = address(reenterToken);

        vm.startPrank(buyer);
        // Token does not bubble up error so this is the expected error on reentry
        vm.expectRevert(FeeFlowControllerEVK.Reentrancy.selector);
        feeFlowController.buy(assets, assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();
    }

    function testBuyReenterGetSlot0() public {
        uint256 mintAmount = 1e18;

        // Setup reentering token
        ReenteringMockToken reenterToken = new ReenteringMockToken("ReenteringToken", "RET");
        reenterToken.mint(address(feeFlowController), mintAmount);
        reenterToken.setReenterTargetAndData(
            address(feeFlowController), abi.encodeWithSelector(feeFlowController.getSlot0.selector)
        );

        address[] memory assets = new address[](1);
        assets[0] = address(reenterToken);

        vm.startPrank(buyer);
        // Token does not bubble up error so this is the expected error on reentry
        vm.expectRevert(FeeFlowControllerEVK.Reentrancy.selector);
        feeFlowController.buy(assets, assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();
    }

    function testBuyInitPriceExceedingABS_MAX_INIT_PRICE() public {
        uint256 absMaxInitPrice = feeFlowController.ABS_MAX_INIT_PRICE();

        // Deploy with auction at max init price
        FeeFlowControllerEVK tempFeeFlowController = new FeeFlowControllerEVK(
            address(evc),
            absMaxInitPrice,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            1.1e18,
            absMaxInitPrice,
            address(0),
            0,
            address(0),
            ""
        );

        // Mint payment tokens to buyer
        paymentToken.mint(buyer, type(uint216).max);

        vm.startPrank(buyer);
        // Approve payment token from buyer to FeeFlowControllerEVK
        paymentToken.approve(address(tempFeeFlowController), type(uint256).max);
        // Buy
        tempFeeFlowController.buy(assetsAddresses(), assetsReceiver, 0, block.timestamp + 1 days, type(uint216).max);
        vm.stopPrank();

        // Assert new init price
        FeeFlowControllerEVK.Slot0 memory slot0 = tempFeeFlowController.getSlot0();
        assertEq(slot0.initPrice, uint216(absMaxInitPrice));
    }

    function testBuyWrapAroundEpochId() public {
        // MINT a lot of tokens
        paymentToken.mint(buyer, type(uint256).max - paymentToken.balanceOf(buyer));

        OverflowableEpochIdFeeFlowController tempFeeFlowController = new OverflowableEpochIdFeeFlowController(
            address(evc),
            MIN_INIT_PRICE,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE,
            address(0),
            0,
            address(0),
            ""
        );
        tempFeeFlowController.setEpochId(type(uint16).max);

        vm.startPrank(buyer);
        paymentToken.approve(address(tempFeeFlowController), type(uint256).max);
        tempFeeFlowController.buy(
            assetsAddresses(), assetsReceiver, type(uint16).max, block.timestamp + 1 days, type(uint256).max
        );
        vm.stopPrank();

        FeeFlowControllerEVK.Slot0 memory slot0 = feeFlowController.getSlot0();
        assertEq(slot0.epochId, uint16(0));
    }

    function testBuyHookCalled() public {
        assertEq(feeFlowController.hookTarget(), address(mockHookTarget));
        mintTokensToBatchBuyer(address(feeFlowController));
        address[] memory addresses = assetsAddresses();
        vm.startPrank(buyer);
        vm.expectCall(address(mockHookTarget), abi.encodePacked(MockHookTarget.mockHookTargetCallback.selector));
        feeFlowController.buy(addresses, assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);
        vm.stopPrank();
    }

    // Testing for overflows in price calculations --------------------------------
    function testMAX_INIT_PRICEandMAX_EPOCH_PERIODdoNotOverflowPricing() public {
        uint256 absMaxInitPrice = feeFlowController.ABS_MAX_INIT_PRICE();
        uint256 maxEpochPeriod = feeFlowController.MAX_EPOCH_PERIOD();

        FeeFlowControllerEVK tempFeeFlowController = new FeeFlowControllerEVK(
            address(evc),
            absMaxInitPrice,
            address(paymentToken),
            paymentReceiver,
            maxEpochPeriod,
            1.1e18,
            absMaxInitPrice,
            address(0),
            0,
            address(0),
            ""
        );
        paymentToken.mint(buyer, absMaxInitPrice);

        skip(maxEpochPeriod);

        vm.startPrank(buyer);
        paymentToken.approve(address(tempFeeFlowController), type(uint256).max);

        // Since timePassed == epochPeriod, timePassed will be multiplied to epochPeriod.
        // Does this not overflow and return zero?
        assert(tempFeeFlowController.getPrice() == 0);
        vm.stopPrank();
    }

    function testMAX_INIT_PRICEandMAX_EPOCH_PERIODminusOneDoNotOverflowPricing() public {
        uint256 absMaxInitPrice = feeFlowController.ABS_MAX_INIT_PRICE();
        uint256 maxEpochPeriod = feeFlowController.MAX_EPOCH_PERIOD();

        FeeFlowControllerEVK tempFeeFlowController = new FeeFlowControllerEVK(
            address(evc),
            absMaxInitPrice,
            address(paymentToken),
            paymentReceiver,
            maxEpochPeriod,
            1.1e18,
            absMaxInitPrice,
            address(0),
            0,
            address(0),
            ""
        );
        paymentToken.mint(buyer, absMaxInitPrice);

        skip(maxEpochPeriod - 1);

        vm.startPrank(buyer);
        paymentToken.approve(address(tempFeeFlowController), type(uint256).max);

        // Since timePassed < epochPeriod, timePassed will be multiplied to epochPeriod.
        // Does this not overflow?
        tempFeeFlowController.getPrice();
        vm.stopPrank();
    }

    function testMAX_INIT_PRICEandMAX_PRICE_MULTIPLIERdoNotOverflowNextAuction() public {
        uint256 absMaxInitPrice = feeFlowController.ABS_MAX_INIT_PRICE();
        uint256 maxPriceMultiplier = feeFlowController.MAX_PRICE_MULTIPLIER();

        FeeFlowControllerEVK tempFeeFlowController = new FeeFlowControllerEVK(
            address(evc),
            absMaxInitPrice,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            maxPriceMultiplier,
            absMaxInitPrice,
            address(0),
            0,
            address(0),
            ""
        );
        paymentToken.mint(buyer, absMaxInitPrice);

        vm.startPrank(buyer);
        paymentToken.approve(address(tempFeeFlowController), type(uint256).max);

        // Purchase will initialize the next auction and increase the price by its multiplier. Doesn't it revert?
        assert(
            tempFeeFlowController.buy(assetsAddresses(), assetsReceiver, 0, block.timestamp + 1 days, type(uint216).max)
                == absMaxInitPrice
        );
        // Its next price should be capped to the maximum init price
        assert(tempFeeFlowController.getPrice() == absMaxInitPrice);
        vm.stopPrank();
    }

    function testOFTAdapterCalledWhenConfigured() public {
        feeFlowController = new FeeFlowControllerEVK(
            address(evc),
            INIT_PRICE,
            address(paymentToken),
            paymentReceiver,
            EPOCH_PERIOD,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE,
            address(mockOFTAdapter),
            DST_EID,
            address(mockHookTarget),
            MockHookTarget.mockHookTargetCallback.selector
        );
        // Approve payment token from buyer to FeeFlowControllerEVK
        vm.startPrank(buyer);
        paymentToken.approve(address(feeFlowController), type(uint256).max);
        vm.stopPrank();

        skip(EPOCH_PERIOD / 2);
        uint256 expectedPrice = feeFlowController.getPrice();
        uint256 snapshotId = vm.snapshot();
        vm.prank(buyer);
        feeFlowController.buy(assetsAddresses(), assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);

        // OFT adapter not called, no allowance
        assertEq(paymentToken.balanceOf(address(feeFlowController)), expectedPrice);
        assertTrue(!mockOFTAdapter.wasSendCalled());
        assertEq(paymentToken.allowance(address(feeFlowController), address(mockOFTAdapter)), 0);

        vm.revertTo(snapshotId);
        // after providing balance for LZ fees, adapter is called
        deal(buyer, 1 ether);
        vm.prank(buyer);
        payable(address(feeFlowController)).transfer(1 ether);

        SendParam memory expecParam = SendParam({
            dstEid: DST_EID,
            to: bytes32(uint256(uint160(paymentReceiver))),
            amountLD: expectedPrice,
            minAmountLD: 0,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        MessagingFee memory fee = mockOFTAdapter.quoteSend(expecParam, false);

        vm.prank(buyer);
        vm.expectCall(
            address(mockOFTAdapter), abi.encodeCall(MockOFTAdapter.send, (expecParam, fee, address(feeFlowController)))
        );
        feeFlowController.buy(assetsAddresses(), assetsReceiver, 0, block.timestamp + 1 days, 1000000e18);

        // adapter has allowance
        assertTrue(mockOFTAdapter.wasSendCalled());
        assertEq(paymentToken.allowance(address(feeFlowController), address(mockOFTAdapter)), expectedPrice);
    }
}
