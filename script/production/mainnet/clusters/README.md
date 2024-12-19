# Cluster Deployment and Management

This README explains how to manage a cluster using the provided scripts.

## Overview

A cluster is a collection of vaults that work together in the system. The `ManageClusterBase.s.sol` contract provides the base functionality for configuring and managing clusters, while specific cluster implementations (like `PrimeCluster.s.sol` or `MEGACluster.s.sol`) define the actual configuration for each cluster.

## Management Process

Refer to the `configureCluster()` function in the specific cluster script file. If no vaults are deployed yet, they will get deployed when the management script is executed for the first time. If the vaults are already deployed, the management script will only apply the delta between the cluster script file configuration and the current state of the cluster.

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

You can pass `--batch-via-safe` option to the deployment script in order to create the a batch transaction in the Safe UI. For this option to be used, ensure that `SAFE_KEY` and `SAFE_ADDRESS` are defined in the `.env` file or provide a different option to derive the Safe signer key instead, i.e. `--ledger` or `--account ACC_NAME`. The address associated must either be a signer or a delegate of the Safe in order to be able to send the transactions. You can also provide the `--safe-address` option to the command instead of `SAFE_ADDRESS`.

`--use-safe-api`: Uses the Safe API to create the transactions in the Safe UI. This option is only valid if the `--batch-via-safe` option is also used. If `--batch-via-safe` is used, but `--use-safe-api` is not used, the script will only create payload dump files that can be used to create the transactions in the Safe UI.

`--verify`: Verifies the deployed contracts (if any) in the blockchain explorer.

## Important Notes

Always try to use the `--dry-run` option first to simulate the transactions and check for any potential issues.
