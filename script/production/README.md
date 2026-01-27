# Cluster Deployment and Management

## Overview

A **cluster** is a collection of vaults that accept each other as collateral and share a common governor. The cluster management system provides:

- **Initial deployment**: Deploy vaults, oracle routers, and IRMs
- **Delta management**: Only apply configuration changes between script and on-chain state
- **Emergency mode**: Rapid response to security incidents

## Cluster Structure

Each cluster consists of:
- **Cluster script** (e.g., `BaseCluster.s.sol`): Defines assets, LTVs, oracles, caps, IRM parameters
- **Cluster JSON** (e.g., `BaseCluster.json`): Deployed contract addresses cache (auto-generated)
- **ManageCluster.s.sol**: Network-specific address definitions
- **ManageClusterBase.s.sol**: Core management logic

## Creating a New Cluster

1. Copy an existing cluster script as a template
2. Define assets in `defineCluster()`:

```solidity
cluster.assets = [WETH, USDC, wstETH];
cluster.clusterAddressesPath = "/script/production/<network>/clusters/MyCluster.json";
```

3. Configure in `configureCluster()`:

```solidity
// Governor (typically GovernorAccessControlEmergency)
cluster.oracleRoutersGovernor = cluster.vaultsGovernor = governorAddresses.accessControlEmergencyGovernor;

// Unit of account
cluster.unitOfAccount = USD;

// Oracle providers per asset
cluster.oracleProviders[WETH] = "ChainlinkOracle";
cluster.oracleProviders[wstETH] = "CrossAdapter=ChainlinkOracle+ChainlinkOracle";

// Supply/borrow caps (in whole tokens, not wei)
cluster.supplyCaps[WETH] = 10_000;
cluster.borrowCaps[WETH] = 8_000;

// IRM parameters: [baseRate, slope1, slope2, kink]
cluster.kinkIRMParams[WETH] = [uint256(0), uint256(194425692), uint256(41617711740), uint256(3865470566)];

// LTV matrix (row=vault, col=collateral, value=liquidationLTV in basis points)
cluster.ltvs = [
    //        WETH    USDC    wstETH
    [uint16(0.00e4), 0.87e4, 0.93e4],  // WETH vault
    [uint16(0.83e4), 0.00e4, 0.83e4],  // USDC vault
    [uint16(0.93e4), 0.87e4, 0.00e4],  // wstETH vault
];
```

4. Optionally define network-specific addresses in `ManageCluster.s.sol`

## Running Cluster Scripts

```bash
./script/production/ExecuteSolidityScript.sh <cluster_script> [options]
```

### Initial Deployment

First deployment when vaults don't exist yet:

```bash
./script/production/ExecuteSolidityScript.sh \
  script/production/base/clusters/BaseCluster.s.sol \
  --account DEPLOYER \
  --rpc-url base
```

### Managed Cluster Updates

After governance transferred to GovernorAccessControl + TimelockController + Safe:

```bash
./script/production/ExecuteSolidityScript.sh \
  script/production/base/clusters/BaseCluster.s.sol \
  --batch-via-safe \
  --safe-address DAO \
  --timelock-address wildcard \
  --rpc-url base
```

### Common Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Simulate without broadcasting |
| `--rpc-url <URL\|CHAIN_ID>` | RPC endpoint or chain ID shorthand |
| `--account <NAME>` / `--ledger` | Signing method |
| `--batch-via-safe` | Route transactions through Safe multisig |
| `--safe-address <ADDR>` | Safe address or alias (`DAO`, `labs`, etc.) |
| `--timelock-address <ADDR>` | Schedule via timelock (`admin`, `wildcard`, `eusd`) |
| `--risk-steward-address <ADDR>` | Bypass timelock for caps/IRM changes |

### Simulation Options

Pending Safe/timelock transactions are automatically simulated before script execution to ensure correct fork state.

| Option | Description |
|--------|-------------|
| `--simulate-safe-address <ADDR>` | Simulate different Safe than `--safe-address` |
| `--simulate-timelock-address <ADDR>` | Simulate different timelock than `--timelock-address` |
| `--skip-pending-simulation` | Disable pending transaction simulation |

## Important Notes

- **Always use `--dry-run` first** to simulate and check for issues
- **Commit the JSON file** after deployment — it's the deployed addresses cache
- **Don't reorder assets** in `cluster.assets` — it must match the LTV matrix order
- Oracle provider names match adapter contract `name()` return values

---

# Emergency Operations

For rapid response to security incidents. Requires `GovernorAccessControlEmergency` with appropriate emergency roles granted to a Safe multisig.

## Emergency Options

| Option | Effect |
|--------|--------|
| `--emergency-ltv-collateral` | Set borrow LTV to 0 for the vault when used as collateral (disables new borrows against it) |
| `--emergency-ltv-borrowing` | Set borrow LTV to 0 for all collaterals on the vault (disables new borrows) |
| `--emergency-caps` | Set supply and borrow caps to 0 (disables new deposits/borrows) |
| `--emergency-operations` | Disable all vault operations via hook |
| `--vault-address <ADDR>` | Target vault, or `all` for all cluster vaults |

## Emergency Command

```bash
./script/production/ExecuteSolidityScript.sh \
  <cluster_script> \
  --rpc-url <RPC_URL> \
  --batch-via-safe \
  --safe-address <EMERGENCY_SAFE> \
  --vault-address <VAULT_OR_ALL> \
  [--emergency-ltv-collateral] \
  [--emergency-ltv-borrowing] \
  [--emergency-caps] \
  [--emergency-operations]
```

### Example

Disable borrowing against a specific vault and set caps to zero:

```bash
./script/production/ExecuteSolidityScript.sh \
  script/production/mainnet/clusters/PrimeCluster.s.sol \
  --rpc-url mainnet \
  --batch-via-safe \
  --safe-address securityCouncil \
  --vault-address 0xD8b27CF359b7D15710a5BE299AF6e7Bf904984C2 \
  --emergency-ltv-collateral \
  --emergency-caps
```

## After Running Emergency Script

1. Load `SafeBatchBuilder_*.json` from `script/deployments/<name>/<chainId>/output/` into Safe Transaction Builder
2. Coordinate signing with other multisig signers
3. Execute the transaction

---

# Environment Setup

```bash
# Install/update Foundry
foundryup

# Clone repositories
git clone https://github.com/euler-xyz/evk-periphery.git && cd evk-periphery
cd .. && git clone https://github.com/euler-xyz/euler-interfaces.git && cd evk-periphery

# Install dependencies and compile
forge install
forge clean && forge compile
```

> **Note**: Environment variables in `.env` take precedence over command line arguments.
