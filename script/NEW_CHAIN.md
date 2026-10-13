# Deploying to a New Chain

What it takes in this repository to deploy the Euler stack on a chain with no prior Euler deployment. Publishing the addresses (euler-interfaces), bytecode verification (euler-verifier) and the backend and apps have their own instructions in their repositories.

An AI agent can do the checks and the code changes (steps 1 and 2) by following [`.claude/skills/new-chain/SKILL.md`](../.claude/skills/new-chain/SKILL.md).

## 1. Prerequisites

**On the chain**

| Requirement | Why |
|---|---|
| EVM with Cancun opcodes and a standard contract-size limit | The contracts compile for Cancun. The EulerEarn factory is close to the size limit; Linea needed a size-optimised build |
| Permit2 at `0x000000000022D473030F116dDEE9F6B43aC78BA3` | Step 3 deploys it if it is missing |
| Safe 1.3.0 or 1.4.1 with its canonical MultiSendCallOnly, in the Safe UI | The multisigs are Safes. `SafeUtils` batches through MultiSendCallOnly and only knows these two versions |
| LayerZero V2 endpoint | The EUL bridge. Option 50 reads the endpoint and DVNs from LayerZero's metadata API |
| Merkl Distributor | rEUL rewards (step 6) |
| Block explorer with verification (Etherscan V2, Blockscout or Sourcify) | Step 9 |

**Locally**

| What | Where |
|---|---|
| `euler-interfaces` checked out next to this repo | Scripts read and write `../euler-interfaces/addresses/<chainId>/` |
| `.env` with `DEPLOYMENT_RPC_URL_<chainId>`, `VERIFIER_URL_<chainId>`, `VERIFIER_API_KEY_<chainId>`, `SAFE_API_KEY` | `./script/utils/dopplerSync.sh` writes `.env` from Doppler `evk-periphery` / `prd`. Add the new chain's values there |
| Deployer key, funded with gas | `--account`, `--ledger` or `DEPLOYER_KEY` |

## 2. Chain-support code

Some per-chain values are hard-coded in Solidity, and each lookup reverts for a chain it doesn't know. Add the chain in one PR and merge it before deploying, so every deployed contract is built from code on `development`. Commit `e59e1ef` (Katana) shows the WETH and Safe edits.

| File | Change |
|---|---|
| `script/utils/ScriptUtils.s.sol` → `getWETHAddress()` | The chain's WETH, or an explicit `address(0)` if it has none (as for Monad, Plasma, HyperEVM). Otherwise: `getWETHAddress: Unsupported chain` |
| `src/Lens/Utils.sol` → `getWETHAddress()` | The same entry. This copy is compiled into the lenses that option 50 deploys |
| `script/utils/SafeUtils.s.sol` → `getSafeBaseURL()` | Add the chain to the `https://safe-client.safe.global/` list if Safe hosts it, otherwise return the chain's own Safe gateway |
| `script/50_CoreAndPeriphery.s.sol` → `OFT_CONFIG["EUL"].configOneDirectionChainIds` | Add the chain: EUL travels only from the chain to Ethereum |
| `script/utils/verifyContracts.sh` | Only if verification fails with "Chain … not supported": route the chain to the `custom` verifier, as done for Monad (`143`) |

## 3. Permit2

```sh
cast code 0x000000000022D473030F116dDEE9F6B43aC78BA3 --rpc-url <rpc>
```

If it prints `0x`, deploy Permit2 at the same address by replaying its Ethereum deployment through the CREATE2 deployer. The same salt and init code give the same address:

```sh
cast code 0x4e59b44847b379578588920cA78FbF26c0B4956C --rpc-url <rpc>   # the CREATE2 deployer; must not be 0x

cast send 0x4e59b44847b379578588920cA78FbF26c0B4956C \
  "$(cast tx 0xf2f1fe96c16ee674bb7fcee166be52465a418927d124f5f1d231b36eae65d377 input --rpc-url <ethereum rpc>)" \
  --account DEPLOYER --rpc-url <rpc>
```

