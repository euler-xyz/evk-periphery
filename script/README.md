# Deployment and management scripts

First, clone the `euler-interfaces` repository in the parent directory of the `evk-periphery` repository:

```sh
cd .. && git clone https://github.com/euler-xyz/euler-interfaces.git && cd evk-periphery
```

This is in order to give the scripts access to the addresses of the already deployed contracts.

Second, create the `.env` file in the root directory of the repository by copying `.env.example`:

```sh
cp .env.example .env
```

It should contain the following environment variables:
- `FORK_RPC_URL` (remote endpoint from which the state will be fetched in case of a local anvil deployment)
- `DEPLOYMENT_RPC_URL` (destination RPC endpoint; use http://127.0.0.1:8545 in case of a local anvil deployment)
- `DEPLOYER_KEY` (the private key which will be used for all the contracts deployments; this will also become a default owner/admin/governor for all the  deployed contracts; this is optional if you provide a different option to derive the deployer key, i.e. `--ledger` or `--account ACC_NAME`)
- `SAFE_KEY` (the private key which will be used to sign Safe transactions; this is optional if you don't send transactions via Safe or provide a different option to derive the Safe signer key, i.e. `--ledger` or `--account ACC_NAME`)
- `SAFE_ADDRESS` (the Safe address which will be used to send transactions via Safe; this is optional if you don't send transactions via Safe. you can use the `--safe-address` option in the command instead. you may also provide the key from the `MultisigAddresses.json` file instead of providing the address)
- `SAFE_NONCE` (the Safe nonce which will be used to send transactions via Safe; this is optional and if not provided, the script will try to retrieve it from the Safe). you can use the `--safe-nonce` option in the command as well
- `VERIFIER_URL` (url of the contract verifier, i.e. https://api.polygonscan.com/api; this is optional and only needed for contracts verification)
- `VERIFIER_API_KEY` (verifier api key; this is optional and only needed for contracts verification)
- `TENDERLY_ACCESS_KEY` (tenderly access key; this is optional and only used for advanced use cases)

## Anvil fork

If you want to deploy on a local anvil fork, load the variables in the `.env` file and spin up the fork:

```sh
source .env && anvil --fork-url "$FORK_RPC_URL"
```

After that, deploy the contracts in a different terminal window.

## Interactive Deployment

To use the interactive deployment script, run the following command:

```sh
./script/interactiveDeployment.sh
```

or with options, i.e.:

```sh
./script/interactiveDeployment.sh --account ACC_NAME --rpc-url RPC_URL
```

You will be walked through the deployment process step by step.

## Batch Deployment

### Core and Periphery contracts deployment and configuration

```sh
./script/interactiveDeployment.sh --account ACC_NAME --rpc-url RPC_URL
```

After that, select option 50 and provide necessary input values.

### Core contracts ownership transfer

```sh
./script/interactiveDeployment.sh --account ACC_NAME --rpc-url RPC_URL
```

After that, select option 51 and provide necessary input values.

### Periphery contracts ownership transfer

```sh
./script/interactiveDeployment.sh --account ACC_NAME --rpc-url RPC_URL
```

After that, select option 52 and provide necessary input values.

### DeployOracleAdapters:

This script takes the oracle adapters data in the CSV format.

```sh
./script/production/DeployOracleAdapters.sh <csv_input_file_path> [csv_oracle_adapters_addresses_path]
```

i.e.
```sh
./script/production/DeployOracleAdapters.sh "script/production/mainnet/oracleAdapters/test/Euler V2 Oracles - Chainlink.csv"
```

To avoid deploying duplicate adapters, you can pass the `OracleAdaptersAddresses.csv` from the previous deployment as an argument (optional). The script will read the deployed adapters from the CSV and will not deploy the duplicate ones.

The above command must be run for each oracle provider/oracle type.

**Important**
Note that the Cross adapter deployment relies on the previous adapters deployment hence the Cross CSV must either contain appropriate adapters addresses when the script is run or appropriate `OracleAdaptersAddresses.csv` from the previous deployment must be passed as an argument.

## Whitelisting

### ConfigWhitelistOracleAdapters

To add the oracle adapters to the Adapters Registry, run the `ConfigWhitelistOracleAdapters.sh` script and providing the `OracleAdaptersAddresses.csv` file path as an argument. The CSV file is the result of running the `DeployOracleAdapters.sh` script and can be found in the deployment directory.

```sh
./script/production/ConfigWhitelistOracleAdapters.sh <csv_file_path>
```

To revoke the adapters from the Adapters Registry, you can run the `ConfigWhitelistOracleAdapters.sh` script and providing the `OracleAdaptersAddresses.csv` with modified `Whitelist` column values set to `No`.

### ConfigWhitelistGovernedPerspective

To whitelist the vaults in the Governed Perspective, run the `ConfigWhitelistGovernedPerspective.sh` script and providing the vaults list CSV file as an argument (i.e. `script/production/mainnet/governedPerspectiveVaults/GovernedPerspectiveVaults.csv`).

```sh
./script/production/ConfigWhitelistGovernedPerspective.sh <csv_file_path>
```

To revoke the vaults from the Governed Perspective, you can run the `ConfigWhitelistGovernedPerspective.sh` script and providing the vaults list CSV file with modified `Whitelist` column values set to `No`.

## Script options

### Verification

You can pass `--verify` option to the deployment script in order to verify the deployed contracts. If you decided not to do it during the deployment, you can do it later. To do that, use the `verifyContracts.sh` script by passing the foundry broadcast file as an argument, i.e.:

```sh
./script/utils/verifyContracts.sh script/deployments/default/1/broadcast/50_CoreAndPeriphery_0.json
```

### Dry run

You can pass `--dry-run` option to the deployment script in order to simulate the deployment without actually executing transactions.

### RPC URL

You can pass the RPC to the script using the `--rpc-url RPC_URL` option.

### Private key management

You can use standard Foundry options for providing the private key to the script, i.e. `--account ACC_NAME` or `--ledger`.

If neither option is provided, the script will look for `DEPLOYER_KEY` in your `.env` file.

### Batch via Safe

You can pass `--batch-via-safe` option to the deployment script in order to create the a batch transaction in the Safe UI. This only works if the result of the script is a transaction to be executed via the EVC batch. For this option to be used, ensure that `SAFE_KEY` and `SAFE_ADDRESS` are defined in the `.env` file or provide a different option to derive the Safe signer key instead, i.e. `--ledger` or `--account ACC_NAME`. The address associated must either be a signer or a delegate of the Safe in order to be able to send the transactions. You can also provide the `--safe-address` option to the command instead of `SAFE_ADDRESS` environment variable.

### Timelock Controller

In case a timelock controller is installed as part of the governor contracts suite, you can additionally pass `--timelock-address` option with the timelock address to the deployment script in order to schedule the transactions in the timelock controller instead of trying to execute them immediately.

### Risk Steward

In case a risk steward contract is installed as part of the governor contracts suite, you can additionally pass `--risk-steward-address` option with the risk steward contract address to the deployment script in order to execute the transactions via the risk steward contract instead of trying to execute it directly.

### Pending transactions simulation

In case there are pending transactions yet to be executed in a multisig or a timelock that affect the state of the vaults, it might be required to simulate those transactions in order to update the state of the fork against which the script is being executed. In order to do that, you can additionally pass `--simulate-safe-address` and `--simulate-timelock-address` with the appropriate addresses.

## Timelock transaction execution

A utility script is provided to execute scheduled timelock transactions automatically. To use it, run:

```sh
./script/production/ExecuteSolidityScript.sh ./script/utils/ExecuteTimelockTx.s.sol --account <ACCOUNT> --timelock-address <TIMELOCK_ADDRESS> --timelock-id <TIMELOCK_ID> --rpc-url <RPC_URL>
```

Required options:
- `--timelock-address`: The address of the timelock controller contract
- `--timelock-id`: The ID of the scheduled transaction, which can be found in the logs emitted when the transaction was scheduled
- `--timelock-salt`: (Optional) The salt used for the timelock operation. If not provided, zero is assumed
