# Securitize ERC-4626 EVC Collateral Vault

This document describes `ERC4626EVCCollateralSecuritize`, an EVC-compatible, collateral-only ERC-4626 vault for restricted assets that expose Securitize's DS Token compliance service. It covers the contract stack, account model, transfer rules, administrative controls, liquidation flow and integration assumptions.

The vault is infrastructure for an issuer-approved integration. It does not define an asset's eligibility policy, preserve every restriction attached to an investor's underlying token balance or make an asset suitable for use as collateral by itself. Issuers, deployers and market operators must evaluate the composed behavior of the underlying token, its compliance service, the vault and the surrounding lending market.

## Architecture

The deployed contract is the final layer of a reusable ERC-4626 stack:

1. **`ERC4626EVC`** provides ERC-4626 accounting, EVC-aware authentication, Permit2 support and internal `totalAssets` tracking.
2. **`ERC4626EVCCollateral`** adds collateral-only behavior and EVC account status checks.
3. **`ERC4626EVCCollateralCapped`** adds a governor-managed supply cap, EVC vault status checks, snapshots and reentrancy protection.
4. **`ERC4626EVCCollateralFreezable`** adds a global pause and per-account-family freezes.
5. **`ERC4626EVCCollateralSecuritize`** restricts deposits and share transfers, checks eligible recipients for liquidation and seizure, and tracks balances by EVC address prefix.
6. **`ERC4626EVCCollateralSecuritizeFactory`** deploys vault instances and records them in the factory registry.

The underlying asset must implement `IDSToken` and expose a compliance service compatible with `IComplianceServiceRegulated.preTransferCheck`.

## Accounts and ownership

The EVC groups a root account and its subaccounts into one account family. The vault uses that relationship as its ownership boundary:

- `deposit` and `mint` require the share receiver to belong to the caller's EVC account family;
- ordinary `transfer` and `transferFrom` calls are limited to the same account family;
- a cross-family share transfer is allowed only during an EVC `controlCollateral` operation, when the enabled controller is verified by `controllerPerspective` and the recipient passes `isTransferCompliant`;
- `seize` is a governor-only cross-family transfer and also requires the recipient to pass `isTransferCompliant`.

A root account must be registered in the EVC before `isCommonOwner` can recognize its account family.

The vault also tracks wrapper-share balances by the first 19 bytes of the account address. This groups an EVC root account and its subaccounts for beneficial-owner accounting. The mapping tracks vault shares; it does not retain the issuance history or provenance of underlying tokens deposited into pooled vault custody.

## Operation policy

The table below summarizes the principal token-moving paths. “Underlying source” is the address observed as the ERC-20 sender when underlying assets move.

| Operation | Wrapper shares move from / to | Underlying source / receiver | Principal checks and exceptions |
| --- | --- | --- | --- |
| `deposit(assets, receiver)` | minted to `receiver` | caller to vault | `receiver` must share the caller's EVC owner; receiver not frozen; supply cap and underlying token checks apply |
| `mint(shares, receiver)` | minted to `receiver` | caller to vault | same policy as `deposit` |
| `transfer(to, amount)` | caller to `to` | none | same EVC owner, except a verified-controller liquidation; sender and receiver not frozen |
| `transferFrom(from, to, amount)` | `from` to `to` | none | same EVC owner, except a verified-controller liquidation; allowance/authentication and freeze checks apply |
| `withdraw(assets, receiver, owner)` | burned from `owner` | vault to `receiver` | standard ERC-4626 owner/allowance rules; receiver must not be an EVC subaccount without its own key; owner and receiver not frozen; underlying token checks apply |
| `redeem(shares, receiver, owner)` | burned from `owner` | vault to `receiver` | same policy as `withdraw` |
| liquidation share transfer | borrower to liquidator | none until redemption | EVC control-collateral context; controller verified by `controllerPerspective`; `isTransferCompliant` performs a point-in-time hypothetical vault-to-liquidator-owner precheck; borrower issuance provenance and the eventual redemption receiver are not preserved |
| `seize(from, to, amount)` | `from` to `to` | none until redemption | governor only; recipient not frozen; recipient must pass the same vault-to-recipient compliance simulation; the source account's freeze status is not checked |

Every operation in the table additionally requires the vault not to be paused.

### Withdraw and redeem receivers

`withdraw` and `redeem` do not require the underlying receiver to share the share owner's EVC account family and do not call `isCommonOwner` or `isTransferCompliant` for that receiver. The owner, or an approved caller acting under standard ERC-4626 allowance rules, may select an unrelated receiver. The vault rejects a receiver recognized as an EVC subaccount whose owner differs from the receiver address, avoiding payouts to subaccounts without usable private keys. An unrelated unregistered address or registered root account is otherwise accepted if the underlying token permits the transfer from the vault. Because the underlying sender is the vault rather than the depositor, this path does not preserve or reapply the depositor's issuance hold-up or issuance-lot provenance.

Integrators must not assume that the deposit/mint same-owner restriction also binds the receiver of an underlying withdrawal. If cross-owner payouts are not acceptable for an asset, that restriction must be provided by the underlying compliance system or by a different vault implementation.

### Liquidation and seizure compliance sender

`isTransferCompliant(to, amount)` resolves the recipient's EVC owner — returning `false` if the recipient has no registered EVC owner, so a liquidator or seizure recipient must be registered in the EVC — and calls the underlying compliance service as follows:

```solidity
preTransferCheck(address(this), toOwner, previewRedeem(amount));
```

This performs a point-in-time compliance precheck for a hypothetical underlying transfer from the vault to the share recipient's EVC owner, using the assets represented by the transferred shares. It does not model the borrower as the underlying sender, preserve or consult the borrower's issuance provenance, reserve future compliance approval, or require a later redemption to pay `toOwner`. Any later redemption executes a separate underlying transfer from the vault to the receiver selected for that redemption.

