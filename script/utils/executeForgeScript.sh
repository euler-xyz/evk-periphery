#!/bin/bash

source .env

scriptPath=$1
shouldVerify=$2

if ! forge script script/$scriptPath --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --slow; then
    exit 1
fi

if [[ $shouldVerify == "y" ]]; then
    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    broadcastFileName=$(basename "${scriptPath%%:*}")

    script/utils/verifyContracts.sh "broadcast/$broadcastFileName/$chainId/run-latest.json"
fi
