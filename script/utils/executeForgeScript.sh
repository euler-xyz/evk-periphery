#!/bin/bash

scriptPath=$1
shift

source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval 'set -- $SCRIPT_ARGS'

chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
gasPrice=$(echo "($(cast gas-price --rpc-url "$DEPLOYMENT_RPC_URL") * 1.25)/1" | bc)

if [[ $chainId == "1" ]]; then
    gasPrice=$(echo "if ($gasPrice > 2000000000) $gasPrice else 2000000000" | bc)
fi

if [[ "$@" == *"--verify"* ]]; then
    set -- "${@/--verify/}"
    verify="--verify"
fi

if [[ "$@" == *"--verifier"* ]]; then
    verifier=$(echo "$@" | grep -o '\--verifier [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--verifier $verifier//")
else
    verifier="etherscan"
fi

broadcast="--broadcast"
if [[ "$@" == *"--dry-run"* ]]; then
    set -- "${@/--dry-run/}"
    broadcast=""
fi

if [[ "$@" == *"--safe-address"* ]]; then
    safe_address=$(echo "$@" | grep -o '\--safe-address [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--safe-address $safe_address//")
fi

if [[ "$@" == *"--safe-nonce"* ]]; then
    safe_nonce=$(echo "$@" | grep -o '\--safe-nonce [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--safe-nonce $safe_nonce//")
fi

if [[ "$@" == *"--batch-via-safe"* ]]; then
    set -- "${@/--batch-via-safe/}"
    batch_via_safe="--batch-via-safe"

    if [[ "$@" == *"--use-safe-api"* ]]; then
        set -- "${@/--use-safe-api/}"
        use_safe_api="--use-safe-api"
    fi

    if [[ "$@" != *"--ffi"* ]]; then
        set -- "$@" --ffi
    fi
fi

if [[ "$@" == *"--timelock-address"* ]]; then
    timelock_address=$(echo "$@" | grep -o '\--timelock-address [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--timelock-address $timelock_address//")
fi

if [[ "$@" == *"--no-stub-oracle"* ]]; then
    set -- "${@/--no-stub-oracle/}"
    no_stub_oracle="--no-stub-oracle"
fi

if ! env broadcast=$broadcast safe_address=$safe_address safe_nonce=$safe_nonce batch_via_safe=$batch_via_safe use_safe_api=$use_safe_api timelock_address=$timelock_address no_stub_oracle=$no_stub_oracle \
    forge script script/$scriptPath --rpc-url "$DEPLOYMENT_RPC_URL" $broadcast --legacy --slow --with-gas-price $gasPrice $@; then
    exit 1
fi

if [[ "$verify" == "--verify" && "$broadcast" == "--broadcast" ]]; then
    broadcastFileName=$(basename "${scriptPath%%:*}")

    script/utils/verifyContracts.sh "broadcast/$broadcastFileName/$chainId/run-latest.json" --verifier $verifier
fi
