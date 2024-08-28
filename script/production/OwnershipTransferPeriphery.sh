#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <solidity_script_dir_path> <addresses_dir_path>"
  exit 1
fi

source .env
scriptName="OwnershipTransferPeriphery.s.sol"

script_dir="${1#script/}"
addresses_dir_path="${2%/}"
json_file="$addresses_dir_path/PeripheryAddresses.json"
dst_json_file=script/PeripheryAddresses.json

read -p "Provide the deployment name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

if ! script/utils/checkEnvironment.sh; then
    echo "Environment check failed. Exiting."
    exit 1
fi

if [[ $addresses_dir_path == http* ]]; then
    curl -o $dst_json_file $json_file
else
    cp $json_file $dst_json_file
fi

if script/utils/executeForgeScript.sh "$script_dir/$scriptName"; then
    deployment_dir="script/deployments/$deployment_name"
    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)

    mkdir -p "$deployment_dir/broadcast"
    cp "broadcast/${scriptName}/$chainId/run-latest.json" "$deployment_dir/broadcast/${scriptName}.json"
fi

rm $dst_json_file