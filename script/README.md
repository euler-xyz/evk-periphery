# Deployment and Management Scripts

## Prerequisites

Clone the `euler-interfaces` repository in the parent directory:

```sh
cd .. && git clone https://github.com/euler-xyz/euler-interfaces.git && cd evk-periphery
```

Create the `.env` file from the example:

```sh
cp .env.example .env
```

### Environment Variables

All environment variables can be overridden via command-line options.

| Variable | Description |
|----------|-------------|
| `DEPLOYMENT_RPC_URL` | Destination RPC endpoint (use `http://127.0.0.1:8545` for local anvil). If defined, takes precedence over `DEPLOYMENT_RPC_URL_<CHAIN_ID>` |
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
Migrate positions between EVC accounts. Outputs step-by-step instructions for manual execution.

Single position:
```sh
./script/production/ExecuteSolidityScript.sh \
  ./script/production/CustomScripts.s.sol:MigratePosition \
  --source-wallet <SOURCE_WALLET> \
  --destination-wallet <DESTINATION_WALLET> \
  --source-account-id <ID> \
  --destination-account-id <ID> \
  --rpc-url <RPC_URL>
```

Multiple positions:
```sh
./script/production/ExecuteSolidityScript.sh \
  ./script/production/CustomScripts.s.sol:MigratePosition \
  --sig "run(uint8[],uint8[])" "[0,1,2]" "[0,1,2]" \
  --source-wallet <SOURCE_WALLET> \
  --destination-wallet <DESTINATION_WALLET> \
  --rpc-url <RPC_URL>
```

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
| `--timelock-address <ADDR>` | Schedule transactions via timelock instead of immediate execution. Aliases: `admin`, `wildcard`, `eusd` |
| `--timelock-id <ID>` | Operation ID for executing a scheduled timelock transaction (from `CallScheduled` event) |
| `--timelock-salt <SALT>` | Salt for timelock operation (default: zero) |

### Risk Steward Options

| Option | Description |
|--------|-------------|
| `--risk-steward-address <ADDR>` | Route governance operations through risk steward to bypass timelocks. Use `default` for `capRiskSteward` |

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

For `MigratePosition` script.

| Option | Description |
|--------|-------------|
| `--source-wallet <ADDR>` | Source wallet address |
| `--destination-wallet <ADDR>` | Destination wallet address |
| `--source-account-id <ID>` | Source EVC sub-account ID (0-255) |
| `--destination-account-id <ID>` | Destination EVC sub-account ID (0-255) |

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
  --timelock-address wildcard \
  --timelock-id <OPERATION_ID> \
  --rpc-url <RPC_URL>
```

## Batch Deployment

### Full Core and Periphery Deployment (Option 50)

Deploys and configures the complete Euler V2 stack. The script prompts for:

**Required inputs:**
- DAO, Labs, Security Council, Security Partner A/B multisig addresses

**Optional inputs (skipped if already deployed):**
- Permit2 address (default: canonical deployment)
- Uniswap V2/V3 router addresses (for Swapper)
- Fee Flow init price (enter 0 to skip)
- Deploy EUL OFT Adapter (y/n)
- Deploy Euler Earn (y/n)
- Deploy EulerSwap V2 (y/n) — if yes, prompts for Uniswap V4 Pool Manager
- Deploy eUSD/seUSD contracts (y/n)

```sh
./script/interactiveDeployment.sh --account ACC_NAME --rpc-url RPC_URL
# Select option 50, provide inputs when prompted
```

### Ownership Transfer (Options 51/52)

After deployment, transfer ownership from deployer to multisigs:

- **Option 51**: Core contracts (EVC, EVault Factory, Protocol Config, etc.)
- **Option 52**: Periphery contracts (Registries, Perspectives, Governors, etc.)

## Oracle Adapters

### Deploy Adapters

```sh
./script/production/DeployOracleAdapters.sh <csv_input_file_path> [existing_adapters_csv] --rpc-url <RPC_URL>
```

### Whitelist Adapters

```sh
./script/production/ConfigWhitelistOracleAdapters.sh <OracleAdaptersAddresses.csv> --rpc-url <RPC_URL>
```

### Whitelist Vaults in Governed Perspective

```sh
# For EVK vaults
./script/production/ConfigWhitelistGovernedPerspective.sh <vaults_list.csv> --evk --rpc-url <RPC_URL>

# For Euler Earn vaults
./script/production/ConfigWhitelistGovernedPerspective.sh <vaults_list.csv> --earn --rpc-url <RPC_URL>
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
| `--verifier blockscout` | No API key required |
| `--verifier sourcify` | Sourcify verification |
| `--verifier custom` | Custom verifier (i.e. snowtrace) |
