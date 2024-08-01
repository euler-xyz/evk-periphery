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

echo ""
echo "Welcome to the Advanced Deployment script!"
echo "This script will deploy an advanced preset of smart contracts."

if [ -z "$DEPLOYMENT_RPC_URL" ]; then
    echo "Error: DEPLOYMENT_RPC_URL environment variable is not set. Please set it and try again."
    exit 1
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
assets=(ETH 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 0x6B175474E89094C44Da98b954EedeAC495271d0F 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0 0xD533a949740bb3306d119CC777fa900bA034cd52 0x514910771AF9Ca656af840dff83E8264EcF986CA 0xd9Fcd98c322942075A5C3860693e9f4f03AAE07b 0x95ad61b0a150d79219dcf64e1e6cc01f0b64c4ce)
dealAmount=1000000

# Loop through the provided list of asset addresses
for asset in "${assets[@]}"; do
	./script/utils/tenderlyDeal.sh $account $asset $dealAmount
done

# Deploy the advanced preset
scriptName="MainnetAdvanced.s.sol"
if ! forge script script/presets/$scriptName --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --slow; then
    exit 1
fi

if [[ $verify_contracts != "y" ]]; then
    exit 1
fi

# Verify the deployed smart contracts
chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
./script/utils/verifyContracts.sh "./broadcast/$scriptName/$chainId/run-latest.json"
