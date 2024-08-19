#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <solidity_script_dir_path> <addresses_dir_path>"
  exit 1
fi

source .env
scriptName="OwnershipTransfer.s.sol"

script_dir="${1#script/}"
core_json_file="$2/CoreAddresses.json"
periphery_json_file="$2/PeripheryAddresses.json"
extra_json_file="$2/ExtraAddresses.json"

dst_core_json_file=script/CoreAddresses.json
dst_periphery_json_file=script/PeripheryAddresses.json
dst_extra_json_file=script/ExtraAddresses.json

read -p "Provide the deployment name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

if ! script/utils/checkEnvironment.sh; then
    echo "Environment check failed. Exiting."
    exit 1
fi

if [[ $2 == http* ]]; then
    curl -o $dst_core_json_file $core_json_file
    curl -o $dst_periphery_json_file $periphery_json_file
    curl -o $dst_extra_json_file $extra_json_file
else
    cp $core_json_file $dst_core_json_file
    cp $periphery_json_file $dst_periphery_json_file
    cp $extra_json_file $dst_extra_json_file
fi

if script/utils/executeForgeScript.sh "$script_dir/$scriptName"; then
    deployment_dir="script/deployments/$deployment_name"
    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)

    mkdir -p "$deployment_dir/broadcast"
    cp "broadcast/${scriptName}/$chainId/run-latest.json" "$deployment_dir/broadcast/${scriptName}.json"
fi

rm $dst_core_json_file
rm $dst_periphery_json_file
rm $dst_extra_json_file