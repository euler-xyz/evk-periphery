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
    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    verifier_url_var="VERIFIER_URL_${chainId}"
    verifier_api_key_var="VERIFIER_API_KEY_${chainId}"
    verifier_url=${VERIFIER_URL:-${!verifier_url_var}}

    if [[ $VERIFIER_URL == "" ]]; then
        verifier_api_key=${!verifier_api_key_var}
    else
        verifier_api_key=$VERIFIER_API_KEY
    fi

    if [[ $verifier_url == "" ]] || [[ $verifier_api_key == "" && $verifier_url != *"explorer."* && $verifier_url != *"blockscout."* && $verifier_url != *"snowtrace."* ]]; then
        echo "Error: You must set either:"
        echo "  - both VERIFIER_URL and VERIFIER_API_KEY, or"
        echo "  - both VERIFIER_URL_${chainId} and VERIFIER_API_KEY_${chainId}"
        echo "The verifier key is only required if not using a blockscout or snowtrace verifier"
        exit 1
    fi
fi

if [[ "$@" == *"--batch-via-safe"* ]]; then
    if [ -z "$SAFE_ADDRESS" ]; then
        echo "Error: SAFE_ADDRESS environment variable is not set. Please set it and try again."
        exit 1
    fi
fi
