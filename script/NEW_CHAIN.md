# Deploying to a New Chain

What it takes in this repository to deploy the Euler stack on a chain with no prior Euler deployment and hand it over to the multisigs. Publishing the addresses (euler-interfaces), bytecode verification (euler-verifier) and the backend and apps have their own instructions in their repositories.

## 1. Prerequisites

**On the chain**

| Requirement | Why |
|---|---|
| EVM with Cancun opcodes and a standard contract-size limit | The contracts compile for Cancun. The EulerEarn factory is close to the size limit; Linea needed a size-optimised build |
| Permit2 at `0x000000000022D473030F116dDEE9F6B43aC78BA3` | Option 50 asks for Permit2 and defaults to the canonical address |
| Safe 1.3.0 or 1.4.1 with its canonical MultiSendCallOnly | `SafeUtils` batches through MultiSendCallOnly and only knows these two versions |
| Safe client gateway for the chain | `getSafeBaseURL()` needs it for every `--batch-via-safe` run |
| LayerZero V2 endpoint (only if EUL is bridged) | The EUL OFT Adapter and its peering |
| Merkl Distributor (only if rEUL rewards are used) | Whitelisted in rEUL (step 7) |
| Uniswap V2/V3 routers (optional) | Swapper |
| Uniswap V4 PoolManager (only if EulerSwap V2 is deployed) | EulerSwap V2 is optional and off by default |
| Block explorer with verification (Etherscan V2, Blockscout or Sourcify) | Step 8 |

**Locally**

| What | Where |
|---|---|
| `euler-interfaces` checked out next to this repo | Scripts read and write `../euler-interfaces/addresses/<chainId>/` |
| `.env` with `DEPLOYMENT_RPC_URL_<chainId>`, `VERIFIER_URL_<chainId>`, `VERIFIER_API_KEY_<chainId>`, `SAFE_API_KEY` | `./script/utils/dopplerSync.sh` writes `.env` from Doppler `evk-periphery` / `prd`. Add the new chain's values there |
| Deployer key, funded with gas | `--account`, `--ledger` or `DEPLOYER_KEY` |

## 2. Chain-support code

A PR to this repository, merged before deploying. Each list below reverts for an unknown chain. Commit `e59e1ef` (Katana) is an example of the full set.

| File | Change |
|---|---|
| `script/utils/ScriptUtils.s.sol` → `getWETHAddress()` | The chain's WETH, or an explicit `address(0)` if it has none (as for Monad, Plasma, HyperEVM). Otherwise: `getWETHAddress: Unsupported chain` |
| `src/Lens/Utils.sol` → `getWETHAddress()` | The same entry. This copy is compiled into the lenses, so the lens deployment in option 50 fails without it |
| `script/utils/SafeUtils.s.sol` → `getSafeBaseURL()` | `https://safe-client.safe.global/` if Safe hosts the chain, otherwise the chain's own Safe gateway |
| `script/50_CoreAndPeriphery.s.sol` → `OFT_CONFIG["EUL"]` | If EUL is bridged: add the chain to `configOneDirectionChainIds` (EUL only travels from the chain to Ethereum; most chains) unless it should flow both ways. `configIgnoreChainIds` is for chains whose adapter must not be peered. Answering "n" to the OFT prompt in option 50 skips EUL bridging altogether |
| `foundry.toml` `[etherscan]` / `script/utils/verifyContracts.sh` | Only if Foundry doesn't know the chain's explorer. See `d6c9178` (Monad: the `custom` verifier against the Etherscan V2 endpoint) |
| `script/utils/determineArgs.sh` | Optional: an `--rpc-url` shorthand alias |

## 3. Multisigs

Option 50 requires five contracts: the DAO, labs, security council, security partner A and security partner B Safes. It checks that each address is a deployed contract. `FORCE_MULTISIG_ADDRESSES=true` skips that check; use it for test deployments only.

1. Create the five Safes on the chain.
2. Bring each Safe's owners and threshold to the values in `euler-interfaces/config/multisig/<key>.json`:

   ```sh
   ./script/production/GenerateMultisigConfigurationTxBuilderFile.sh --rpc-url <chainId> [--safe-address <key>]
   ```

   It compares the current owners and threshold with the expected ones and writes Safe Transaction Builder files with the changes.
3. Execute those files in the Safe UI.

