#!/bin/bash

source .env

rpc_url=$(echo "$@" | grep -o '\--rpc-url [^ ]*' | cut -d ' ' -f 2)

if echo "$@" | grep -q '\--test-addresses'; then
    EXPORT_ENV_VARS="export ADDRESSES_DIR_PATH=../euler-interfaces/addresses/test"
else
    EXPORT_ENV_VARS="export ADDRESSES_DIR_PATH=../euler-interfaces/addresses"
fi

SCRIPT_ARGS=$(echo "$@" | sed 's/--rpc-url [^ ]* *//' | sed 's/--test-addresses *//')

if [ -z "$DEPLOYMENT_RPC_URL" ] && [ -n "$rpc_url" ]; then
    DEPLOYMENT_RPC_URL=$rpc_url
fi

if [ -z "$DEPLOYMENT_RPC_URL" ]; then
    exit 1
fi

echo "$EXPORT_ENV_VARS"
echo "export SAFE_API_KEY=$SAFE_API_KEY"
echo "export SCRIPT_ARGS='$SCRIPT_ARGS'"

if [ "$DEPLOYMENT_RPC_URL" == "local" ]; then
    echo "export DEPLOYMENT_RPC_URL=http://127.0.0.1:8545"
    exit 0
fi

if ! cast chain-id --rpc-url "$DEPLOYMENT_RPC_URL" &>/dev/null; then
    env_var="DEPLOYMENT_RPC_URL_${DEPLOYMENT_RPC_URL}"

    if [ -n "${!env_var}" ]; then
        echo "export DEPLOYMENT_RPC_URL=${!env_var}"
        exit 0
    else
        chains_data=$(curl -s https://chainid.network/chains_mini.json)

        if [ "$DEPLOYMENT_RPC_URL" = "mainnet" ] || [ "$DEPLOYMENT_RPC_URL" = "ethereum" ]; then
            network_name="ethereum mainnet"
        elif [ "$DEPLOYMENT_RPC_URL" = "optimism" ]; then
            network_name="op mainnet"
        elif [ "$DEPLOYMENT_RPC_URL" = "arbitrum" ]; then
            network_name="arbitrum one"
        elif [ "$DEPLOYMENT_RPC_URL" = "avalanche" ]; then
            network_name="avalanche c-chain"
        elif [ "$DEPLOYMENT_RPC_URL" = "swell" ]; then
            network_name="swellchain"
        else
            network_name=$(echo "$DEPLOYMENT_RPC_URL" | tr '[:upper:]' '[:lower:]')
        fi
        
        if ! [[ "$network_name" =~ ^[0-9]+$ ]]; then
            chain_id=$(echo "$chains_data" | jq -r '
                def words(str): str | ascii_downcase | split(" ");
                def matches(network; search): 
                    (words(search) - words(network)) | length == 0;
                .[] | select(matches(.name; $search)) | .chainId
            ' --arg search "$network_name" | head -n1)
        else
            chain_id=$network_name
            network_name=$(echo "$chains_data" | jq -r ".[] | select(.chainId == $chain_id) | .name" | head -n1 | tr '[:upper:]' '[:lower:]')
        fi

        env_var="DEPLOYMENT_RPC_URL_${chain_id}"

        if [ -n "${!env_var}" ]; then
            echo "export DEPLOYMENT_RPC_URL=${!env_var}"
            exit 0
        fi
    fi
fi

echo "export DEPLOYMENT_RPC_URL=$DEPLOYMENT_RPC_URL"
