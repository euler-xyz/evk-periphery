#!/bin/bash

if ! script/utils/checkEnvironment.sh; then
    echo "Environment check failed. Exiting."
    exit 1
fi

source .env

addresses_dir_path="${ADDRESSES_DIR_PATH%/}"
factory_perspective=$(jq -r '.evkFactoryPerspective' "$addresses_dir_path/PeripheryAddresses.json")

factoryVaults=$(cast call $factory_perspective "verifiedArray()(address[])" --rpc-url $DEPLOYMENT_RPC_URL)
factoryVaults=($(echo "$factoryVaults" | sed 's/[][]//g' | tr ',' '\n'))

for contractAddress in "${factoryVaults[@]}"; do
    echo "Verifying proxy contract for address: $contractAddress"
    curl -d "address=$contractAddress" "$VERIFIER_URL?module=contract&action=verifyproxycontract&apikey=$VERIFIER_API_KEY"
    echo ""
done
