#!/bin/bash

source .env

scriptPath=$1
shouldVerify=$2
gasPrice=$(echo "($(cast gas-price --rpc-url "$DEPLOYMENT_RPC_URL") * 1.2)/1" | bc)

if ! forge script script/$scriptPath --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy --slow --gas-price $gasPrice; then
    exit 1
fi

if [[ $shouldVerify == "y" ]]; then
    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    broadcastFileName=$(basename "${scriptPath%%:*}")

    script/utils/verifyContracts.sh "broadcast/$broadcastFileName/$chainId/run-latest.json"
fi
