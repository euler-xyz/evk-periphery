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

### 1. Deploy the core contracts:

```sh
./script/production/Core.sh <solidity_script_dir_path>
```

i.e.
```sh
./script/production/Core.sh script/production/arbitrum
```

The core contracts addresses which are the result of this deployment will be stored in `script/deployments/[your_deployment_name]/output/CoreInfo.json`. They will be required for the other scripts to run but also the Front End team needs those.

### 2. Copy the oracle adapters data in the CSV format into any directory you like
### 3. Deploy the oracle adapters adding them to the Adapters Registry:

```sh
./script/production/OracleAdapters.sh <csv_file_path>
```

i.e.
```sh
./script/production/OracleAdapters.sh "script/production/arbitrum/oracleAdapters/test/Euler V2 Oracles (Arbitrum) - Chainlink.csv"
```

The above command must be run for each oracle provider/oracle type. You will be prompted for the Adapter Registry address which you should have obtained in step 1.

**Important**
Note that the Cross adapter relies on the previous adapters deployment hence the Cross CSV must contain appropriate adapters addresses when the script is run. These can be taken from `script/deployments/[your_deployment_name]/output/adaptersList.csv`

### 4. Deploy the initial set of vaults:

```sh
./script/production/InitialVaults.sh <solidity_script_dir_path> <core_info_json_file_path>
```

i.e.
```sh
./script/production/InitialVaults.sh script/production/arbitrum script/deployments/default/output/CoreInfo.json
```

**Important**
Note that the vaults deployment relies on the deployed oracle adapter addresses. Prepare the `InitialVaults.s.sol` accordingly before running the script.

### 5. Transfer the ownership of the core contracts:

```sh
./script/production/OwnershipTransfer.sh <solidity_script_dir_path> <core_info_json_file_path>
```

i.e.
```sh
./script/production/OwnershipTransfer.sh script/production/arbitrum script/deployments/default/output/CoreInfo.json
```
