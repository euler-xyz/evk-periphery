# EVK Swapper periphery

The `Swapper` and `SwapVerifier` contracts are helpers for executing swaps and swaps-to-repay operations on EVK vaults, using EVC batches.

## Security and trust boundaries

The `Swapper` contract is not trusted. From the protocol's perspective, it is a black box. Provided with a token to sell, it is supposed to execute the swap and return the bought token either as a balance available for deposit or as repaid debt. No assumptions are made about how the swap is performed or about the security of the `Swapper` code. In fact, the `Swapper` has no access control and allows anyone to remove any token balance it holds at any time. The provided implementation is just a reference; users are generally free to use any swapper they choose.

The `SwapVerifier` contract is part of the trusted codebase. Its responsibility is to verify the results of the `Swapper` execution, i.e., that the sold and bought token balances meet the required limits. The checks are simple but are the cornerstone of the security of using the swap periphery. It is the user's responsibility to ensure that all executions of the `Swapper` contract are always followed by proper verification with `SwapVerifier`, presumably as the following item in an EVC batch.

Because it is trusted, `SwapVerifier` (through the `MigrationHelper` base contract it inherits) is also the contract that may safely hold user authorizations — ERC20/Permit2 allowances, Aave credit delegations, and Morpho operator authorizations. Every such "from sender" primitive binds the token source / protocol-side on-behalf account to the EVC-authenticated `_msgSender()`, so a grant can only ever be exercised on the granting user's own position. These authorizations must always be granted to `SwapVerifier`, **never** to the `Swapper`: the `Swapper` is untrusted and lets anyone execute arbitrary calls, so a grant to it could be replayed by a front-runner to drain the victim. See [Position migration helpers](#position-migration-helpers) — and note in particular the caution there against leaving *standing* credit delegations or Morpho operator authorizations on the contract.

## `Swapper` contract

### General swapping algorithm

The general steps to use the `Swapper` contract are following:

- provision the `Swapper` with tokens to sell.

  The amount provided will serve as an implicit limit for the trade. In most cases the token will be provided with a `withdraw` from an `EVault` (or `borrow` in case of short trades), but the only requirement is that during the swap, the `Swapper` holds enough of the input token to carry out the trade.

- execute a call (or a series of calls) to `swap()` function.

  The assumption is that the calls will consume the provided tokens and buy the required output token.

- call `SwapVerifier` to make sure the results are within accepted bounds.

  The verification should be taking into account any expected slippage and price impact. This step is an essential security measure.

  For regular swaps, `SwapVerifier` assumes that any token balance present in the output vault after the swap is the result of the swap. For this reason the bought token is not deposited for the user automatically by the `Swapper`. It is the verifier that checks slippage and then skims the available assets for the user.

  In case of swap-to-repay mode, the `Swapper` contract is expected to repay the debt for the account, so `SwapVerifier` only checks that the resulting debt matches expectations 

### Interface

The `Swapper` contract should implement the `ISwapper` interface. This ensures, that users could potentially provide their own implementations of the swapper contract in the UI, without needing to modify the FE code.

The main function is `swap()`, which takes a swap definition in a `SwapParams` struct. The params define a handler to use, swapping mode, bought and sold tokens, the amounts etc. See [ISwapper natspec](../src/Swaps/ISwapper.sol) for details. Note, that some parameters might be ignored in certain modes or by certain handlers, while others (`amountOut`) might have different semantics in certain modes.

The interface also defines helper functions like `sweep`, `deposit`, `repay` and `repayAndDeposit` which allow consuming the contract's balance.

Finally a `multicall` function allows chaining all of the above to execute complex scenarios.

### Swapping modes

The swaps can be performed in one of 3 modes:
- exact input 

  In this mode, all of the provided input token is expected to be swapped for an unknown amount of the output token. The proceeds are expected to be sent to a vault, to be skimmed by the user, or back to the swapper contract. The latter option is useful when performing complex, multi-stage swaps, where the output token is accumulated in the swapper before being consumed at the end of the operation. Note that the available handler (`GenericHandler`) executes a payload encoded off-chain, so a lot of the parameters passed to the `swap` function will be ignored and only the amount of input token encoded in the payload will be swapped, even if the swapper holds more.

