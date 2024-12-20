#!/bin/bash

source .env
eval "$(./script/utils/getDeploymentRpcUrl.sh "$@")"

if ! script/utils/checkEnvironment.sh; then
    echo "Environment check failed. Exiting."
    exit 1
fi

read -p "Provide the directory name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

if CLUSTER_ADDRESSES_PATH=$1 FORCE_NO_KEY=true forge script script/utils/ClusterDump.s.sol --rpc-url $DEPLOYMENT_RPC_URL; then
    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    deployment_dir="script/deployments/$deployment_name/$chainId"

    mkdir -p "$deployment_dir/output"

    for json_file in script/*.csv; do
        jsonFileName=$(basename "$json_file")
        mv "$json_file" "$deployment_dir/output/$jsonFileName"
    done
else
    for json_file in script/*.csv; do
        rm "$json_file"
    done
fi

