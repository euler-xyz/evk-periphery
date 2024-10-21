#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <solidity_script_path>"
  exit 1
fi

source .env
scriptPath="${1#./}"
scriptPath="${scriptPath#script/}"
scriptName=$(basename "$1")
shift

read -p "Provide the deployment name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

if ! script/utils/checkEnvironment.sh "$@"; then
    echo "Environment check failed. Exiting."
    exit 1
fi

if script/utils/executeForgeScript.sh "$scriptPath" "$@"; then
    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    deployment_dir="script/deployments/$deployment_name"
    
    if [[ "$@" == *"--dry-run"* ]]; then
        mkdir -p "$deployment_dir/broadcast" "$deployment_dir/output"
        cp "broadcast/${scriptName}/$chainId/run-latest.json" "$deployment_dir/broadcast/${scriptName}.json"

        for json_file in script/*.json; do
            jsonFileName=$(basename "$json_file")
            counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/output/$jsonFileName")

            mv "$json_file" "$deployment_dir/output/${jsonFileName%.json}_$counter.json"
        done
    else
        mkdir -p "$deployment_dir/dry-run/broadcast"
        cp "broadcast/${scriptName}/$chainId/dry-run/run-latest.json" "$deployment_dir/dry-run/broadcast/${scriptName}.json"

        for json_file in script/*.json; do
            jsonFileName=$(basename "$json_file")
            counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/dry-run/$jsonFileName")

            mv "$json_file" "$deployment_dir/dry-run/${jsonFileName%.json}_$counter.json"
        done
    fi
else
    for json_file in script/*.json; do
        rm "$json_file"
    done
fi
