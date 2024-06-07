# Euler Vault Kit deployment scripts

First, create the `.env` file in the root directory of the repository by copying `.env.example`:

```sh
cp .env.example .env
```

It should contain the following environment variables:
- `FORK_RPC_URL` (remote endpoint from which the state will be fetched in case of local anvil deployment)
- `DEPLOYMENT_RPC_URL` (destination RPC endpoint; use http://127.0.0.1:8545 in case of local anvil deployment)
- `DEPLOYER_KEY` (the private key which will be used for all the contracts deployments; this will also become an owner/admin/governor for all the  deployed contracts)

## Anvil fork

If you want to deploy on a local anvil fork, load the variables in the `.env` file and spin up a fork:

```sh
source .env && anvil --fork-url "$FORK_RPC_URL"
```

After that, deploy the contracts in a different terminal window.

## Deployment

The scripts can be used in two modes:
- interactively with the script which prompts for the required inputs
- called directly with appropriate inputs provided via the input json files

## Interactive deployment

To use interactive deployment script, run the following command:

```sh
source .env && ./script/_interactiveDeployment.sh
```

You will be walked through the deployment process step by step. Note that you may need to add execution permissions to the script before running it:

```sh
chmod +x ./script/_interactiveDeployment.sh
```

The result of the deployment will be saved in `script/deployments/[current_block_number]` directory.

## Direct deployment
### Mock ERC20 token deployment

This command deploys mock ERC20 token.

Inputs:
`script/input/00_MockERC20.json`

```sh
source .env && forge script script/00_MockERC20.s.sol --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy
```

Outputs:
`script/output/00_MockERC20.json`

### Periphery Factories deployment

This command deploys:
- Oracle Router Factory
- Oracle Adapter Registry
- Kink IRM Factory

```sh
source .env && forge script script/01_PeripheryFactories.s.sol --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy
```

Outputs:
`script/output/01_PeripheryFactories.json`

### Oracle Adapters

Those commands deploy requested oracle adapters. Supported adapters:
- Chainlink
- Chronicle
- Lido
- Pyth
- Redstone

#### Chainlink
Inputs:
`script/input/02_ChainlinkAdapter.json`

```sh
source .env && forge script script/02_OracleAdapters.s.sol:ChainlinkAdapter --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy
```

Outputs:
`script/output/02_ChainlinkAdapter.json`

#### Chronicle
Inputs:
`script/input/03_ChronicleAdapter.json`

```sh
source .env && forge script script/02_OracleAdapters.s.sol:ChronicleAdapter --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy
```

Outputs:
`script/output/03_ChronicleAdapter.json`

#### Lido
Inputs:
`script/input/04_LidoAdapter.json`

```sh
source .env && forge script script/02_OracleAdapters.s.sol:LidoAdapter --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy
```

Outputs:
`script/output/04_LidoAdapter.json`

#### Pyth
Inputs:
`script/input/05_PythAdapter.json`

```sh
source .env && forge script script/02_OracleAdapters.s.sol:PythAdapter --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy
```

Outputs:
`script/output/05_PythAdapter.json`

#### Redstone
Inputs:
`script/input/06_RedstoneAdapter.json`

```sh
source .env && forge script script/02_OracleAdapters.s.sol:RedstoneAdapter --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy
```

Outputs:
`script/output/06_RedstoneAdapter.json`

### Kink IRM deployment

This command deploys Kink IRM contract.

Inputs:
`script/input/03_KinkIRM.json`

```sh
source .env && forge script script/03_KinkIRM.s.sol --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy
```

Outputs:
`script/output/03_KinkIRM.json`

### Integrations deployment

This command deploys:
- EVC
- Protocol Config
- Sequence Registry
- Balance Tracker
- sets up permit2 contract if needed

```sh
source .env && forge script script/04_Integrations.s.sol --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy
```

Outputs:
`script/output/04_Integrations.json`

### EVault implementation deployment

This command deploys:
- EVault modules contracts
- EVault implementation contract

Inputs:
`script/input/05_EVaultImplementation.json`

```sh
source .env && forge script script/05_EVaultImplementation.s.sol --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy
```

Outputs:
`script/output/05_EVaultImplementation.json`

### EVault Factory deployment

This command deploys EVault Factory contract.

Inputs:
`script/input/06_EVaultFactory.json`

```sh
source .env && forge script script/06_EVaultFactory.s.sol --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy
```

Outputs:
`script/output/06_EVaultFactory.json`

### EVault deployment

This command deploys EVault proxies and dedicated Euler Oracle Router if specified.

Inputs:
`script/input/07_EVault.json`

```sh
source .env && forge script script/07_EVault.s.sol --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy
```

Outputs:
`script/output/07_EVault.json`

### Peripherals

This command deploys:
- Account Lens
- Oracle Lens
- Vault Lens
- Escrow Singleton Perspective
- Cluster Conservative Perspective

```sh
source .env && forge script script/08_Peripherals.s.sol --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy
```

Outputs:
`script/output/08_Peripherals.json`
