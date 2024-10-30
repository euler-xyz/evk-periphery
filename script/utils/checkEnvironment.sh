#!/bin/bash

source .env

if ! command -v jq &> /dev/null; then
    echo "jq could not be found. Please install jq first."
    echo "You can install jq by running: sudo apt-get install jq"
    exit 1
fi

if [ -z "$DEPLOYMENT_RPC_URL" ]; then
    echo "Error: DEPLOYMENT_RPC_URL environment variable is not set. Please set it and try again."
    exit 1
fi

if [[ $DEPLOYMENT_RPC_URL == "http://127.0.0.1:8545" ]]; then
    if ! pgrep -x "anvil" > /dev/null; then
        echo "Anvil is not running. Please start Anvil and try again."
        echo "You can spin up a local fork with the following command:"
        echo "anvil --fork-url ${FORK_RPC_URL}"
        exit 1
    fi
fi

if [[ "$@" == *"--verify"* ]]; then
    if [ -z "$VERIFIER_URL" ]; then
        echo "Error: VERIFIER_URL environment variable is not set. Please set it and try again."
        exit 1
    fi

    if [ -z "$VERIFIER_API_KEY" ]; then
        echo "Error: VERIFIER_API_KEY environment variable is not set. Please set it and try again."
        exit 1
    fi
fi

if [[ "$@" == *"--batch-via-safe"* ]]; then
    if [ -z "$SAFE_ADDRESS" ]; then
        echo "Error: SAFE_ADDRESS environment variable is not set. Please set it and try again."
        exit 1
    fi
fi
