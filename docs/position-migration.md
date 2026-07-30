# Migrating a Position to Another Wallet

`MigratePosition` (in [`script/production/CustomScripts.s.sol`](../script/production/CustomScripts.s.sol)) moves an EVC account's **entire position** — every enabled collateral and every outstanding debt — to an account controlled by a different wallet.

The position is never unwound. Collateral shares are transferred and the debt is pulled by the destination account inside a single EVC batch, so there is no repayment, no swap, no flash loan and no exposure to price movement or slippage. Its main use is offboarding from a custodian: the position keeps running while the wallet that controls it changes.

The script **broadcasts nothing**. It simulates the migration against a fork of the target chain and writes a plain-text instruction file containing the two transactions that need to be signed, ready to paste into a block explorer.

## What is and is not migrated

Migrated, per source sub-account:

* every vault returned by `EVC.getCollaterals()` on which the account holds a non-zero share balance — the shares are transferred and the collateral is enabled on the destination account and disabled on the source account
* every vault returned by `EVC.getControllers()` on which the account has non-zero debt — the controller is enabled on the destination account, the debt is pulled with `pullDebt(type(uint256).max, sourceAccount)` and the controller is disabled on the source account

Not migrated:

* **vault shares that are not enabled as collateral.** The script iterates over the EVC's collateral list, not over vault balances. A plain deposit sitting in a vault the account never enabled stays behind and has to be moved separately
* tokens held directly by the wallet or the sub-account
* balance forwarder (rewards streaming) — if it was enabled on the source account, enable it on the destination account afterwards
* positions on other chains — run the script once per chain

## 1. Set up

Install [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge` and `cast`), plus `git` and `jq`:

```sh
curl -L https://foundry.paradigm.xyz | bash && foundryup
```

`evk-periphery` reads its address books from `../euler-interfaces/addresses`, so the two checkouts **must be siblings**:

```sh
mkdir euler && cd euler
git clone https://github.com/euler-xyz/evk-periphery.git
git clone https://github.com/euler-xyz/euler-interfaces.git
cd evk-periphery
forge install && forge build
```

The submodules are recursive and large — expect a checkout of roughly 1 GB and a first build of several minutes.

Then create the `.env` file and set the RPC endpoint for your chain, keyed by chain ID:

```sh
cp .env.example .env
```

```sh
DEPLOYMENT_RPC_URL_1=https://your-ethereum-endpoint
```

Leave `DEPLOYMENT_RPC_URL` (the un-suffixed one) empty. If you set it, it pins every invocation to that single endpoint and `--rpc-url` is ignored.

## 2. Find the source account

An Euler position belongs to an *EVC account*: a wallet address plus a sub-account id from 0 to 255, where id `0` is the wallet itself.

Open the source wallet's portfolio on [app.euler.finance](https://app.euler.finance) and note which sub-account holds the position — that number is the `--source-account-id` you pass below. The portfolio also shows which vaults are enabled as collateral, which is exactly what the migration will pick up.

## 3. Run the script

```sh
./script/production/ExecuteSolidityScript.sh \
  ./script/production/CustomScripts.s.sol:MigratePosition \
  --sig "run()" \
  --source-wallet <SOURCE_WALLET> \
  --source-account-id <SOURCE_ID> \
  --destination-wallet <DESTINATION_WALLET> \
  --destination-account-id <DESTINATION_ID> \
  --rpc-url <RPC_URL_OR_CHAIN_ID> \
  --dry-run
```

* `--sig "run()"` is **required**. `run` is overloaded, and without an explicit signature `forge` aborts with `Multiple functions with the same name 'run' found in the ABI`.
* `--source-wallet` / `--destination-wallet` are the **owner wallets**, not the sub-account addresses. The script derives the accounts from the wallet and the id.
* `--dry-run` is what you want. The script only simulates and writes files; it has no transaction to broadcast.
* The script prompts for a deployment name, which is only used to name the output directory.
* If the destination wallet is a Safe, add `--batch-via-safe --safe-address <SAFE_ADDRESS>`. The second transaction is then written as a Safe Transaction Builder JSON instead of raw explorer input.

A successful run means the migration was simulated against current chain state and the destination account passed its health check. If the position is unhealthy or a vault forbids one of the operations, the script fails here rather than on chain.

The instruction is printed to the console and written to:

```
script/deployments/<deployment_name>/<chainId>/dry-run/output/MigrationInstruction_0.txt
```

alongside `Batches_0.json`, which holds the same batch as ABI-encoded calldata under `data` — useful if you would rather submit the raw calldata than fill in the explorer's array field.

## 4. Sign the two transactions

Follow the instruction file. It walks through calling `setOperator` on the EVC from the **source** wallet, then `batch` from the **destination** wallet, with the exact input values filled in. Once the batch lands, the position shows up under the destination wallet in the app.

The file opens by telling you to trust the destination wallet. Three details it leaves out:

> **Between the two transactions the destination wallet has full control of the source sub-account** and can move the position anywhere. Keep the window short. If the second transaction is never sent, revoke immediately by re-sending `setOperator` with `operatorBitField` set to `0`.

* `setOperator` sets the operator's bitfield outright rather than adding to it. If the destination wallet already held operator rights over other sub-accounts of the same wallet, those are cleared.
* If the batch reverts out of gas, resubmit it with a manually raised gas limit. It defers all health checks to the end of the transaction, and a tight wallet estimate can fall just short.

## Worked example

The Usual Stability Loan market on Ethereum mainnet — `bUSD0` collateral, `USD0` borrowed — held on sub-account `14` of `0x86b8dc38D6EAD92B200e1214bB5280e9db3E2cc9`:

```sh
./script/production/ExecuteSolidityScript.sh \
  ./script/production/CustomScripts.s.sol:MigratePosition \
  --sig "run()" \
  --source-wallet 0x86b8dc38D6EAD92B200e1214bB5280e9db3E2cc9 \
  --source-account-id 14 \
  --destination-wallet 0x1111111111111111111111111111111111111111 \
  --destination-account-id 0 \
  --rpc-url mainnet \
  --dry-run
```

produces a seven-item batch: `enableCollateral` on the destination account, `transferFromMax` of the `eUSD0++-3` shares, `disableCollateral` on the source account, `enableController` on the destination account, `pullDebt(max)` from the source account, `disableController` on the source account, and `setAccountOperator(..., false)` to revoke the operator grant.

Note that this particular sub-account also holds `eUSDC-2` shares that were never enabled as collateral. They are not in `getCollaterals()`, so the migration leaves them on the source account — they have to be withdrawn or transferred separately.