- exact output

  In this mode, the swapper is expected to purchase a specified amount of the output token in exchange for an unknown amount of the input token. The input token amount provided to the swapper acts as an implicit slippage limit. Currently available handlers (Uniswap V2 and V3) will check the current balance of the output token held by the swapper and adjust the amount of token to buy to only purchase the remainder. This feature can be used to construct multi-stage swaps. For instance, in the first stage, most of the token is bought through a dex aggregator, which presumably offers better price, but doesn't provide exact output swaps. The proceeds are directed to the swapper contract. In the second stage another `swap` call is executed, and the remainder is bought directly in Uniswap, where exact output trades are supported.

  In exact output trades, the remaining, unused input token amount is automatically redeposited for the account specified in `SwapParams.accountIn` in a vault specified in `SwapParams.vaultIn`.

  Note that the generic handler can also be invoked in exact output mode. The swap will be executed as per the request encoded off-chain, but swapper will attempt to return unused input token balance if any.

- target debt (swap and repay)

  In this mode, the swapper will check how much debt a provided account has (including current interest accrued), compare it with a target debt the user requests, and the amount already held by the swapper contract, and by exact output trade will buy exactly the amount required to repay the debt (down to the target amount). In most cases the target amount will be zero, which means the mode can be used to close debt positions without leaving any dust.

  After buying the necessary amount, the swapper will automatically execute `repay` on the liability vault for the user.

  If at the time the swap is executed, the swapper contract holds more funds than necessary to repay to the target debt, the swap is not carried out, but instead the debt is repaid and any surplus of the output token is deposited for the account in the liability vault. This allows combined swaps to safely target high ratios of exact input swaps vs exact output remainders. The exact input swap doesn't know the exact amount of output that will be received and it can 'over-swap' more than is necessary to repay the debt. Because the surplus doesn't revert the transaction, high ratios of better priced exact input swaps can be targeted by the UI.

  Finally, and similarly to exact output, any unused input will be redeposited for the `accountIn`.

  Note that the generic handler can also be invoked in target debt mode. In such a case there will be no on-chain modification to the swap payload, but swapper will attempt a repay and return of the unused input as per swap params.


### Handlers

The swapper contract executes trades using external providers like 1Inch or Uniswap. Internal handler modules take care of interfacing with the provider. They are enumerated by a `bytes32` encoded string. The available handlers are listed as constants in `Swapper.sol`.

