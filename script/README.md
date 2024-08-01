# Euler Vault Kit deployment scripts

First, create the `.env` file in the root directory of the repository by copying `.env.example`:

```sh
cp .env.example .env
```

It should contain the following environment variables:
- `FORK_RPC_URL` (remote endpoint from which the state will be fetched in case of local anvil deployment)
- `DEPLOYMENT_RPC_URL` (destination RPC endpoint; use http://127.0.0.1:8545 in case of local anvil deployment)
- `DEPLOYER_KEY` (the private key which will be used for all the contracts deployments; this will also become an owner/admin/governor for all the  deployed contracts)
- `VERIFIER_URL` (url of the contract verifier, i.e. https://api.polygonscan.com/api)
- `VERIFIER_API_KEY` (verifier api key)

## Anvil fork

If you want to deploy on a local anvil fork, load the variables in the `.env` file and spin up a fork:

```sh
source .env && anvil --fork-url "$FORK_RPC_URL"
```

After that, deploy the contracts in a different terminal window.

## Deployment

To use the interactive deployment script, run the following command:

```sh
./script/interactiveDeployment.sh
```

You will be walked through the deployment process step by step. Note that you may need to add execution permissions to the script before running it:

```sh
chmod +x ./script/interactiveDeployment.sh
```

The result of the deployment will be saved in `script/deployments/[your_deployment_name]` directory.