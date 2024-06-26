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

# Check if DEPLOYMENT_RPC_URL environment variable is set
if [ -z "$DEPLOYMENT_RPC_URL" ]; then
    echo "Error: DEPLOYMENT_RPC_URL environment variable is not set. Please set it and try again."
    exit 1
fi

account=$1
asset=$2
dealValue=$3

if [[ $asset == "ETH" ]]; then
    decimals=18
    dealValueCalc=$(echo "obase=16; $dealValue * 10^$decimals" | bc)
    dealValueHex="0x$(printf $dealValueCalc)"

    jsonPayload=$(jq -n \
        --arg account "$account" \
        --arg dealValueHex "$dealValueHex" \
        '{
            "jsonrpc": "2.0",
            "method": "tenderly_setBalance",
            "params": [
                $account,
                $dealValueHex
            ],
            "id": 1
        }')
else
    decimals=$(cast call $asset "decimals()(uint8)" --rpc-url $DEPLOYMENT_RPC_URL)
	dealValueCalc=$(echo "obase=16; $dealValue * 10^$decimals" | bc)
	dealValueHex="0x$(printf $dealValueCalc)"

    jsonPayload=$(jq -n \
		--arg account "$account" \
		--arg asset "$asset" \
		--arg dealValueHex "$dealValueHex" \
		'{
            "jsonrpc": "2.0",
            "method": "tenderly_setErc20Balance",
            "params": [
                $asset,
                $account,
                $dealValueHex
            ],
            "id": 1
        }')
fi

echo "Dealing $asset..."
curl -s -X POST "$DEPLOYMENT_RPC_URL" -H "Content-Type: application/json" -d "$jsonPayload" > /dev/null
