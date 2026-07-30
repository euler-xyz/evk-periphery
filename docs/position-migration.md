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

## 1. Prerequisites

[Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge` and `cast`), `git`, `jq`, and an RPC endpoint for the chain the position is on.

```sh
curl -L https://foundry.paradigm.xyz | bash && foundryup
```

## 2. Clone and build

`evk-periphery` reads its address books from `../euler-interfaces/addresses`, so the two checkouts **must be siblings**:

```sh
mkdir euler && cd euler
git clone https://github.com/euler-xyz/evk-periphery.git
git clone https://github.com/euler-xyz/euler-interfaces.git
cd evk-periphery
forge install && forge build
```

The submodules are recursive and large — expect a checkout of roughly 1 GB and a first build of several minutes.

## 3. Configure

```sh
cp .env.example .env
```

Set the RPC endpoint for your chain in `.env`, keyed by chain ID:

```sh
DEPLOYMENT_RPC_URL_1=https://your-ethereum-endpoint
```

Leave `DEPLOYMENT_RPC_URL` (the un-suffixed one) empty. If you set it, it pins every invocation to that single endpoint and `--rpc-url` is ignored.

## 4. Identify the source account

An Euler position belongs to an *EVC account*: a wallet address plus a sub-account id from 0 to 255. The account address is the wallet address with its **last byte XOR-ed by the id**, so id `0` is the wallet itself.

If you know the account address the position sits on — from the UI, the block explorer or the API — recover the owner wallet and the id with:

```sh
RPC=https://your-ethereum-endpoint
EVC=0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383   # Ethereum mainnet; see euler-interfaces/addresses/<chainId>/CoreAddresses.json
ACCOUNT=0x...                                     # the account holding the position

OWNER=$(cast call $EVC "getAccountOwner(address)(address)" $ACCOUNT --rpc-url $RPC)
ID=$(( 0x${ACCOUNT: -2} ^ 0x${OWNER: -2} ))
echo "owner=$OWNER id=$ID"
```

Confirm what will be picked up:

```sh
cast call $EVC "getCollaterals(address)(address[])" $ACCOUNT --rpc-url $RPC
cast call $EVC "getControllers(address)(address[])" $ACCOUNT --rpc-url $RPC
```

Anything not listed here will not be migrated.

## 5. Run the script

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

To move several sub-accounts of the same wallet in one batch, pass the id lists instead. `--source-account-id` / `--destination-account-id` are ignored in this form:

```sh
  --sig "run(uint8[],uint8[])" "[0,1,2]" "[0,1,2]"
```

The instruction is printed to the console and written to:

```
script/deployments/<deployment_name>/<chainId>/dry-run/output/MigrationInstruction_0.txt
```

alongside `Batches_0.json`, which holds the same batch as ABI-encoded calldata under `data` — useful if you would rather submit the raw calldata than fill in the explorer's array field.

A successful run means the migration was simulated against current chain state and the destination account passed its health check. If the position is unhealthy or the vault forbids one of the operations, the script fails here rather than on chain.

## 6. Execute the two transactions

The instruction file describes two transactions on the EVC.

**Step 1 — the source wallet authorises the destination wallet.** Call `setOperator(addressPrefix, operator, operatorBitField)` on the EVC from the source wallet, using the values from the file. `operatorBitField` is a bitmask of the sub-account ids being migrated: id 14 is `1 << 14` = `16384`.

**Step 2 — the destination wallet pulls the position.** Call `batch(items)` on the EVC from the destination wallet, pasting the `items` array from the file. The batch transfers the collateral, pulls the debt, disables the source account's collateral and controller, and revokes the operator authorisation granted in step 1.

> **Between step 1 and step 2 the destination wallet has full control of the source sub-account** and can move the position anywhere. Keep the window short, and be certain the destination wallet is yours. If step 2 is not executed, revoke immediately by re-sending `setOperator` with `operatorBitField` set to `0`.

`setOperator` sets the operator's bitfield outright rather than adding to it. If the destination wallet already held operator rights over other sub-accounts of the same wallet, those are cleared.

If step 2 reverts out of gas, resubmit it with a manually raised gas limit. The batch defers all health checks to the end of the transaction, and a tight wallet estimate can fall just short.

If the destination wallet is a Safe, add `--batch-via-safe --safe-address <SAFE_ADDRESS>` to the command in step 5. Step 2 is then emitted as a Safe Transaction Builder JSON in the same output directory instead of raw explorer input. Step 1 is unaffected — it still has to be sent by the source wallet.

## 7. Verify

```sh
cast call $EVC "getCollaterals(address)(address[])" $SOURCE_ACCOUNT --rpc-url $RPC       # []
cast call $EVC "getControllers(address)(address[])" $SOURCE_ACCOUNT --rpc-url $RPC       # []
cast call $EVC "getCollaterals(address)(address[])" $DESTINATION_ACCOUNT --rpc-url $RPC  # the collateral vaults
cast call $EVC "getControllers(address)(address[])" $DESTINATION_ACCOUNT --rpc-url $RPC  # the borrow vault
cast call $EVC "isAccountOperatorAuthorized(address,address)(bool)" $SOURCE_ACCOUNT $DESTINATION_WALLET --rpc-url $RPC  # false
```

## Worked example

The Usual Stability Loan market on Ethereum mainnet — `bUSD0` collateral, `USD0` borrowed:

| | |
|---|---|
| collateral vault | `0xF037eeEBA7729c39114B9711c75FbccCa4A343C8` (`eUSD0++-3`, asset `bUSD0`) |
| borrow vault | `0xd001f0a15D272542687b2677BA627f48A4333b5d` (`eUSD0-4`, asset `USD0`) |
| owner wallet | `0x86b8dc38D6EAD92B200e1214bB5280e9db3E2cc9` |
| sub-account id | `14`, i.e. account `0x86b8dc38d6ead92b200e1214bb5280e9db3e2cc7` |

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

produces:

```
Step 1: give control over your account to the destination wallet
    setOperator/payableAmount: 0
    addressPrefix: 0x86b8dc38d6ead92b200e1214bb5280e9db3e2c
    operator: 0x1111111111111111111111111111111111111111
    operatorBitField: 16384

Step 2: pull the position from the source account to the destination account
    batch/payableAmount: 0
    items: [[...7 items...]]
```

The seven batch items are, in order: `enableCollateral` on the destination account, `transferFromMax` of the `eUSD0++-3` shares, `disableCollateral` on the source account, `enableController` on the destination account, `pullDebt(max)` from the source account, `disableController` on the source account, and `setAccountOperator(..., false)` to revoke step 1.

Note that this particular sub-account also holds `eUSDC-2` shares that were never enabled as collateral. They are not in `getCollaterals()`, so the migration leaves them on the source account — they have to be withdrawn or transferred separately.