It uses about 2.0M gas. If the CREATE2 deployer is missing, ask the chain team to add it.

## 4. Safes

Create five Safes in the Safe UI: DAO, labs, security council, security partner A and security partner B. For now, make the deployer the only owner with threshold 1. The real owners come last (step 11): until then the deployer can correct anything alone, while afterwards every correction needs the owners' signatures or a redeployment.

Option 50 asks for their addresses and checks that each one is a deployed contract.

## 5. Deploy: option 50

```sh
./script/interactiveDeployment.sh --account DEPLOYER --rpc-url <chainId>
# choose 50
```

Run it once first with `--dry-run --test-addresses` added. That simulates without broadcasting and writes the simulated addresses under `../euler-interfaces/addresses/test/`. Discard what it wrote (`git status` in euler-interfaces).

| Prompt | Answer |
|---|---|
| DAO, labs, security council, security partner A and B | the Safes from step 4 |
| Permit2 | default |
| Uniswap V2 / V3 router | the chain's routers, or empty if it has none |
| Fee Flow init price | default |
| EUL OFT Adapter | `y` |
| Euler Earn | `y` |
| EulerSwap V2 | `n` |
| Securitize Vault Factory V2 | `n` |

Every step skips what already exists, so the option can be re-run.

**Results:**
- addresses in `../euler-interfaces/addresses/<chainId>/*.json`
- bridge state in `config/bridge/BridgeConfigCache.json`
- broadcasts in `script/deployments/`

## 6. rEUL: whitelist the Merkl Distributor

Before option 51, while the deployer still owns rEUL (its address is in `TokenAddresses.json`):

```sh
cast send <rEUL> "setWhitelistStatus(address,uint256)" 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae 2 \
  --account DEPLOYER --rpc-url <rpc>   # 2 = distributor
```

That is the Distributor on the chains checked so far. Confirm the address for the new chain with Merkl.

## 7. Hand over: option 51

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

## 8. Ethereum side of the EUL bridge

Spokes only peer with Ethereum, and the Ethereum OFT Adapter's delegate is the DAO Safe. The new chain's peer is added on Ethereum through a DAO batch; until it executes, EUL cannot move between the two.

```sh
./script/interactiveDeployment.sh --rpc-url 1 --batch-via-safe --safe-address DAO
# choose 50: existing contracts are skipped; the new chain's peering becomes a DAO Safe batch
```

## 9. Verify on the explorer

```sh
./script/utils/verifyContracts.sh script/deployments/default/<chainId>/broadcast/ [--verifier etherscan|blockscout|sourcify|custom]
```

Then check that every address written to `euler-interfaces/addresses/<chainId>/` shows as verified. If the EulerEarn contracts won't verify, follow the euler-earn README (`script/deploy.sh`).

## 10. Publish

One PR to euler-interfaces with:
- the address files
- the chain's `chains.js` entry, then `node chains.js`
- the verification manifest

euler-verifier must know the chain first: a `networks.json` entry, and the verifier version used by euler-interfaces CI bumped. See the READMEs and runbooks in both repositories.

## 11. Configure the Safes

```sh
./script/production/GenerateMultisigConfigurationTxBuilderFile.sh --rpc-url <chainId>
```

For each Safe, it writes a Safe Transaction Builder file that adds the owners from `euler-interfaces/config/multisig/<key>.json`, removes the deployer and sets the threshold. Execute each file in the Safe UI; the deployer signs alone.

## Done when

- Option 51 completed with no remaining `!` lines for items the deployer should hand over.
- The Merkl Distributor is whitelisted in rEUL.
- The DAO batch on Ethereum is executed.
- Every deployed contract is verified on the explorer.
- The euler-interfaces PR is merged.
- Every Safe has its configured owners and threshold, and the deployer is no longer an owner.
