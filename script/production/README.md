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
- `ADDRESSES_DIR_PATH` (path to the directory containing the addresses of the previously deployed contracts, i.e. euler-interfaces/addresses/1)

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
./script/production/ExecuteSolidityScript.sh <solidity_script_path>
```

i.e.
```sh
./script/production/ExecuteSolidityScript.sh script/production/mainnet/DeployCoreAndPeriphery.s.sol
```

All the contract addresses, which are the result of this deployment, will be stored in `script/deployments/[your_deployment_name]/output`. They will be required for the other scripts to run hence the path to this directory must be provided via `ADDRESSES_DIR_PATH` environment variable in the `.env` file.

### 2. Copy the oracle adapters data in the CSV format into any directory you like
### 3. Deploy the oracle adapters adding them to the Adapters Registry:

```sh
./script/production/DeployOracleAdapters.sh <csv_input_file_path> [<csv_oracle_adapters_addresses_path>]
```

i.e.
```sh
./script/production/DeployOracleAdapters.sh "script/production/mainnet/oracleAdapters/test/Euler V2 Oracles - Chainlink.csv"
```

The above command must be run for each oracle provider/oracle type.

To add the oracle adapters to the Adapters Registry, run the `ConfigWhitelistOracleAdapters.sh` script and providing the `OracleAdaptersAddresses.csv` file path as an argument. The CSV file is the result of running the `DeployOracleAdapters.sh` script and can be found in the deployment directory.

```sh
./script/production/ConfigWhitelistOracleAdapters.sh <csv_file_path>
```

i.e.
```sh
./script/production/ConfigWhitelistOracleAdapters.sh "script/deployments/default/output/OracleAdaptersAddresses.csv"
```

To revoke the adapters from the Adapters Registry, you can run the `ConfigWhitelistOracleAdapters.sh` script and providing the `OracleAdaptersAddresses.csv` with modified `Whitelist` column values set to `No`.

**Important**
To avoid deploying duplicate adapters, one can pass the `OracleAdaptersAddresses.csv` from the previous deployment as an argument (optional). The script will read the deployed adapters from the CSV and will not deploy the duplicate ones.

**Important**
Note that the Cross adapter deployment relies on the previous adapters deployment hence the Cross CSV must either contain appropriate adapters addresses when the script is run or appropriate `OracleAdaptersAddresses.csv` from the previous deployment must be passed as an argument.

### 4. Deploy the initial set of vaults:

```sh
./script/production/ExecuteSolidityScript.sh <solidity_script_path>
```

i.e.
```sh
./script/production/ExecuteSolidityScript.sh script/production/mainnet/DeployInitialVaults.s.sol
```

**Important**
Note that the vaults deployment relies on the deployed oracle adapter addresses. Prepare the `DeployInitialVaults.s.sol` accordingly before running the script.

### 5. Transfer the ownership of the core contracts:

```sh
./script/production/ExecuteSolidityScript.sh <solidity_script_path>
```

i.e.
```sh
./script/production/ExecuteSolidityScript.sh script/production/mainnet/OwnershipTransferCore.s.sol
```

### 6. Transfer the ownership of the periphery contracts:

```sh
./script/production/ExecuteSolidityScript.sh <solidity_script_path>
```

i.e.
```sh
./script/production/ExecuteSolidityScript.sh script/production/mainnet/OwnershipTransferPeriphery.s.sol
```
