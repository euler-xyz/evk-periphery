#!/bin/bash

if ! command -v jq &> /dev/null
then
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
    echo ".env file loaded successfully."
else
    echo "Error: .env file does not exist. Please create it and try again."
    exit 1
fi

echo ""
echo "Welcome to the Tenderly deal script!"
echo "This script will deal tokens to the specified account."

# Check if DEPLOYMENT_RPC_URL environment variable is set
if [ -z "$DEPLOYMENT_RPC_URL" ]; then
    echo "Error: DEPLOYMENT_RPC_URL environment variable is not set. Please set it and try again."
    exit 1
else
    echo "DEPLOYMENT_RPC_URL is set to: $DEPLOYMENT_RPC_URL"
fi

# Check if an account address is provided as the first input parameter
if [ -z "$1" ]; then
    echo "Error: No account address provided. Please provide an account address as the first input parameter."
    exit 1
else
    account=$1
fi

# Check if a list of token addresses is provided as the second input parameter
if [ -z "$2" ]; then
    echo "Error: No asset addresses provided. Please provide a list of asset addresses as the second input parameter."
    exit 1
else
    IFS=',' read -r -a assetAddresses <<< "${2//[\[\]]/}"
fi

echo ""
echo "Trying to deal the tokens to $account..."

dealValue=1000000
decimals=18
dealValueCalc=$(echo "obase=16; $dealValue * 10^$decimals" | bc)
dealValueHex="0x$(printf $dealValueCalc)"

# fund ETH first
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

echo "Dealing ETH..."
curl -s -X POST "$DEPLOYMENT_RPC_URL" -H "Content-Type: application/json" -d "$jsonPayload" > /dev/null

# Loop through the provided list of asset addresses
for asset in "${assetAddresses[@]}"; do
	decimals=$(cast call $asset "decimals()(uint8)" --rpc-url $DEPLOYMENT_RPC_URL)

	dealValueCalc=$(echo "obase=16; $dealValue * 10^$decimals" | bc)
	dealValueHex="0x$(printf $dealValueCalc)"

	# Construct the JSON payload
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

	echo "Dealing $asset..."
	curl -s -X POST "$DEPLOYMENT_RPC_URL" -H "Content-Type: application/json" -d "$jsonPayload" > /dev/null
done

echo Done