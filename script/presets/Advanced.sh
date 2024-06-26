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

echo "Compiling the smart contracts..."
forge compile
if [ $? -ne 0 ]; then
    echo "Compilation failed, retrying..."
    forge compile
    if [ $? -ne 0 ]; then
        echo "Compilation failed again, please check the errors and try again."
        exit 1
    else
        echo "Compilation successful on retry."
    fi
else
    echo "Compilation successful."
fi

echo ""
echo "Welcome to the Advanced Deployment script!"
echo "This script will deploy an advanced preset of smart contracts."

# Check if DEPLOYMENT_RPC_URL environment variable is set
if [ -z "$DEPLOYMENT_RPC_URL" ]; then
    echo "Error: DEPLOYMENT_RPC_URL environment variable is not set. Please set it and try again."
    exit 1
else
    echo "DEPLOYMENT_RPC_URL is set to: $DEPLOYMENT_RPC_URL"
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

# Deal tokens to the deployer account
account=$(cast wallet address --private-key "$DEPLOYER_KEY")
assets=(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 0x6B175474E89094C44Da98b954EedeAC495271d0F 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0 0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b 0x95ad61b0a150d79219dcf64e1e6cc01f0b64c4ce)
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
for asset in "${assets[@]}"; do
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

# Deploy the advanced preset
scriptName="Advanced.s.sol"
if ! forge script script/presets/$scriptName --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --slow; then
    exit 1
fi

if [[ $verify_contracts != "y" ]]; then
    exit 1
fi

# Verify the deployed smart contracts
transactions=$(jq -c '.transactions[]' ./broadcast/$scriptName/1/run-latest.json)

# Iterate over each transaction and verify it
for tx in $transactions; do
    transactionType=$(echo $tx | grep -o '"transactionType":"[^"]*' | grep -o '[^"]*$')
    contractName=$(echo $tx | grep -o '"contractName":"[^"]*' | grep -o '[^"]*$')
    contractAddress=$(echo $tx | grep -o '"contractAddress":"[^"]*' | grep -o '[^"]*$')    

    if [[ $transactionType != "CREATE" || $contractName == "" || $contractAddress == "" ]]; then
        if [[ $transactionType == "CREATE" && ( $contractName != "" || $contractAddress != "" ) ]]; then
            echo "Skipping $contractName: $contractAddress"
        fi
        continue
    fi
    
    verify_command="forge verify-contract $contractAddress $contractName --rpc-url $DEPLOYMENT_RPC_URL --verifier-url $VERIFIER_URL --etherscan-api-key $VERIFIER_API_KEY --skip-is-verified-check --watch"
    
    echo "Verifying $contractName: $contractAddress"
    result=$(eval $verify_command --flatten --force 2>&1)

    if [[ "$result" != *"Contract successfully verified"* ]]; then
        result=$(eval $verify_command 2>&1)

        if [[ "$result" != *"Contract successfully verified"* ]]; then
            echo "Failure"
        fi
    fi
done