The addresses can be entered when option 50 asks for them, or written beforehand to `../euler-interfaces/addresses/<chainId>/MultisigAddresses.json`. `--non-interactive` requires the file.

## 4. Deploy: option 50

Dry-run against a local fork first (see `script/README.md` → Local Anvil Fork), then for real:

```sh
./script/interactiveDeployment.sh --account DEPLOYER --rpc-url <chainId>
# choose 50
```

**Prompts:**
- the five multisigs
- Permit2
- the Uniswap V2/V3 routers
- the Fee Flow init price (`0` skips Fee Flow)
- whether to deploy the EUL OFT Adapter
- whether to deploy EulerEarn
- whether to deploy EulerSwap V2: optional, defaults to "n". Answer "y" only if EulerSwap is wanted on the chain; it then asks for the Uniswap V4 PoolManager, protocol fee config admin and registry curator
- whether to deploy Securitize Vault Factory V2

Every step skips what already exists, so the option can be re-run safely.

**Results:**
- addresses in `../euler-interfaces/addresses/<chainId>/*.json`
- bridge state in `config/bridge/BridgeConfigCache.json`
- broadcasts in `script/deployments/`

**Flags:**
- `--skip-oft-config-eul` skips the EUL bridge configuration.
- `--test-addresses` writes to `euler-interfaces/addresses/test/` instead.

**Not deployed any more** (since `5e6fa45`): the governor suite for governed clusters. Deploy one in Toolbox → Tools → Governance when needed (step 10).

## 5. Hand over: option 51

```sh
./script/interactiveDeployment.sh --account DEPLOYER --rpc-url <chainId>
# choose 51
```

| What | New owner |
|---|---|
| ProtocolConfig admin | DAO |
| EVault factory upgrade admin | EVault factory governor; its default admin becomes the factory timelock, and the deployer renounces its roles on both |
| EulerEarn factory | DAO |
| rEUL | labs |
| EUL default admin role | DAO |
| EUL OFT Adapter owner and delegate | DAO |

Items the deployer no longer controls are skipped with a `!` line in the output. Read it.

## 6. Ethereum side of the EUL bridge

Only if EUL is bridged.
- Spokes only peer with Ethereum.
- The Ethereum OFT Adapter's delegate is the DAO Safe, so the new chain's peer must be added on Ethereum through a DAO batch.
- Until that batch executes, EUL cannot move between the two.

```sh
./script/interactiveDeployment.sh --rpc-url 1 --batch-via-safe --safe-address DAO
# choose 50: existing contracts are skipped; the new chain's peering becomes a DAO Safe batch
```

## 7. rEUL: whitelist the Merkl Distributor

Only if rEUL rewards are used on the chain. rEUL's owner (the labs Safe after option 51, the deployer before it) calls:

```solidity
rEUL.setWhitelistStatus(<Merkl Distributor>, 2) // 2 = WHITELIST_STATUS_DISTRIBUTOR
```

The Distributor is `0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae` on the chains checked so far. Confirm the address for the new chain with Merkl.

## 8. Verify on the explorer

```sh
./script/utils/verifyContracts.sh script/deployments/default/<chainId>/broadcast/ [--verifier etherscan|blockscout|sourcify|custom]
```

Then check that every address written to `euler-interfaces/addresses/<chainId>/` shows as verified on the explorer.

## 9. Publish

One PR to euler-interfaces with:
- the address files
- the chain's `chains.js` entry, then `node chains.js`
- the verification manifest

euler-verifier must know the chain first: a `networks.json` entry, and the verifier version used by euler-interfaces CI bumped. See the READMEs and runbooks in both repositories.

## 10. Governed clusters

`--timelock-address admin|wildcard` and `--risk-steward-address default` resolve through the chain's `GovernorAddresses.json`, which is empty on a new chain.
1. Deploy a governor suite in Toolbox → Tools → Governance.
2. Then either pass its addresses explicitly (`cluster.vaultsGovernor`, `--timelock-address <address>`, `--risk-steward-address <address>`) or add them to `GovernorAddresses.json`.

See `script/production/README.md`.

## Done when

- Option 51 completed with no remaining `!` lines for items the deployer should hand over.
- The DAO batch on Ethereum is executed (if EUL is bridged).
- The Merkl Distributor is whitelisted (if rEUL is used).
- Every deployed contract is verified on the explorer.
- The euler-interfaces PR is merged.
