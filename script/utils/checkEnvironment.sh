#!/bin/bash

source .env

shouldVerify=$1

if ! command -v jq &> /dev/null; then
    echo "jq could not be found. Please install jq first."
    echo "You can install jq by running: sudo apt-get install jq"
    exit 1
fi

if [ -z "$DEPLOYMENT_RPC_URL" ]; then
    echo "Error: DEPLOYMENT_RPC_URL environment variable is not set. Please set it and try again."
    exit 1
fi

if [[ $shouldVerify == "y" ]]; then
    if [ -z "$VERIFIER_URL" ]; then
        echo "Error: VERIFIER_URL environment variable is not set. Please set it and try again."
        exit 1
    fi

    if [ -z "$VERIFIER_API_KEY" ]; then
        echo "Error: VERIFIER_API_KEY environment variable is not set. Please set it and try again."
        exit 1
    fi
fi

forge clean && forge compile