// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import {EVCUtil} from "ethereum-vault-connector/utils/EVCUtil.sol";
import {SafeERC20Permit2Lib} from "euler-earn/libraries/SafeERC20Permit2Lib.sol";
import {SafeERC20, IERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Minimal Aave V3 Pool interface used for position migrations.
interface IAaveV3Pool {
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external;
}

/// @notice Minimal Morpho Blue interface used for position migrations.
interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }

    function borrow(
        MarketParams calldata marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256 assetsBorrowed, uint256 sharesBorrowed);

    function withdrawCollateral(MarketParams calldata marketParams, uint256 assets, address onBehalf, address receiver)
        external;
}

/// @title MigrationHelper
/// @custom:security-contact security@euler.xyz
/// @author Euler Labs (https://www.eulerlabs.com/)
/// @notice Pulls tokens, and performs debt- and collateral-bearing actions on external lending protocols
///         (Aave V3, Morpho Blue), on behalf of the EVC-authenticated sender. Used both as a gas-saving
///         allowance sink for swaps and for migrating positions in and out of Euler.
/// @dev This contract is trusted and can safely receive token allowances, Aave credit delegations and
///      Morpho operator authorizations from users. Security model: every state-changing function pins the
///      token source / protocol-side on-behalf account to the EVC-authenticated `_msgSender()`. A user
///      grants this contract a standing allowance / credit delegation / operator authorization so a batch
///      can act for them, but because the acting account is bound to that caller, the grant can only ever
///      be exercised on the granting user's own position; a front-runner who replays the user's
///      permit/delegation/authorization signature is authenticated as themselves and can only touch their
///      own balance/position. `_msgSender()` resolves to the EVC on-behalf-of account, so an address the
///      user has authorized as an EVC operator can likewise exercise these grants on the user's behalf — a
///      consequence of the user's own operator authorization, consistent with the rest of the swap periphery.
///      CAUTION: this means a *standing* Aave credit delegation or Morpho operator authorization left on this
///      contract is exercisable by ANY EVC operator the user has authorized (for any unrelated reason): such an
///      operator can borrow the user's delegated credit / withdraw their external collateral and direct the
///      proceeds to themselves, bounded only by the external protocol's own health checks. The `_msgSender()`
///      binding protects against third parties and replayers, not against the user's own operators. The Aave
///      credit delegation / Morpho operator authorization should therefore be granted and revoked within the
///      migration batch rather than left standing. The contract custodies no funds across calls, and safety
///      does not depend on the `token`/`pool`/`morpho` arguments being canonical addresses.
contract MigrationHelper is EVCUtil {
    using SafeERC20 for IERC20;

    /// @notice Address of Permit2 contract
    address public immutable permit2;

    /// @dev Aave V3 variable interest rate mode. Stable-rate borrowing is not supported.
    uint256 internal constant AAVE_VARIABLE_RATE_MODE = 2;

    /// @notice Contract constructor
    /// @param _evc Address of the EthereumVaultConnector contract
    /// @param _permit2 Address of the Permit2 contract
    constructor(address _evc, address _permit2) EVCUtil(_evc) {
        permit2 = _permit2;
    }

    /// @notice Pull tokens from sender to the designated receiver
    /// @param token ERC20 token address
    /// @param amount Amount of the token to transfer
    /// @param to Receiver of the token
    function transferFromSender(address token, uint256 amount, address to) public {
        SafeERC20Permit2Lib.safeTransferFromWithPermit2(IERC20(token), _msgSender(), to, amount, permit2);
    }

    /// @notice Pull the sender's entire live balance of a token, capped at `maxAmount`, and forward it to `to`
    /// @param token The (possibly rebasing) ERC20 token to pull, e.g. an Aave aToken
    /// @param maxAmount Upper bound on the amount to pull; the actual amount is min(balance, maxAmount)
    /// @param to Recipient of the pulled tokens (e.g. the Swapper)
    /// @return amount The amount actually transferred
    /// @dev Reading the live balance avoids leaving dust behind when the token rebases (e.g. an Aave
    ///      aToken accruing interest between the user signing the permit and the batch executing), so the
    ///      whole position can be drained without an exact off-chain amount.
    /// @dev `maxAmount` bounds the pull to the balance measured off-chain plus a small accrual buffer: an
    ///      unexpectedly large balance, or a larger pre-existing allowance, can never cause an over-pull.
    ///      Size the signed permit `value` to `maxAmount` so the allowance always covers the capped transfer.
    /// @dev As with {transferFromSender}, the source is bound to `_msgSender()`, so a front-runner replaying
    ///      the user's permit can only ever drain their own balance.
    function transferBalanceFromSender(address token, uint256 maxAmount, address to) external returns (uint256 amount) {
        amount = IERC20(token).balanceOf(_msgSender());
        if (amount > maxAmount) amount = maxAmount;
        // Short-circuit a zero pull: nothing to move, and some ERC20s revert on zero-value transfers.
        if (amount == 0) return 0;
        transferFromSender(token, amount, to);
    }

    /// @notice Borrow an asset from Aave V3 on behalf of the sender and forward it to a receiver
    /// @param pool Address of the Aave V3 Pool
    /// @param asset The reserve asset to borrow
    /// @param amount The amount of `asset` to borrow
    /// @param to Recipient of the borrowed assets (e.g. the Swapper)
    /// @dev The sender must have granted variable-debt credit delegation to this contract for `asset`.
    /// @dev Aave sends the borrowed assets to msg.sender (this contract); only the amount actually
    ///      received from the borrow (the balance delta) is forwarded to `to`, so a non-canonical or
    ///      no-op `pool` cannot cause any pre-existing balance to be paid out, and no balance is left behind.
    function aaveBorrowForSender(address pool, address asset, uint256 amount, address to) external {
        uint256 balanceBefore = IERC20(asset).balanceOf(address(this));
        IAaveV3Pool(pool).borrow(asset, amount, AAVE_VARIABLE_RATE_MODE, 0, _msgSender());
        IERC20(asset).safeTransfer(to, IERC20(asset).balanceOf(address(this)) - balanceBefore);
    }

    /// @notice Withdraw Morpho Blue collateral on behalf of the sender, directly to a receiver
    /// @param morpho Address of the Morpho Blue contract
    /// @param marketParams The Morpho market parameters identifying the position
    /// @param amount The amount of collateral to withdraw
    /// @param to Recipient of the withdrawn collateral (e.g. the Swapper)
    /// @dev The sender must have authorized this contract as a Morpho operator.
    function morphoWithdrawCollateralForSender(
        address morpho,
        IMorpho.MarketParams calldata marketParams,
        uint256 amount,
        address to
    ) external {
        IMorpho(morpho).withdrawCollateral(marketParams, amount, _msgSender(), to);
    }

    /// @notice Borrow from a Morpho Blue market on behalf of the sender, directly to a receiver
    /// @param morpho Address of the Morpho Blue contract
    /// @param marketParams The Morpho market parameters identifying the market
    /// @param amount The amount of loan asset to borrow
    /// @param to Recipient of the borrowed assets (e.g. the Swapper)
    /// @dev The sender must have authorized this contract as a Morpho operator.
    function morphoBorrowForSender(
        address morpho,
        IMorpho.MarketParams calldata marketParams,
        uint256 amount,
        address to
    ) external {
        IMorpho(morpho).borrow(marketParams, amount, 0, _msgSender(), to);
    }
}