Only controllers accepted by `controllerPerspective` can use the liquidation exception. The perspective is therefore a security boundary and must not accept arbitrary or trivial controllers.

## Pooled-custody and issuance-hold-up behavior

Restricted tokens may treat a registered platform wallet differently from an ordinary investor wallet. In particular, a compliance service may allow transfers into a platform wallet and omit investor-specific issuance hold-up checks when that platform wallet later sends tokens to another eligible investor.

When the collateral vault is registered as such a platform wallet, the following behavior is possible:

1. an investor deposits underlying tokens that are still subject to an investor-specific issuance hold-up;
2. the underlying tokens enter pooled custody at the vault address;
3. the investor redeems to a different eligible receiver, or the investor's shares move to an eligible liquidator that redeems them;
4. the compliance service evaluates the payout using the vault as the underlying sender, rather than the original investor.

For the known Securitize configuration, Securitize has confirmed that platform-wallet destination and source exemptions can, in theory, allow an investor's 72-hour issuance hold-up to be bypassed through this flow. The vault does not preserve that hold-up: both an unrelated `withdraw` or `redeem` receiver and a liquidation followed by redemption produce a vault-originated underlying transfer. Destination KYC and other checks applied by the underlying token remain in force, so this does not by itself authorize payment to an ineligible destination.

Consequently, this vault does **not** preserve or enforce depositor-specific issuance lots after deposit. An issuance hold-up that applies to a direct investor-to-investor transfer may not survive routing through a platform-wallet vault. Destination eligibility checks continue to apply; this behavior does not by itself permit payout to an ineligible receiver.

For a deployment whose issuer and market operators accept these custody semantics, the two flows above are expected behavior of this implementation. Security reviews should distinguish the documented loss of depositor-specific issuance hold-up from a bypass of recipient eligibility, a full-investor lock, the vault's pause or freeze controls, controller verification, or share ownership authorization.

This is a material integration constraint, not a general statement that issuance restrictions are unimportant. A deployment is appropriate only where the issuer and market operators explicitly accept pooled platform-wallet custody with these semantics. Assets whose restrictions must remain attached to the depositing investor—including long-duration transfer restrictions—should not use this implementation unless the underlying compliance service independently enforces them across platform-wallet custody.

The latest DS Token implementation also supports a full-investor lock that can block transfers into platform wallets. That stronger control belongs to the underlying token and compliance configuration, not this vault, and must be tested for the deployed asset and version. This integration is intended for assets whose temporary, primarily security-oriented issuance hold-up can be treated with the platform-wallet semantics above; assets with longer-lived restrictions that must remain attached to the originating investor are not intended for this implementation.

## Administrative and risk controls

### Supply cap

The governor can configure a cap on total underlying assets. Interactions that increase total assets must remain within the resolved cap. Reducing total assets remains possible.

### Pause

The governor can pause value-moving operations. While checks are in progress, paused collateral reports a zero balance so it cannot support additional borrowing.

### Account-family freeze

The governor can freeze an address prefix, covering a root EVC account and its subaccounts. A frozen family's balance cannot change through normal vault operations; governor `seize` is the exception. During EVC checks, frozen collateral reports a zero balance.

The vault freeze is a wrapper control. It is distinct from any investor lock, sanctions control or transfer restriction implemented by the underlying token.

### Governor seizure

The governor can transfer shares from an account to an eligible recipient through `seize`. Seizure requires the vault not to be paused and the recipient's family not to be frozen, but does not check the source account's freeze status, so a frozen family's shares can still be seized (supporting a freeze-then-seize sequence). The operation does not transfer underlying assets immediately. The recipient may later redeem, subject to the underlying token's vault-to-recipient transfer checks.

### Controller perspective

The governor configures the perspective that identifies controllers permitted to execute cross-family collateral transfers during liquidation. Changing this perspective changes a critical authorization boundary and should be subject to the deployment's governance and review process.

## Deployment

`ERC4626EVCCollateralSecuritizeFactory.deploy` accepts:

- `controllerPerspective`: the perspective that verifies liquidation controllers;
- `asset`: the restricted underlying token;
- `name`: the vault share name;
- `symbol`: the vault share symbol.

The caller becomes governor admin of the new vault. The factory records the deployment address, deployer and timestamp.

Before deployment, verify at minimum:

1. the underlying asset exposes the expected DS Token compliance-service interface;
2. the issuer approves the vault address and its intended platform-wallet classification;
3. direct transfers, deposits, withdrawals, redemptions, liquidation transfers and seizure are tested against the production compliance configuration;
4. the issuer and market operators accept the pooled-custody and issuance-hold-up behavior described above;
5. destination eligibility remains enforced for vault-originated transfers;
6. stronger restrictions, including full-investor locks, are tested rather than inferred;
7. `controllerPerspective` accepts only the intended production controllers;
8. the initial supply cap, governor, pause and freeze procedures are defined;
9. the market's liquidation path has sufficient eligible liquidator participation.

Compliance-service configuration can change independently of the vault. Operators should repeat these checks when the asset, service implementation, wallet classification or transfer policy changes.

## References

- [`ERC4626EVCCollateralSecuritize.sol`](../src/Vault/deployed/ERC4626EVCCollateralSecuritize.sol)
- [`ERC4626EVCCollateralFreezable.sol`](../src/Vault/implementation/ERC4626EVCCollateralFreezable.sol)
- [`ERC4626EVCCollateralSecuritizeFactory.sol`](../src/VaultFactory/ERC4626EVCCollateralSecuritizeFactory.sol)
- [Securitize vault implementation PR #380](https://github.com/euler-xyz/evk-periphery/pull/380)
