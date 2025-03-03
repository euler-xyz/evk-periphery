# Cluster Deployment and Management

This README explains how to manage a cluster using the provided scripts.

## Overview

A cluster is a collection of vaults that work together in the system. The `ManageClusterBase.s.sol` contract provides the base functionality for configuring and managing clusters, while specific cluster implementations (like `PrimeCluster.s.sol` or `MEGACluster.s.sol`) define the actual configuration for each cluster.

## Management Process

Refer to the `defineCluster()` and `configureCluster()` functions in the specific cluster script file. If no vaults are deployed yet, they will get deployed when the management script is executed for the first time. If the vaults are already deployed, the management script will only apply the delta between the cluster script file configuration and the current state of the cluster.

Edit the specific cluster file (e.g., `PrimeCluster.s.sol` or `MEGACluster.s.sol`) to set up the desired configuration. Define assets, LTVs, oracle providers, supply caps, borrow caps, IRM parameters, and other settings.

The corresponding `.json` files created in the scripts directory are used as the deployed contracts addresses cache. They are used for further management of the cluster. This is how the existing contract addresses are being loaded into the management script.

## Run the script:

Use the `ExecuteSolidityScript.sh` script to run the management script.

Use the following command:

```bash
./script/production/ExecuteSolidityScript.sh script/production/mainnet/clusters/<ClusterSpecificScript> [options]
```

Replace `<ClusterSpecificScript>` with the cluster specific file name, i.e. `PrimeCluster.s.sol`.

Options:

`--dry-run`: Simulates the deployment without actually executing transactions.

`--batch-via-safe`: Creates a batch payload file that can be used to create a batch transaction in the Safe UI. For this option to be used, ensure that `SAFE_KEY` and `SAFE_ADDRESS` are defined in the `.env` file or provide a different option to derive the Safe signer key instead, i.e. `--ledger` or `--account ACC_NAME`. The address associated must either be a signer or a delegate of the Safe in order to be able to send the transactions. You can also provide the `--safe-address` option to the command instead of `SAFE_ADDRESS`.

`--timelock-address`: Schedules the transactions in the timelock controller provided instead of trying to execute them immediately. This option must be used in case the timelock controller is installed as part of the governor contracts suite.

`--use-safe-api`: Uses the Safe API to create the transactions in the Safe UI. This option is only valid if the `--batch-via-safe` option is also used. If `--batch-via-safe` is used, but `--use-safe-api` is not used, the script will only create payload dump files that can be used to create the transactions in the Safe UI.

`--verify`: Verifies the deployed contracts (if any) in the blockchain explorer.

## Important Notes

Always try to use the `--dry-run` option first to simulate the transactions and check for any potential issues.

# Emergency Cluster Pause

This section assumes that the cluster is governed by the `GovernorAccessControlEmergency` contract with a Safe multisig having an appropriate emergency role granted to it. It also assumes that at least the following environment variables are defined in the `.env` file or their corresponding command line arguments will be provided:

- `DEPLOYMENT_RPC_URL` or `--rpc-url RPC_URL`
- `DEPLOYER_KEY` or `--account ACCOUNT` or `--ledger` (this must be a signer or a delegate of the Safe)
- `SAFE_ADDRESS` or `--safe-address ADDRESS`
- `SAFE_NONCE` or `--safe-nonce NONCE` (this is only necessary if Safe Transaction Service is not available on the network and otherwise may be omitted)

> **IMPORTANT**: Environment variables defined in the `.env` file take precedence over the command line arguments!

## Steps

1. Ensure that you have up to date foundry version installed:

```bash
foundryup
```

If you don't have foundry installed at all, before running `foundryup`, you need to first run:

```bash
curl -L https://foundry.paradigm.xyz | bash
```

2. Clone the repository if you don't have it already:

```bash
git clone https://github.com/euler-xyz/euler-periphery.git && cd euler-periphery
```

3. Ensure that you have up to date dependencies installed:

```bash
forge install
```

4. Do necessary changes in the dedicated cluster script file (e.g. `./script/production/mainnet/clusters/PrimeCluster.s.sol`).

- to reduce the LTVs, search for `cluster.ltvs` and `cluster.externalLTVs` and edit the matrix values accordingly. If only borrow LTVs need to be reduced, search for `cluster.borrowLTVsOverride` and `cluster.externalBorrowLTVsOverride` and define the matrices accordingly.

- to pause vault operations, search for `cluster.hookedOps` and edit it in the following way:
  - to pause all operations for all the vaults in the cluster, use the following value: `32767`
  - to pause all operations except for the liquidations for all the vaults in the cluster, use the following value: `30719`
  - to pause vaults selectively, instead of defining `cluster.hookedOps` value, define `cluster.hookedOpsOverride[SYMBOL]` for each vault you want to pause and use values as described above

- to reduce the supply or borrow caps, search for `cluster.supplyCaps` and `cluster.borrowCaps` and edit the values accordingly

5. Compile the contracts:

```bash
forge clean && forge compile
```

6. Run the script:

If environment variables are defined in the `.env` file:
```bash
./script/production/ExecuteSolidityScript.sh PATH_TO_CLUSTER_SPECIFIC_SCRIPT --batch-via-safe
```

If environment variables are **not** defined in the `.env` file:
```bash
./script/production/ExecuteSolidityScript.sh PATH_TO_CLUSTER_SPECIFIC_SCRIPT --batch-via-safe --rpc-url RPC_URL --account ACCOUNT --safe-address SAFE_ADDRESS
```

Example command for the `PrimeCluster.s.sol` script:

```bash
./script/production/ExecuteSolidityScript.sh script/production/mainnet/clusters/PrimeCluster.s.sol --batch-via-safe
```

7. Create the transaction in the Safe UI. 

If Safe Transaction Service is available you can either add `--use-safe-api` option to the previous command (then the transaction will be automatically created in the Safe UI) or run the `curl` command as displayed in the console output after running the script. The `<payload file>` is created by the script and can be found under the following path: `script/deployments/[YOUR_SPECIFIED_DIRECTORY]/[CHAIN_ID]/output/SafeTransaction_*.json`.

If Safe Transaction Service is not available, use the Safe UI Transaction Builder tool to create the transaction. Select `Custom data` option. Look up the `SafeTransaction_*.json` file. Copy the `to` address from the file and paste it into the `Enter Address` field. The `To Address` field should get automatically filled in with the same address. Put `0` into the `ETH value` field. Copy the `data` field from the file and paste it into the `Data (Hex encoded)` field. Click `Add transaction` and proceed with the transaction creation in the Safe UI.

8. Coordinate signing process with the Safe multisig signers.

9. Execute the transaction in the Safe UI.
