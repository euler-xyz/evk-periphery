#!/bin/bash

source .env

scriptPath=$1

currentGasPrice=$(cast gas-price --rpc-url "$DEPLOYMENT_RPC_URL")
gasPrice=$(echo "if ($currentGasPrice * 1.25 > 2000000000) ($currentGasPrice * 1.25)/1 else 2000000000" | bc)

if [[ "$@" == *"--broadcast"* ]]; then
    broadcast="--broadcast"
fi

if ! forge script script/$scriptPath --rpc-url "$DEPLOYMENT_RPC_URL" $broadcast --legacy --slow --with-gas-price $gasPrice; then
    exit 1
fi

if [[ "$@" == *"--verify"* ]]; then
    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    broadcastFileName=$(basename "${scriptPath%%:*}")

    script/utils/verifyContracts.sh "broadcast/$broadcastFileName/$chainId/run-latest.json"
fi