- Generic handler

  Executes arbitrary call on arbitrary target address. Presumably they are calls to swap providers. For example a payload returned by [1Inch API](https://portal.1inch.dev/documentation/swap/introduction) on the aggregator contract or payloads created with [Uniswap's Auto Router](https://github.com/Uniswap/smart-order-router) on [SwapRouter02](https://etherscan.io/address/0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45)

  Generic handler accepts all 3 swapping modes, although for most swap providers only exact input is natively available. Although the off-chain data will not be modified to match the actual on-chain conditions during execution, swapper will carry out post processing according to the swap mode: returning unused input token in exact output mode or repaying debt in target debt mode. See F5 in [Common flows](#common-flows-in-evk) for one possible use case.

  The data passed to the handler in `SwapParams.data` should be an abi encoded tuple: target contract address and call data

- Uniswap V2 handler

  Doesn't support `exact input`. Executes exact output swaps on [UniswapV2 router](https://etherscan.io/address/0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D)

- Uniswap V3 handler

  Doesn't support `exact input`. Executes exact output swaps on [UniswapV3 router](https://etherscan.io/address/0xE592427A0AEce92De3Edee1F18E0157C05861564)

## `SwapVerifier` contract

This simple contract provides functions to verify results of the swaps and swaps-and-repays. It also inherits the from-sender primitives described under [Position migration helpers](#position-migration-helpers).

`verifyAmountMinAndSkim` - Checks the amount of assets available to skim on a vault and reverts if it is less than the required minimum. After verification the function skims available assets for the specified account. The assets available are considered the result of the swap. The user must make sure to put all the tokens bought with the swapper in the vault, either by performing swaps directly into the vault, or by calling `sweep` on the swapper, before calling the verification function (see F2. in common flows below).

`verifyDebtMax` - Checks that the debt of an account is not larger than given max amount. Swapper contract will automatically repay the debt when executing swap-and-repay mode, so no additional steps are required before or after verification.

## Position migration helpers

`SwapVerifier` inherits `MigrationHelper`, which adds a set of trusted "from sender" primitives used both as allowance sinks for ordinary swaps and for migrating leveraged positions in and out of Euler (e.g. from Aave V3 or Morpho Blue). They share a single security invariant: each one pins the token source / external-protocol on-behalf account to the EVC-authenticated `_msgSender()`.

- `transferFromSender(token, amount, to)` - pulls `amount` of `token` from the sender to `to`, using the sender's standing ERC20 or Permit2 allowance granted to this contract.
- `transferBalanceFromSender(token, maxAmount, to)` - pulls `min(balanceOf(sender), maxAmount)` to `to`. Reading the live balance drains a rebasing position (e.g. an Aave aToken that accrues interest between signing and execution) without leaving dust, while `maxAmount` bounds the pull so an unexpectedly large balance or oversized allowance cannot be over-pulled. Size the signed permit `value` to `maxAmount`.
- `aaveBorrowForSender(pool, asset, amount, to)` - borrows `amount` of `asset` from Aave V3 on behalf of the sender (the sender must have granted variable-debt credit delegation to this contract) and forwards the amount actually received to `to`. Only the borrow balance delta is forwarded, so a non-canonical or no-op `pool` cannot pay out any pre-existing balance.
- `morphoWithdrawCollateralForSender(morpho, marketParams, amount, to)` - withdraws Morpho Blue collateral on behalf of the sender (the sender must have authorized this contract as a Morpho operator) directly to `to`.
- `morphoBorrowForSender(morpho, marketParams, amount, to)` - borrows from a Morpho Blue market on behalf of the sender directly to `to`.

### Security model and usage

A user grants this contract an allowance / credit delegation / operator authorization so a migration batch can act for them. Because the acting account is bound to `_msgSender()`, the grant can only ever be exercised on the granting user's own position: a front-runner who replays the user's permit/delegation/authorization signature is authenticated as themselves and can only touch their own balance/position. The arbitrary `to` recipient is therefore not a leak — a replayer borrows against their *own* credit and chooses where their *own* proceeds go.

`_msgSender()` resolves to the EVC on-behalf-of account, so an address the user has authorized as an EVC operator can likewise run these on the user's behalf. This is a consequence of the user's own operator authorization, but it is a **sharper edge than it first appears, and the reason standing external-protocol grants should be avoided:**

> ⚠️ **Do not leave standing (persistent) Aave credit delegations or Morpho operator authorizations on this contract.** An EVC operator authorization is normally scoped to Euler/EVC actions, but these helpers bridge it into the user's *external* Aave/Morpho position. Any EVC operator the user has authorized — for any unrelated reason — can call `aaveBorrowForSender` / `morphoBorrowForSender` / `morphoWithdrawCollateralForSender` with `onBehalfOfAccount` set to the user, borrow against the user's delegated credit (or withdraw their collateral, bounded only by the external protocol's own health checks), and direct the proceeds (`to`) to themselves. The `_msgSender()` binding protects against third parties and replayers; it does **not** protect a user against their own EVC operators once a standing external grant exists.
>
> The safe pattern is **transient grant-and-revoke within the migration batch**: include the Aave `delegationWithSig` / Morpho `setAuthorizationWithSig` grant, the `*ForSender` leg, and the matching signature-based revocation in the same EVC batch, so no exploitable grant persists after the batch. The direct `approveDelegation` / `setAuthorization` entrypoints require the user to be `msg.sender`, so they are suitable for standalone user calls but not for execution as EVC batch items. Ordinary ERC20/Permit2 allowances for `transferFromSender` are far less dangerous — they only ever move the *granting* caller's own tokens to a `to` that same caller picks — but the same grant-and-revoke hygiene is recommended for unlimited approvals.

For this binding to hold, the privileged legs (`*ForSender` borrows and withdrawals) must be placed as **top-level EVC batch items** targeting `SwapVerifier` with `onBehalfOfAccount` set to the user — **not** nested inside `Swapper.multicall`. If they were nested, `msg.sender` from the helper's perspective would be the `Swapper` rather than the EVC, and `_msgSender()` would no longer resolve to the user (the call would instead act on behalf of the `Swapper`, which holds no grant, and revert). The non-privileged legs (swaps, supplies/repays that need no authorization, vault deposits) still run inside `Swapper.multicall` as usual.

`MigrationHelper` custodies no funds across calls, and (like `transferFromSender`'s `token`) its safety does not depend on the `pool`/`morpho` arguments being canonical addresses — the `_msgSender()` binding is what protects users.

## Common flows in EVK

F1. Swap exact amount of deposits from one EVault (A) to another (B)
- fetch a swap payload from either 1Inch api or Uniswap Auto Router, setting B as the receiver
- create EVC batch call with the following items:
  - `A.withdraw` the required input token amount to the swapper contract 
  - `Swapper.swap` - `exact input` on the generic handler
  - `SwapVerifier.verifyAmountMinAndSkim` Check a minimum required amount was bought for the input, according to slippage settings and claim it for the user.

F2. Swap deposits from one EVault (A) to exact amount of another (B)
- find an exact input payload on 1Inch or Uniswap Auto Router such that most of the required output amount is bought. E.g., binary search input amount that yields 98% of the required output amount. The receiver encoded in the payload must be the swapper contract.
- create EVC batch with the following items:
  - `A.withdraw` to the swapper contract. The amount must cover all of the estimated swap costs with some extra, to account for slippage
  - `swapper.multicall` with the following items:
    - `Swapper.swap` - `exact input` on the generic handler with the off-chain payload
    - `Swapper.swap` - `exact output` on one of the supporting handlers (Uni V2/V3) with the user specified `amountOut`. The receiver can be either the swapper contract or B vault.
    - `Swapper.sweep` the output token, into the B vault
  - `SwapVerifier.verifyAmountMinAndSkim` check a minimum required amount was bought and claim the funds for the user. Because exact output swaps are not guaranteed to be exact always, a small slippage could be allowed.

F3. Create leveraged position

The process is the same as in F1 or F2, but instead of withdrawing, the input token (short asset) is borrowed, with the `receiver` set to the swapper contract. To create leverage, the output token (long asset) should be deposited into a vault that is configured as collateral for the vault where the loan is taken. Of course, the user needs to enable correct controller and collaterals on the EVC first.

F4. Sell deposits from one vault (A) to repay debt in another (B)
- prepare a payload exactly like in F2, setting the bought amount to the debt user intends to repay
- create EVC batch with the following items:
- `A.withdraw` to the swapper contract. The amount must cover all of the estimated swap costs with extra to account for slippage
- `swapper.multicall` with the following items:
  - `Swapper.swap` - `exact input` with the off-chain payload
  - `Swapper.swap` - `target debt` mode on one of the supporting handlers (Uni V2/V3). The `amountOut` should be set to the amount of debt the user requested to have after the operation. Set to zero, to repay full debt.
- `SwapVerifier.verifyDebtMax` check that the user's debt matches the expectations. Because exact output swaps are not guaranteed to be exact always, a small slippage could be allowed.

F5. Sell deposit from one vault (A) to repay debt in another (B) when exact output is unavailable

For some token pairs, the exact output swap might not be available at all, or the price impact might be too big due to poor liquidity in Uniswap. In such cases to repay the full debt:
- find an exact input payload on 1Inch or Uniswap Auto Router, to buy slightly **more** of the output token than is necessary to repay the debt, taking into account slippage on exchanges and interest accrual between the payload generation and transaction execution. E.g., binary search input amount that yields 102% of the current debt (2% slippage limit). Set the receiver to the liability vault.
- create EVC batch with the following items:
  - `A.withdraw` the required input token amount to the swapper contract
  - `Swapper.swap` - `target debt` on the generic handler. The `amountOut` should be set to the amount of debt the user requested to have after the operation. Set to zero, to repay full debt.
  - `SwapVerifier.verifyDebtMax` check that the user's debt matches the expectations
