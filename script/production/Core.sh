#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <solidity_script_dir_path>"
  exit 1
fi

script_dir="${1#script/}"

read -p "Do you want to verify the deployed contracts? (y/n) (default: n): " verify_contracts
verify_contracts=${verify_contracts:-n}

read -p "Provide the deployment name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

source .env
scriptName="Core.s.sol"

if ! script/utils/checkEnvironment.sh $verify_contracts; then
    echo "Environment check failed. Exiting."
    exit 1
fi

forge clean && forge compile

if script/utils/executeForgeScript.sh "$script_dir/$scriptName" $verify_contracts; then
    deployment_dir="script/deployments/$deployment_name"
    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)

    mkdir -p "$deployment_dir/broadcast" "$deployment_dir/output"
    cp "broadcast/${scriptName}/$chainId/run-latest.json" "$deployment_dir/broadcast/${scriptName}.json"
    mv "script/CoreInfo.json" "$deployment_dir/output/CoreInfo.json"
fi