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
fi

read -p "Provide the deployment name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

if ! script/utils/checkEnvironment.sh $verify_contracts; then
    echo "Environment check failed. Exiting."
    exit 1
fi

if [[ "$@" == *"--dry-run"* ]]; then
    dry_run="--dry-run"
fi

if script/utils/executeForgeScript.sh "$scriptPath" $verify_contracts $dry_run; then
    if [[ $dry_run == "" ]]; then
        deployment_dir="script/deployments/$deployment_name"
        chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)

        mkdir -p "$deployment_dir/broadcast" "$deployment_dir/output"
        cp "broadcast/${scriptName}/$chainId/run-latest.json" "$deployment_dir/broadcast/${scriptName}.json"

        [ -f "script/CoreAddresses.json" ] && mv "script/CoreAddresses.json" "$deployment_dir/output/CoreAddresses.json"
        [ -f "script/PeripheryAddresses.json" ] && mv "script/PeripheryAddresses.json" "$deployment_dir/output/PeripheryAddresses.json"
        [ -f "script/LensAddresses.json" ] && mv "script/LensAddresses.json" "$deployment_dir/output/LensAddresses.json"
    fi
fi
