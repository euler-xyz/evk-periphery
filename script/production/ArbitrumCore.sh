#!/bin/bash

function execute_forge_script {
    local scriptName=$1
    local shouldVerify=$2

    if ! forge script script/production/$scriptName --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --slow; then
        exit 1
    fi

    if [[ $shouldVerify == "y" ]]; then
        chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
        broadcastFileName=${scriptName%%:*}

        ./script/utils/verifyContracts.sh "broadcast/$broadcastFileName/$chainId/run-latest.json"
    fi
}

function save_results {
    local scriptName=$1
    local deployment_name=$2
    local deployment_dir="script/deployments/$deployment_name"
    local chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)

    mkdir -p "$deployment_dir"
    cp "broadcast/${scriptName}/$chainId/run-latest.json" "$deployment_dir/${scriptName}.json"
}

if ! command -v jq &> /dev/null; then
    echo "jq could not be found. Please install jq first."
    echo "You can install jq by running: sudo apt-get install jq"
    exit 1
fi

if [[ ! -d "$(pwd)/script" ]]; then
    echo "Error: script directory does not exist in the current directory."
    echo "Please ensure this script is run from the top project directory."
    exit 1
fi

if [[ -f .env ]]; then
    source .env
else
    echo "Error: .env file does not exist. Please create it and try again."
    exit 1
fi

if [ -z "$DEPLOYMENT_RPC_URL" ]; then
    echo "Error: DEPLOYMENT_RPC_URL environment variable is not set. Please set it and try again."
    exit 1
fi

read -p "Do you want to verify the deployed contracts? (y/n) (default: n): " verify_contracts
verify_contracts=${verify_contracts:-n}

read -p "Provide the deployment name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

if [[ $verify_contracts == "y" ]]; then
    if [ -z "$VERIFIER_URL" ]; then
        echo "Error: VERIFIER_URL environment variable is not set. Please set it and try again."
        exit 1
    fi

    if [ -z "$VERIFIER_API_KEY" ]; then
        echo "Error: VERIFIER_API_KEY environment variable is not set. Please set it and try again."
        exit 1
    fi
fi

scriptName="ArbitrumCore.s.sol"
execute_forge_script $scriptName $verify_contracts
save_results $scriptName $deployment_name