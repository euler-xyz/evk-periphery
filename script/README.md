# Euler Vault Kit deployment scripts

First, create the `.env` file in the root directory of the repository by copying `.env.example`:

```sh
cp .env.example .env
```

It should contain the following environment variables:
- `FORK_RPC_URL` (remote endpoint from which the state will be fetched in case of a local anvil deployment)
- `DEPLOYMENT_RPC_URL` (destination RPC endpoint; use http://127.0.0.1:8545 in case of a local anvil deployment)
- `DEPLOYER_KEY` (the private key which will be used for all the contracts deployments; this will also become an owner/admin/governor for all the  deployed contracts)
- `VERIFIER_URL` (url of the contract verifier, i.e. https://api.polygonscan.com/api)
- `VERIFIER_API_KEY` (verifier api key)

## Anvil fork

If you want to deploy on a local anvil fork, load the variables in the `.env` file and spin up the fork:

```sh
source .env && anvil --fork-url "$FORK_RPC_URL"
```

After that, deploy the contracts in a different terminal window.

## Batch Deployment

Invoke the specific task scripts, i.e.:

DeployCoreAndPeriphery:

```sh
./script/production/DeployCoreAndPeriphery.sh production/mainnet
```

OwnershipTransferCore:

```sh
./script/production/OwnershipTransferCore.sh production/mainnet script/deployments/mainnet/output
```

## Interactive Deployment

To use the interactive deployment script, run the following command:

```sh
./script/interactiveDeployment.sh
```

You will be walked through the deployment process step by step.

The result of the deployment will be saved in `script/deployments/[your_deployment_name]` directory.

## Verification

Each bash script will prompt you whether you would like to verify the contracts. If you decided not to do it during the deployment, you can do it later. To do that, use the `verifyContracts.sh` script by passing the foundry broadcast file as an argument, i.e.:

```sh
./script/utils/verifyContracts.sh script/deployments/mainnet/broadcast/DeployCoreAndPeriphery.s.sol.json
```