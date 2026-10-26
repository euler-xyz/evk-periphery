# Deployment and Management Scripts

## Prerequisites

Install [Foundry](https://book.getfoundry.sh/getting-started/installation), `git` and `jq`.

Clone the `euler-interfaces` repository *next to* this one — the scripts resolve the address books through the hardcoded relative path `../euler-interfaces/addresses`, so the two checkouts must be siblings:

```sh
cd .. && git clone https://github.com/euler-xyz/euler-interfaces.git && cd evk-periphery
```

Pull in the submodules and compile (the submodules are large, expect a ~1 GB checkout):

```sh
forge install && forge build
```

Create the `.env` file from the example:

```sh
cp .env.example .env
```

### Environment Variables

Where a variable and a command-line option address the same setting, **the variable wins** — `DEPLOYMENT_RPC_URL` overrides `--rpc-url`, `SAFE_ADDRESS` overrides `--safe-address`, `SAFE_NONCE` overrides `--safe-nonce` and `DEPLOYER_KEY` overrides `--account`/`--ledger`. Leave a variable empty in `.env` if you intend to pass it per invocation.

| Variable | Description |
|----------|-------------|
| `DEPLOYMENT_RPC_URL` | Destination RPC endpoint (use `http://127.0.0.1:8545` for local anvil). If defined, pins every invocation to this one endpoint, taking precedence over both `--rpc-url` and `DEPLOYMENT_RPC_URL_<CHAIN_ID>`. Leave it empty unless that is what you want |
| `DEPLOYMENT_RPC_URL_<CHAIN_ID>` | Chain-specific RPC URL (see RPC shorthand below) |
| `FORK_RPC_URL` | Remote endpoint for local anvil fork state |
| `DEPLOYER_KEY` | Private key for deployments (or use `--ledger` / `--account`) |
| `SAFE_KEY` | Private key for Safe transaction signing |
| `SAFE_ADDRESS` | Safe address for multisig transactions (or use `--safe-address`) |
| `SAFE_NONCE` | Safe nonce (auto-retrieved if not provided) |
| `SAFE_API_KEY` | Safe API key from https://developer.safe.global/ |
| `VERIFIER_URL[_<CHAIN_ID>]` | Contract verifier URL (e.g., `https://api.polygonscan.com/api`) |
| `VERIFIER_API_KEY[_<CHAIN_ID>]` | Verifier API key |

### RPC URL Shorthand

Define chain-specific RPC URLs in `.env`:

```sh
DEPLOYMENT_RPC_URL_1=https://eth-mainnet.example.com
DEPLOYMENT_RPC_URL_8453=https://base-mainnet.example.com
DEPLOYMENT_RPC_URL_42161=https://arb-mainnet.example.com
```

Then reference by chain ID or network name:

```sh
--rpc-url 8453          # Uses DEPLOYMENT_RPC_URL_8453
--rpc-url base          # Looks up chain ID, then uses DEPLOYMENT_RPC_URL_8453
--rpc-url mainnet       # Uses DEPLOYMENT_RPC_URL_1
--rpc-url local         # Uses http://127.0.0.1:8545
```

Network name aliases:

| Alias | Chain ID | Alias | Chain ID |
|-------|----------|-------|----------|
| `mainnet`, `ethereum` | 1 | `linea` | 59144 |
| `optimism`, `op` | 10 | `berachain`, `bera` | 80094 |
| `arbitrum`, `arb` | 42161 | `mantle` | 5000 |
| `avalanche`, `avax` | 43114 | `worldchain`, `world` | 480 |
| `polygon`, `matic` | 137 | `ink` | 57073 |
| `gnosis`, `xdai` | 100 | `bob` | 60808 |
| `bsc`, `bnb` | 56 | `sonic` | 146 |
| `base` | 8453 | `unichain`, `uni` | 130 |
| `swell` | 1923 | `monad` | 143 |
| `hyperevm`, `hyper` | 999 | | |

## Quick Start

### Local Anvil Fork

```sh
source .env && anvil --fork-url "$FORK_RPC_URL"
```

### Interactive Deployment

```sh
./script/interactiveDeployment.sh --account ACC_NAME --rpc-url RPC_URL
```

## Custom Scripts

The `script/production/CustomScripts.s.sol` file contains utility scripts for common operations. Run them using `ExecuteSolidityScript.sh`:

```sh
./script/production/ExecuteSolidityScript.sh <script_path>:<contract_name> [options]
```

### Available Custom Scripts

#### GetVaultInfoFull
Retrieve complete vault information via the VaultLens.

```sh
./script/production/ExecuteSolidityScript.sh \
  ./script/production/CustomScripts.s.sol:GetVaultInfoFull \
  --sig "run(address)" <VAULT_ADDRESS> \
  --rpc-url <RPC_URL>
```

#### GetAccountInfo
Get account information for a specific vault.

```sh
./script/production/ExecuteSolidityScript.sh \
  ./script/production/CustomScripts.s.sol:GetAccountInfo \
  --sig "run(address,address)" <ACCOUNT_ADDRESS> <VAULT_ADDRESS> \
  --rpc-url <RPC_URL>
```

#### MigratePosition
Move an EVC account's collateral and debt to an account owned by another wallet, without unwinding the position. Broadcasts nothing — it simulates the migration and writes the two transactions to sign to `MigrationInstruction_<n>.txt` in the output directory.

See [docs/position-migration.md](../docs/position-migration.md) for the full walkthrough, including what is *not* migrated.

Single position:
```sh
./script/production/ExecuteSolidityScript.sh \
  ./script/production/CustomScripts.s.sol:MigratePosition \
  --sig "run()" \
  --source-wallet <SOURCE_WALLET> \
  --destination-wallet <DESTINATION_WALLET> \
  --source-account-id <ID> \
  --destination-account-id <ID> \
  --rpc-url <RPC_URL> \
  --dry-run
```

Multiple sub-accounts of the same wallet in one batch (`--source-account-id` / `--destination-account-id` are ignored in this form):
```sh
./script/production/ExecuteSolidityScript.sh \
  ./script/production/CustomScripts.s.sol:MigratePosition \
  --sig "run(uint8[],uint8[])" "[0,1,2]" "[0,1,2]" \
  --source-wallet <SOURCE_WALLET> \
  --destination-wallet <DESTINATION_WALLET> \
  --rpc-url <RPC_URL> \
  --dry-run
```

> `run` is overloaded, so `--sig` is mandatory — without it `forge` aborts with `Multiple functions with the same name 'run' found in the ABI`.

#### MergeSafeBatchBuilderFiles
Merge multiple `SafeBatchBuilder_<nonce>_<safe>_*.json` files into a single multisend transaction.

```sh
./script/production/ExecuteSolidityScript.sh \
  ./script/production/CustomScripts.s.sol:MergeSafeBatchBuilderFiles \
  --safe-address <SAFE> \
  --path ./script/deployments/default/<CHAIN_ID>/output \
  --rpc-url <RPC_URL>
```

#### LiquidateAccount
Liquidate the maximum possible amount from an underwater account.

Check liquidation opportunity (view call):
```sh
./script/production/ExecuteSolidityScript.sh \
  ./script/production/CustomScripts.s.sol:LiquidateAccount \
  --sig "checkLiquidation(address,address)" <ACCOUNT> <COLLATERAL> \
  --rpc-url <RPC_URL>
```

Execute liquidation:
```sh
./script/production/ExecuteSolidityScript.sh \
  ./script/production/CustomScripts.s.sol:LiquidateAccount \
  --sig "run(address,address)" <ACCOUNT> <COLLATERAL> \
  --account <DEPLOYER_ACCOUNT> \
  --rpc-url <RPC_URL>
```

#### RedeployAccountLens / RedeployOracleUtilsAndVaultLenses
Redeploy lens contracts and update addresses.

```sh
./script/production/ExecuteSolidityScript.sh \
  ./script/production/CustomScripts.s.sol:RedeployAccountLens \
  --account <DEPLOYER_ACCOUNT> \
  --rpc-url <RPC_URL>
```

## Script Options Reference

### Core Options

| Option | Description |
|--------|-------------|
| `--rpc-url <URL\|CHAIN_ID>` | RPC endpoint or chain ID shorthand (uses `DEPLOYMENT_RPC_URL_<CHAIN_ID>`) |
| `--account <NAME>` | Use named Foundry account for signing |
| `--ledger` | Use Ledger hardware wallet for signing |
| `--dry-run` | Simulate without broadcasting transactions |
| `--verify` | Verify contracts after deployment |
| `--verifier <NAME>` | Verifier to use (default: `etherscan`) |

### Safe/Multisig Options

| Option | Description |
|--------|-------------|
| `--batch-via-safe` | Route EVC batch through Safe multisig. Creates `SafeBatchBuilder_*.json` payload files for Safe Transaction Builder |
| `--safe-address <ADDR>` | Safe address or alias from `MultisigAddresses.json` (`labs`, `DAO`, `securityCouncil`, etc.) |
| `--safe-nonce <N>` | Override Safe nonce (auto-retrieved if not provided) |
| `--safe-owner-simulate` | Verify sender is Safe owner/delegate before simulation. Fails if not authorized |
| `--skip-safe-simulation` | Skip transaction simulation before creating Safe payload. Used for emergency operations in case of pending transactions that are not desired to be simulated |

### Timelock Options

| Option | Description |
|--------|-------------|
| `--timelock-address <ADDR>` | Schedule transactions via timelock instead of immediate execution. Address, or a key of the chain's `GovernorAddresses.json` |
| `--timelock-id <ID>` | Operation ID for executing a scheduled timelock transaction (from `CallScheduled` event) |
| `--timelock-salt <SALT>` | Salt for timelock operation (default: zero) |

### Risk Steward Options

| Option | Description |
|--------|-------------|
| `--risk-steward-address <ADDR>` | Route governance operations through risk steward to bypass timelocks |

### Simulation Options

Before script execution, pending Safe and timelock transactions are automatically simulated to ensure the fork state reflects expected on-chain state after those transactions execute.

By default:
- Safe from `--safe-address` is used for pending transaction simulation
- Timelock from `--timelock-address` is used for pending transaction simulation

| Option | Description |
|--------|-------------|
| `--simulate-safe-address <ADDR>` | Override which Safe's pending transactions to simulate (if different from `--safe-address`) |
| `--simulate-timelock-address <ADDR>` | Override which timelock's pending transactions to simulate (if different from `--timelock-address`) |
| `--skip-pending-simulation` | Disable pending transaction simulation entirely |

### Emergency Options

For rapid response to security incidents. Typically used with cluster scripts.

| Option | Description |
|--------|-------------|
| `--emergency-ltv-collateral` | Disable vault as collateral by setting borrow LTVs to zero on all vaults using it |
| `--emergency-ltv-borrowing` | Disable all collaterals on the vault by setting their borrow LTVs to zero |
| `--emergency-caps` | Set supply and borrow caps to zero |
| `--emergency-operations` | Disable all vault operations via hook |
| `--vault-address <ADDR>` | Target vault (or `all` for all cluster vaults) |

### Migration Options

For `MigratePosition` script. See [docs/position-migration.md](../docs/position-migration.md).

| Option | Description |
|--------|-------------|
| `--source-wallet <ADDR>` | Source **owner wallet** address, not the sub-account address |
| `--destination-wallet <ADDR>` | Destination **owner wallet** address, not the sub-account address |
| `--source-account-id <ID>` | Source EVC sub-account ID (0-255). Ignored when `--sig "run(uint8[],uint8[])"` is used |
| `--destination-account-id <ID>` | Destination EVC sub-account ID (0-255). Ignored when `--sig "run(uint8[],uint8[])"` is used |

### Other Options

| Option | Description |
|--------|-------------|
| `--path <PATH>` | Custom path for file operations (e.g., `MergeSafeBatchBuilderFiles`) |
| `--from-block <N>` | Starting block for log queries |
| `--to-block <N>` | Ending block for log queries |
| `--no-stub-oracle` | Disable stub oracle usage (auto-disabled on non-mainnet/base chains) |
| `--force-zero-oracle` | Force zero oracle address |

## Timelock Transaction Execution

Execute scheduled timelock transactions:

```sh
./script/production/ExecuteSolidityScript.sh \
  ./script/utils/ExecuteTimelockTx.s.sol \
  --account <ACCOUNT> \
  --timelock-address <TIMELOCK_ADDRESS> \
  --timelock-id <OPERATION_ID> \
  --rpc-url <RPC_URL>
```

## Batch Deployment

For a chain with no prior Euler deployment, follow [Deploying to a New Chain](NEW_CHAIN.md).

### Full Core and Periphery Deployment (Option 50)

Deploys and configures the complete Euler V2 stack. The script prompts for:

**Required inputs:**
- DAO, Labs, Security Council, Security Partner A/B multisig addresses

**Optional inputs (skipped if already deployed):**
- Permit2 address (default: canonical deployment)
- Uniswap V2/V3 router addresses (for Swapper)
- Fee Flow init price (default 0: Fee Flow is skipped and the fee receiver is the DAO Safe)
- Deploy EUL OFT Adapter (y/n)
- Deploy Euler Earn (y/n)
- Deploy EulerSwap V2 (y/n) — if yes, prompts for Uniswap V4 Pool Manager

```sh
./script/interactiveDeployment.sh --account ACC_NAME --rpc-url RPC_URL
# Select option 50, provide inputs when prompted
```

### EUL bridge lists

EUL is bridged hub and spoke: every chain connects only to Ethereum. A chain's bridge is in one of three states:

```
TWO-WAY     Ethereum ──EUL──▶ chain       EUL can go to the chain
            Ethereum ◀──EUL── chain       and come back

ONE-WAY     Ethereum ───✕───  chain       nothing new goes to the chain
            Ethereum ◀──EUL── chain       holders can still bring EUL back

CLOSED      Ethereum ───✕───  chain
            Ethereum ───✕───  chain       nothing moves either way
```

Choose the state with the two lists in `OFT_CONFIG["EUL"]` (`script/50_CoreAndPeriphery.s.sol`), then run option 50 on both chains:

| The chain is on… | A run on Ethereum | A run on the chain |
|---|---|---|
| neither list (a new chain) | connects Ethereum to the chain | connects the chain to Ethereum |
| `configOneDirectionChainIds` | stops Ethereum sending to the chain (blocks its send library) | stops the chain receiving from Ethereum (blocks its receive library) |
| `configIgnoreChainIds` | disconnects Ethereum from the chain (sets its peer to zero) | disconnects the chain from Ethereum (sets its peer to zero) |

Each run changes only the chain it runs on, so every change takes two runs. A run applies its change at once if the deployer still controls the chain's OFT Adapter. Otherwise it writes the change as a DAO Safe batch (`--batch-via-safe --safe-address DAO`), which applies when the batch executes.

**Order.** To shut a direction, shut the sending side first. Wait until LayerZero Scan shows no EUL transfer still in transit, then shut the receiving side. Otherwise EUL in transit gets stuck. If the deployer controls an adapter, start the second run only after the wait.

**The bridge cache** (`euler-interfaces/config/bridge/BridgeConfigCache.json`) is option 50's record of which pairs are connected. Connecting adds an entry and disconnecting removes it. Making a bridge one-way leaves the entry, because the chains are still connected. A pair with no entry counts as new and gets connected, so a closed chain must stay on `configIgnoreChainIds` for as long as its address folder exists. euler-interfaces CI rejects a cache in which only one side lists the other, so commit it once both runs are done.

- Option 50 only reads chains under `euler-interfaces/addresses/<chainId>/`, so both runs must happen before a chain's folder is archived.
- If LayerZero has no blocked library on a chain (BOB today), that chain can't stop receiving. The run says so; Ethereum's blocked sending still keeps EUL from reaching it.
- If a run says a step must be done manually, do it, then re-run option 50 on that side so the cache follows.

### Retiring a chain's EUL bridge

A chain may keep running after Euler deprecates it. Retire its bridge in two steps:

1. **Make it one-way when the chain is deprecated.** Add it to `configOneDirectionChainIds`. Ethereum stops sending first; after the wait, the chain stops receiving. The bridge can stay one-way for as long as the chain runs.
2. **Close it later,** after announcing the date to holders. Move the chain to `configIgnoreChainIds`. The chain stops sending first, so a send from it fails instead of burning EUL that Ethereum would reject. After the wait, Ethereum stops receiving. Open one euler-interfaces PR with the resulting cache. EUL left on the chain stays there, and the EUL backing it stays locked in Ethereum's OFT Adapter.

### Ownership Transfer (Option 51)

After deployment, transfer ownership from deployer to multisigs:

- **Option 51**: Core contracts (EVC, EVault Factory, Protocol Config, etc.)

## Oracle Adapters

### Deploy Adapters

```sh
./script/production/DeployOracleAdapters.sh <csv_input_file_path> [existing_adapters_csv] --rpc-url <RPC_URL>
```

## Contract Verification

Verify contracts after deployment:

```sh
./script/utils/verifyContracts.sh <broadcast_file_or_directory> [options]
```

**Examples:**
```sh
# Single broadcast file
./script/utils/verifyContracts.sh script/deployments/default/1/broadcast/50_CoreAndPeriphery_0.json

# All files in a directory
./script/utils/verifyContracts.sh script/deployments/default/1/broadcast/

# With specific verifier
./script/utils/verifyContracts.sh script/deployments/default/1/broadcast/50_CoreAndPeriphery_0.json --verifier blockscout
```

**Verifier options:**

| Option | Description |
|--------|-------------|
| `--verifier etherscan` | Default. Requires `VERIFIER_API_KEY[_<CHAIN_ID>]` |
| `--verifier blockscout` | API key optional. Without `VERIFIER_API_KEY[_<CHAIN_ID>]`, Blockscout applies its anonymous rate limit |
| `--verifier sourcify` | Sourcify verification |
| `--verifier custom` | Custom verifier (i.e. snowtrace) |

To verify on a Blockscout explorer for a chain whose `VERIFIER_URL_<CHAIN_ID>` is another explorer, override both variables:

```sh
VERIFIER_URL=https://eth.blockscout.com/api VERIFIER_API_KEY=<blockscout key> ./script/utils/verifyContracts.sh script/deployments/default/1/broadcast/ --rpc-url 1 --verifier blockscout
```

Builds made with forge 1.8 or later keep absolute-path remappings in their metadata, which `forge verify-contract` does not submit. For such contracts the script submits the standard JSON input with the remappings of the local artifact that matches the on-chain code, so run it from the checkout and forge version that deployed.
