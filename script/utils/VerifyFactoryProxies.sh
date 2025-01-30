#!/bin/bash

source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval 'set -- $SCRIPT_ARGS'

if ! script/utils/checkEnvironment.sh; then
    echo "Environment check failed. Exiting."
    exit 1
fi

addresses_dir_path="${ADDRESSES_DIR_PATH%/}/$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)"
factory_perspective=$(jq -r '.evkFactoryPerspective' "$addresses_dir_path/PeripheryAddresses.json")

factoryVaults=$(cast call $factory_perspective "verifiedArray()(address[])" --rpc-url $DEPLOYMENT_RPC_URL)
factoryVaults=($(echo "$factoryVaults" | sed 's/[][]//g' | tr ',' '\n'))

chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
verifier_url_var="VERIFIER_URL_${chainId}"
verifier_url=${VERIFIER_URL:-${!verifier_url_var}}

for contractAddress in "${factoryVaults[@]}"; do
    echo "Verifying proxy contract for address: $contractAddress"
    curl -d "address=$contractAddress" "$verifier_url?module=contract&action=verifyproxycontract&apikey=$VERIFIER_API_KEY"
    echo ""
done
