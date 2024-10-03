#!/bin/bash

source .env

scriptPath=$1

chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
gasPrice=$(echo "($(cast gas-price --rpc-url "$DEPLOYMENT_RPC_URL") * 1.25)/1" | bc)

if [[ $chainId == "1" ]]; then
    gasPrice=$(echo "if ($gasPrice > 2000000000) $gasPrice else 2000000000" | bc)
fi

broadcast="--broadcast"
if [[ "$@" == *"--dry-run"* ]]; then
    broadcast=""
fi

if [[ "$@" == *"--batch-via-safe"* ]]; then
    batch_via_safe="--batch-via-safe"
    ffi="--ffi"
fi

if ! env broadcast=$broadcast batch_via_safe=$batch_via_safe forge script script/$scriptPath --rpc-url "$DEPLOYMENT_RPC_URL" $ffi $broadcast --legacy --slow --with-gas-price $gasPrice; then
    exit 1
fi

if [[ "$@" == *"--verify"* ]]; then
    broadcastFileName=$(basename "${scriptPath%%:*}")

    script/utils/verifyContracts.sh "broadcast/$broadcastFileName/$chainId/run-latest.json"
fi
