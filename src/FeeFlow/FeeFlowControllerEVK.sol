// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.24;

import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IOFT, SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppSender.sol";
import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {IEVault} from "evk/EVault/IEVault.sol";

/// @title FeeFlowControllerEVK
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://eulerlabs.com)
/// @notice Continuous back to back dutch auctions selling any asset received by this contract. The EVK version
/// introduces:
/// - optional bridging of the payment token to a remote chain using a LayerZero OFT adapter
/// - convertFees() call iteration over the provided assets array to avoid 10 vault status checks limit of the EVC if
/// called outside of the EVC checks-deferred context
/// - additional call imposed upon the buyer. This way, the protocol can automate certain periodic operations that would
/// otherwise require manual intervention
/// IMPORTANT: the payment token must not be the share token of the EVK vault
contract FeeFlowControllerEVK is EVCUtil {
    using SafeERC20 for IERC20;

    uint256 public constant MIN_EPOCH_PERIOD = 1 hours;
    uint256 public constant MAX_EPOCH_PERIOD = 365 days;
    uint256 public constant MIN_PRICE_MULTIPLIER = 1.1e18; // Should at least be 110% of settlement price
    uint256 public constant MAX_PRICE_MULTIPLIER = 3e18; // Should not exceed 300% of settlement price
    uint256 public constant ABS_MIN_INIT_PRICE = 1e6; // Minimum sane value for init price
    uint256 public constant ABS_MAX_INIT_PRICE = type(uint192).max; // chosen so that initPrice * priceMultiplier does
        // not exceed uint256
    uint256 public constant PRICE_MULTIPLIER_SCALE = 1e18;

    IERC20 public immutable paymentToken;
    address public immutable paymentReceiver;
    uint256 public immutable epochPeriod;
    uint256 public immutable priceMultiplier;
    uint256 public immutable minInitPrice;

    address public immutable oftAdapter;
    uint32 public immutable dstEid;

    address public immutable hookTarget;
    bytes4 public immutable hookTargetSelector;

    struct Slot0 {
        uint8 locked; // 2 if locked, 1 if unlocked
        uint16 epochId; // intentionally overflowable
        uint192 initPrice;
        uint40 startTime;
    }

    Slot0 internal slot0;

    event Buy(address indexed buyer, address indexed assetsReceiver, uint256 paymentAmount);
    event HookTargetFailed(bytes32 reason);

    error Reentrancy();
    error InitPriceBelowMin();
    error InitPriceExceedsMax();
    error EpochPeriodBelowMin();
    error EpochPeriodExceedsMax();
    error PriceMultiplierBelowMin();
    error PriceMultiplierExceedsMax();
    error MinInitPriceBelowMin();
    error MinInitPriceExceedsAbsMaxInitPrice();
    error DeadlinePassed();
    error EmptyAssets();
    error EpochIdMismatch();
    error MaxPaymentTokenAmountExceeded();
    error PaymentReceiverIsThis();
    error InvalidOFTAdapter();

    modifier nonReentrant() {
        if (slot0.locked == 2) revert Reentrancy();
        slot0.locked = 2;
        _;
        slot0.locked = 1;
    }

    modifier nonReentrantView() {
        if (slot0.locked == 2) revert Reentrancy();
        _;
    }

    /// @dev Initializes the FeeFlowControllerEVK contract with the specified parameters.
    /// @param evc The address of the Ethereum Vault Connector (EVC) contract.
    /// @param initPrice The initial price for the first epoch.
    /// @param paymentToken_ The address of the payment token. This must not be the share token of the EVK vault.
    /// @param paymentReceiver_ The address of the payment receiver.
    /// @param epochPeriod_ The duration of each epoch period.
    /// @param priceMultiplier_ The multiplier for adjusting the price from one epoch to the next.
    /// @param minInitPrice_ The minimum allowed initial price for an epoch.
    /// @param oftAdapter_ The address of the OFT adapter.
    /// @param dstEid_ The LayerZero endpoint ID of the destination chain.
    /// @param hookTarget_ The address of the hook target.
    /// @param hookTargetSelector_ The selector of the function called on the hook target.
    /// @notice This constructor performs parameter validation and sets the initial values for the contract.
    constructor(
        address evc,
        uint256 initPrice,
        address paymentToken_,
        address paymentReceiver_,
        uint256 epochPeriod_,
        uint256 priceMultiplier_,
        uint256 minInitPrice_,
        address oftAdapter_,
        uint32 dstEid_,
        address hookTarget_,
        bytes4 hookTargetSelector_
    ) EVCUtil(evc) {
        if (initPrice < minInitPrice_) revert InitPriceBelowMin();
        if (initPrice > ABS_MAX_INIT_PRICE) revert InitPriceExceedsMax();
        if (epochPeriod_ < MIN_EPOCH_PERIOD) revert EpochPeriodBelowMin();
        if (epochPeriod_ > MAX_EPOCH_PERIOD) revert EpochPeriodExceedsMax();
        if (priceMultiplier_ < MIN_PRICE_MULTIPLIER) revert PriceMultiplierBelowMin();
        if (priceMultiplier_ > MAX_PRICE_MULTIPLIER) revert PriceMultiplierExceedsMax();
        if (minInitPrice_ < ABS_MIN_INIT_PRICE) revert MinInitPriceBelowMin();
        if (minInitPrice_ > ABS_MAX_INIT_PRICE) revert MinInitPriceExceedsAbsMaxInitPrice();
        if (paymentReceiver_ == address(this)) revert PaymentReceiverIsThis();
        if (oftAdapter_ != address(0) && address(paymentToken_) != IOFT(oftAdapter_).token()) {
            revert InvalidOFTAdapter();
        }

        slot0.initPrice = uint192(initPrice);
        slot0.startTime = uint40(block.timestamp);

        paymentToken = IERC20(paymentToken_);
        paymentReceiver = paymentReceiver_;
        epochPeriod = epochPeriod_;
        priceMultiplier = priceMultiplier_;
        minInitPrice = minInitPrice_;
        oftAdapter = oftAdapter_;
        dstEid = dstEid_;
        hookTarget = hookTarget_;
        hookTargetSelector = hookTargetSelector_;
    }

    /// @dev Allows the contract to receive ETH
    receive() external payable {}

    /// @dev Allows a user to buy assets by transferring payment tokens and receiving the assets.
    /// @param assets The addresses of the assets to be bought.
    /// @param assetsReceiver The address that will receive the bought assets.
    /// @param epochId Id of the epoch to buy from, will revert if not the current epoch
    /// @param deadline The deadline timestamp for the purchase.
    /// @param maxPaymentTokenAmount The maximum amount of payment tokens the user is willing to spend.
    /// @return paymentAmount The amount of payment tokens transferred for the purchase.
    /// @notice This function performs various checks and transfers the payment tokens to the payment receiver.
    /// It also transfers the assets to the assets receiver and sets up a new auction with an updated initial price.
    function buy(
        address[] calldata assets,
        address assetsReceiver,
        uint256 epochId,
        uint256 deadline,
        uint256 maxPaymentTokenAmount
    ) external nonReentrant returns (uint256 paymentAmount) {
        if (block.timestamp > deadline) revert DeadlinePassed();
        if (assets.length == 0) revert EmptyAssets();

        Slot0 memory slot0Cache = slot0;

        if (uint16(epochId) != slot0Cache.epochId) revert EpochIdMismatch();

        address sender = _msgSender();

        paymentAmount = getPriceFromCache(slot0Cache);

        if (paymentAmount > maxPaymentTokenAmount) revert MaxPaymentTokenAmountExceeded();

        if (paymentAmount > 0) {
            if (oftAdapter == address(0)) {
                paymentToken.safeTransferFrom(sender, paymentReceiver, paymentAmount);
            } else {
                paymentToken.safeTransferFrom(sender, address(this), paymentAmount);
                uint256 balance = paymentToken.balanceOf(address(this));

                SendParam memory sendParam = SendParam({
                    dstEid: dstEid,
                    to: bytes32(uint256(uint160(paymentReceiver))),
                    amountLD: balance,
                    minAmountLD: 0,
                    extraOptions: "",
                    composeMsg: "",
                    oftCmd: ""
                });
                MessagingFee memory fee = IOFT(oftAdapter).quoteSend(sendParam, false);

                if (address(this).balance >= fee.nativeFee) {
                    paymentToken.forceApprove(oftAdapter, balance);
                    IOFT(oftAdapter).send{value: fee.nativeFee}(sendParam, fee, address(this));
                }
            }
        }

        for (uint256 i = 0; i < assets.length; ++i) {
            // Convert fees
            IEVault(assets[i]).convertFees();

            // Transfer full balance to buyer
            uint256 balance = IERC20(assets[i]).balanceOf(address(this));
            IERC20(assets[i]).safeTransfer(assetsReceiver, balance);
        }

        // Setup new auction
        uint256 newInitPrice = paymentAmount * priceMultiplier / PRICE_MULTIPLIER_SCALE;

        if (newInitPrice > ABS_MAX_INIT_PRICE) {
            newInitPrice = ABS_MAX_INIT_PRICE;
        } else if (newInitPrice < minInitPrice) {
            newInitPrice = minInitPrice;
        }

        // epochID is allowed to overflow, effectively reusing them
        unchecked {
            slot0Cache.epochId++;
        }
        slot0Cache.initPrice = uint192(newInitPrice);
        slot0Cache.startTime = uint40(block.timestamp);

        // Write cache in single write
        slot0 = slot0Cache;

        emit Buy(sender, assetsReceiver, paymentAmount);

        // Perform the hook call if the hook target is set
        if (hookTarget != address(0)) {
            (bool success, bytes memory result) = hookTarget.call(abi.encodeWithSelector(hookTargetSelector));

            if (!success && result.length != 0) {
                bytes32 reason;
                assembly {
                    reason := mload(add(32, result))
                }
                emit HookTargetFailed(reason);
            }
        }

        return paymentAmount;
    }

    /// @dev Retrieves the current price from the cache based on the elapsed time since the start of the epoch.
    /// @param slot0Cache The Slot0 struct containing the initial price and start time of the epoch.
    /// @return price The current price calculated based on the elapsed time and the initial price.
    /// @notice This function calculates the current price by subtracting a fraction of the initial price based on the
    /// elapsed time.
    // If the elapsed time exceeds the epoch period, the price will be 0.
    function getPriceFromCache(Slot0 memory slot0Cache) internal view returns (uint256) {
        uint256 timePassed = block.timestamp - slot0Cache.startTime;

        if (timePassed > epochPeriod) {
            return 0;
        }

        return slot0Cache.initPrice - slot0Cache.initPrice * timePassed / epochPeriod;
    }

    /// @dev Calculates the current price
    /// @return price The current price calculated based on the elapsed time and the initial price.
    /// @notice Uses the internal function `getPriceFromCache` to calculate the current price.
    function getPrice() external view nonReentrantView returns (uint256) {
        return getPriceFromCache(slot0);
    }

    /// @dev Retrieves Slot0 as a memory struct
    /// @return Slot0 The Slot0 value as a Slot0 struct
    function getSlot0() external view nonReentrantView returns (Slot0 memory) {
        return slot0;
    }
}
