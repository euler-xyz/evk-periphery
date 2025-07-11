#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <solidity_script_path>"
  exit 1
fi

scriptPath="${1#./}"
scriptPath="${scriptPath#script/}"
scriptName=$(basename "$1")
shift

# Cache --rpc-url option and remove it from arguments
rpc_urls=""
remaining_args=()
i=0
while [ $i -lt $# ]; do
    i=$((i + 1))
    arg="${!i}"
    
    if [ "$arg" = "--rpc-url" ]; then
        i=$((i + 1))
        if [ $i -le $# ]; then
            rpc_urls="${!i}"
        fi
    else
        remaining_args+=("$arg")
    fi
done

# If no --rpc-url specified, create a single-element array with empty string
if [ -z "$rpc_urls" ]; then
    rpc_urls_array=("")
else
    IFS=',' read -ra rpc_urls_array <<< "$rpc_urls"
fi

read -p "Provide the deployment name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

for rpc_url in "${rpc_urls_array[@]}"; do
    source .env
    eval "$(./script/utils/determineArgs.sh --rpc-url "$rpc_url" "${remaining_args[@]}")"
    eval 'set -- $SCRIPT_ARGS'

    if ! script/utils/checkEnvironment.sh "$@"; then
        echo "Environment check failed. Skipping."
        continue
    fi

    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)

    echo "Executing the script for chain id: $chainId"
    if script/utils/executeForgeScript.sh "$scriptPath" "$@"; then
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

        for txt_file in script/*.txt; do
            txtFileName=$(basename "$txt_file")
            counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/output/$txtFileName")

            mv "$txt_file" "$deployment_dir/output/${txtFileName%.txt}_$counter.txt"
        done

        for csv_file in script/*.csv; do
            csvFileName=$(basename "$csv_file")
            counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/output/$csvFileName")

            mv "$csv_file" "$deployment_dir/output/${csvFileName%.csv}_$counter.csv"
        done
    else
        for json_file in script/*.json; do
            rm "$json_file"
        done
    fi

    unset DEPLOYMENT_RPC_URL
done
