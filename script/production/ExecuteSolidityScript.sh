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
    deployment_dir="script/deployments/$deployment_name/$chainId"
    broadcast_dir="broadcast/${scriptName}/$chainId"
    jsonName="${scriptName%.s.*}"

    if [[ "$@" == *"--dry-run"* ]]; then
        deployment_dir="$deployment_dir/dry-run"
        broadcast_dir="$broadcast_dir/dry-run"
    fi

    mkdir -p "$deployment_dir/broadcast" "$deployment_dir/output"

    counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/broadcast/${jsonName}.json")
    cp "$broadcast_dir/run-latest.json" "$deployment_dir/broadcast/${jsonName}_${counter}.json"

    for json_file in script/*.json; do
        jsonFileName=$(basename "$json_file")
        counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/output/$jsonFileName")

        mv "$json_file" "$deployment_dir/output/${jsonFileName%.json}_$counter.json"
    done
else
    for json_file in script/*.json; do
        rm "$json_file"
    done
fi
