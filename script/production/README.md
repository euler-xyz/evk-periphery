# Euler deployment scripts

First, create the `.env` file in the root directory of the repository by copying `.env.example`:

```sh
cp .env.example .env
```

It should contain the following environment variables:
- `FORK_RPC_URL` (remote endpoint from which the state will be fetched in case of a local anvil deployment)
- `DEPLOYMENT_RPC_URL` (destination RPC endpoint; use http://127.0.0.1:8545 in case of a local anvil deployment)
- `DEPLOYER_KEY` (the private key which will be used for all the contracts deployments; this will also become an initial owner/admin/governor for all the  deployed contracts and later transferred)
- `VERIFIER_URL` (url of the contract verifier, i.e. https://api.polygonscan.com/api)
- `VERIFIER_API_KEY` (verifier api key)

## Anvil fork

If you want to deploy on a local anvil fork, load the variables in the `.env` file and spin up the fork:

```sh
source .env && anvil --fork-url "$FORK_RPC_URL"
```

After that, deploy the contracts in a different terminal window.

## Deployment

### Results

The results of the deployment will be saved in `script/deployments/[your_deployment_name]` directory.

### 1. Deploy the core and the periphery contracts:

```sh
./script/production/DeployCoreAndPeriphery.sh <solidity_script_dir_path>
```

i.e.
```sh
./script/production/DeployCoreAndPeriphery.sh script/production/mainnet
```

All the contract addresses, which are the result of this deployment, will be stored in `script/deployments/[your_deployment_name]/output`. They will be required for the other scripts to run (this directory path must be provided) but also the Front End team needs those.

### 2. Copy the oracle adapters data in the CSV format into any directory you like
### 3. Deploy the oracle adapters adding them to the Adapters Registry:

```sh
./script/production/DeployOracleAdapters.sh <csv_file_path> [<adapters_list_path>]
```

i.e.
```sh
./script/production/DeployOracleAdapters.sh "script/production/mainnet/oracleAdapters/test/Euler V2 Oracles - Chainlink.csv"
```

The above command must be run for each oracle provider/oracle type. If you choose to add the oracle adapters to the Adapters Registry while deploying, you will be prompted for the Adapter Registry address which you should have obtained in step 1.

If you decided not to add the oracle adapters to the Adapters Registry, you can add them later by running the `ConfigAddOracleAdapters.sh` script and providing the `adaptersList.csv` file path as an argument. The CSV file is the result of running the `DeployOracleAdapters.sh` script and can be found in the deployment directory.

```sh
./script/production/ConfigAddOracleAdapters.sh <csv_file_path>
```

i.e.
```sh
./script/production/ConfigAddOracleAdapters.sh "script/deployments/default/output/adaptersList.csv"
```

**Important**
Note that the Cross adapter relies on the previous adapters deployment hence the Cross CSV must either contain appropriate adapters addresses when the script is run or appropriate `adaptersList.csv` from the previous deployment must be passed.

### 4. Deploy the initial set of vaults:

```sh
./script/production/DeployInitialVaults.sh <solidity_script_dir_path> <addresses_dir_path>
```

i.e.
```sh
./script/production/DeployInitialVaults.sh script/production/mainnet script/deployments/default/output
```

**Important**
Note that the vaults deployment relies on the deployed oracle adapter addresses. Prepare the `DeployInitialVaults.s.sol` accordingly before running the script.

**Important**
`<addresses_dir_path>` must contain two json files containing the addresses, which are the result of running the `DeployCoreAndPeriphery.sh` script: `CoreAddresses.json` and `PeripheryAddresses.json`.

### 5. Transfer the ownership of the core contracts:

```sh
./script/production/OwnershipTransferCore.sh <solidity_script_dir_path> <addresses_dir_path>
```

i.e.
```sh
./script/production/OwnershipTransferCore.sh script/production/mainnet script/deployments/default/output
```

### 6. Transfer the ownership of the periphery contracts:

```sh
./script/production/OwnershipTransferPeriphery.sh <solidity_script_dir_path> <addresses_dir_path>
```

i.e.
```sh
./script/production/OwnershipTransferPeriphery.sh script/production/mainnet script/deployments/default/output
```
