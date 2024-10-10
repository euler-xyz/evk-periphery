#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <solidity_script_path>"
  exit 1
fi

source .env
scriptPath="${1#./}"
scriptPath="${scriptPath#script/}"
scriptName=$(basename "$1")

read -p "Do you want to verify the deployed contracts? (y/n) (default: n): " verify_contracts
verify_contracts=${verify_contracts:-n}

if [[ $verify_contracts == "y" ]]; then
    verify_contracts="--verify"
else
    verify_contracts=""
fi

read -p "Provide the deployment name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

if [[ "$@" == *"--batch-via-safe"* ]]; then
    batch_via_safe="--batch-via-safe"
fi

if [[ "$@" == *"--dry-run"* ]]; then
    dry_run="--dry-run"
fi

if ! script/utils/checkEnvironment.sh $verify_contracts $batch_via_safe; then
    echo "Environment check failed. Exiting."
    exit 1
fi

if script/utils/executeForgeScript.sh "$scriptPath" $verify_contracts $batch_via_safe $dry_run; then
    deployment_dir="script/deployments/$deployment_name"
    
    if [[ $dry_run == "" ]]; then
        chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)

        mkdir -p "$deployment_dir/broadcast" "$deployment_dir/output"
        cp "broadcast/${scriptName}/$chainId/run-latest.json" "$deployment_dir/broadcast/${scriptName}.json"

        for json_file in script/*.json; do
            jsonFileName=$(basename "$json_file")
            counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/output/$jsonFileName")

            mv "$json_file" "$deployment_dir/output/${jsonFileName%.json}_$counter.json"
        done
    else
        mkdir -p "$deployment_dir/dry_run"

        for json_file in script/*.json; do
            jsonFileName=$(basename "$json_file")
            counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/dry_run/$jsonFileName")

            mv "$json_file" "$deployment_dir/dry_run/${jsonFileName%.json}_$counter.json"
        done
    fi
else
    for json_file in script/*.json; do
        rm "$json_file"
    done
fi
