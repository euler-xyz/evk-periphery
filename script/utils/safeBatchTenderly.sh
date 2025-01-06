#!/bin/bash

source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval "set -- $SCRIPT_ARGS"

safeFilesDir=${1:-"script"}
safeFilesPrefix=${2:-"SafeTransactionTransformed"}
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
        echo "Failed to extract Tenderly ID or RPC URL from response"
        return 1
    else
        echo "Tenderly ID: $TENDERLY_VNET_ID"
        echo "Tenderly RPC URL: $TENDERLY_RPC_URL"
    fi
else
    echo "Tenderly API request failed with status code: $http_code"
    echo "Response: $response_body"
    return 1
fi

for file in "$safeFilesDir"/$safeFilesPrefix*.json; do
    safe_address=$(jq -r '.safe' "$file")
    
    call_args=$(jq -n \
        --arg from "$safe_address" \
        --arg to "$(jq -r '.to' "$file")" \
        --arg value "0x$(printf '%x' $(jq -r '.value' "$file"))" \
        --arg data "$(jq -r '.data' "$file")" \
        '{
            "from": $from,
            "to": $to,
            "value": $value,
            "data": $data
        }')
    
    state_overrides=$(jq -n \
        --arg addr "$safe_address" \
        '{($addr): {"balance": "0x124125"}}')

    request_body=$(jq -n \
        --argjson callArgs "$call_args" \
        --argjson stateOverrides "$state_overrides" \
        '{
            "callArgs": $callArgs,
            "stateOverrides": $stateOverrides
        }')

    curl --request POST \
        --url https://api.tenderly.co/api/v1/account/euler-labs/project/euler/vnets/$TENDERLY_VNET_ID/transactions \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --header "X-Access-Key: $TENDERLY_ACCESS_KEY" \
        --data "$request_body"
done
