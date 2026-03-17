#!/bin/bash

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <safe-files-directory> <cluster-json>"
    exit 1
fi

safeFilesDir=$1
clusterJson=$2

source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval 'set -- $SCRIPT_ARGS'

# Validate inputs
if [ ! -d "$safeFilesDir" ]; then
    echo "Error: Directory $safeFilesDir does not exist"
    exit 1
fi

if [ ! -f "$clusterJson" ]; then
    echo "Error: Cluster JSON file $clusterJson does not exist"
    exit 1
fi

# Create Tenderly testnet and get the network ID
if [ -z "${TENDERLY_VNET_ID:-}" ] || [ -z "${TENDERLY_RPC_URL:-}" ]; then
    eval "$(script/utils/createTenderlyTestnet.sh)"
fi

if [ -z "$TENDERLY_VNET_ID" ] || [ -z "$TENDERLY_RPC_URL" ]; then
    echo "Error: Failed to create Tenderly testnet"
    exit 1
fi

# Check if there are any matching Safe transaction files
if compgen -G "$safeFilesDir/SafeTransaction*.json" > /dev/null; then
    echo "Processing Safe transactions from $safeFilesDir"
    # Process each matching Safe transaction file
    for file in "$safeFilesDir"/SafeTransaction*.json; do
        if [ ! -f "$file" ]; then
            echo "No Safe transaction files found"
            exit 1
        fi

        echo "Processing file: $file"

        safe_address=$(jq -r '.safe' "$file")

        # Prepare the simulation request
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
            '{($addr): {"balance": "0x1000000000000000000"}}')

        request_body=$(jq -n \
            --argjson callArgs "$call_args" \
            --argjson stateOverrides "$state_overrides" \
            '{
                "callArgs": $callArgs,
                "stateOverrides": $stateOverrides
            }')

        # Send simulation request to Tenderly
        response=$(curl --silent --show-error --fail-with-body \
            --request POST \
            --url "https://api.tenderly.co/api/v1/account/euler-labs/project/euler/vnets/$TENDERLY_VNET_ID/transactions" \
            --header 'Accept: application/json' \
            --header 'Content-Type: application/json' \
            --header "X-Access-Key: $TENDERLY_ACCESS_KEY" \
            --data "$request_body")

        # Process the response
        if [ $? -eq 0 ]; then
            simulation_status=$(echo "$response" | jq -r '.simulation.status')
            if [ "$simulation_status" = "true" ]; then
                echo "✅ Simulation successful for $file"
            else
                echo "❌ Simulation failed for $file"
                echo "Error: $(echo "$response" | jq -r '.simulation.error')"
                exit 1
            fi
        else
            echo "❌ Failed to send simulation request for $file"
            echo "Error: $response"
            exit 1
        fi
    done
else
    echo "No Safe transaction files found matching pattern ${safeFilesDir}/SafeTransaction*.json"
fi

CLUSTER_ADDRESSES_PATH=$clusterJson TENDERLY_RPC_URL=$TENDERLY_RPC_URL forge script script/utils/SimulateSafeTxTenderly.s.sol --rpc-url $TENDERLY_RPC_URL --ffi
