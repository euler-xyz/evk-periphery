#!/bin/bash

source .env
eval "$(./script/utils/getDeploymentRpcUrl.sh "$@")"
set -- "${@/--rpc-url/}"

scriptPath=$1
shift

chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
gasPrice=$(echo "($(cast gas-price --rpc-url "$DEPLOYMENT_RPC_URL") * 1.25)/1" | bc)

if [[ $chainId == "1" ]]; then
    gasPrice=$(echo "if ($gasPrice > 2000000000) $gasPrice else 2000000000" | bc)
fi

if [[ "$@" == *"--verify"* ]]; then
    set -- "${@/--verify/}"
    verify="--verify"
fi

broadcast="--broadcast"
if [[ "$@" == *"--dry-run"* ]]; then
    set -- "${@/--dry-run/}"
    broadcast=""
fi

if [[ "$@" == *"--force-no-addresses-dir-path"* ]]; then
    set -- "${@/--force-no-addresses-dir-path/}"
    force_no_addresses_dir_path="--force-no-addresses-dir-path"
fi

if [[ "$@" == *"--safe-address"* ]]; then
    safe_address=$(echo "$@" | grep -o '\--safe-address [^ ]*' | cut -d ' ' -f 2)
    set -- "${@/--safe-address $safe_address/}"
fi

if [[ "$@" == *"--batch-via-safe"* ]]; then
    set -- "${@/--batch-via-safe/}"
    batch_via_safe="--batch-via-safe"
    ffi="--ffi"

    if [[ "$@" == *"--use-safe-api"* ]]; then
        set -- "${@/--use-safe-api/}"
        use_safe_api="--use-safe-api"
    fi
fi

if ! env broadcast=$broadcast safe_address=$safe_address batch_via_safe=$batch_via_safe use_safe_api=$use_safe_api \
    force_no_addresses_dir_path=$force_no_addresses_dir_path \
    forge script script/$scriptPath --rpc-url "$DEPLOYMENT_RPC_URL" $ffi $broadcast --legacy --slow --with-gas-price $gasPrice $@; then
    exit 1
fi

if [[ "$verify" == "--verify" ]]; then
    broadcastFileName=$(basename "${scriptPath%%:*}")

    script/utils/verifyContracts.sh "broadcast/$broadcastFileName/$chainId/run-latest.json"
fi
