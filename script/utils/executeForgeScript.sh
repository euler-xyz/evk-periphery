#!/bin/bash

source .env

scriptName=$1
shouldVerify=$2

if ! forge script script/$scriptName --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --slow; then
    exit 1
fi

if [[ $shouldVerify == "y" ]]; then
    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    broadcastFileName=$(basename "${scriptName%%:*}")

    script/utils/verifyContracts.sh "broadcast/$broadcastFileName/$chainId/run-latest.json"
fi
