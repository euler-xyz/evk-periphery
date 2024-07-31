#!/bin/bash

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

echo ""
echo "Welcome to the Euler Core Deployment script!"
echo "This script will deploy the Euler core smart contracts."

if [ -z "$DEPLOYMENT_RPC_URL" ]; then
    echo "Error: DEPLOYMENT_RPC_URL environment variable is not set. Please set it and try again."
    exit 1
fi

read -p "Do you want to verify the deployed contracts? (y/n) (default: n): " verify_contracts
verify_contracts=${verify_contracts:-n}

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

# Deploy the core smart contracts
scriptName="ArbitrumCore.s.sol"
if ! forge script script/production/$scriptName --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --slow; then
    exit 1
fi

if [[ $verify_contracts != "y" ]]; then
    exit 1
fi

# Verify the deployed smart contracts
chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
./script/utils/verify.sh "./broadcast/$scriptName/$chainId/run-latest.json"
