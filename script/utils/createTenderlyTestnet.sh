#!/bin/bash

source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval 'set -- $SCRIPT_ARGS'

chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)

response=$(curl -w "\n%{http_code}" --request POST \
    --url https://api.tenderly.co/api/v1/account/euler-labs/project/euler/vnets \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --header "X-Access-Key: $TENDERLY_ACCESS_KEY" \
    --data '{
        "slug": "deployment_scripts_'$(date +%s)'",
        "fork_config": {
            "network_id": '$chainId',
            "block_number": "latest"
        },
        "virtual_network_config": {
            "chain_config": {
                "chain_id": '$chainId'
            }
        },
        "sync_state_config": {
            "enabled": false
        },
        "explorer_page_config": {
            "enabled": false,
            "verification_visibility": "abi"
        }
    }')

http_code=$(echo "$response" | tail -n1)
response_body=$(echo "$response" | sed \$d)

if [ "$http_code" -eq 200 ]; then
    TENDERLY_VNET_ID=$(echo "$response_body" | jq -r '.id')
    TENDERLY_RPC_URL=$(echo "$response_body" | jq -r '.rpcs[0].url')

    if [ -z "$TENDERLY_VNET_ID" ] || [ -z "$TENDERLY_RPC_URL" ]; then
        echo "Failed to extract Tenderly ID or RPC URL from response" >&2
        exit 1
    else
        echo "TENDERLY_VNET_ID='$TENDERLY_VNET_ID'"
        echo "TENDERLY_RPC_URL='$TENDERLY_RPC_URL'"
    fi
else
    echo "Tenderly API request failed with status code: $http_code" >&2
    echo "Response: $response_body" >&2
    exit 1
fi
