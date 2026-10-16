#!/bin/bash

scriptPath=$1
shift

# The flag stripping below rebuilds the argument list through unquoted command substitution, and the forge invocation
# expands $@ unquoted. Without this, any argument containing *, ? or [ is silently replaced by matching filenames.
set -f

# see determineArgs.sh: an empty DEPLOYMENT_RPC_URL in .env must not clobber the one the caller already resolved
inherited_deployment_rpc_url=$DEPLOYMENT_RPC_URL
source .env
DEPLOYMENT_RPC_URL=${DEPLOYMENT_RPC_URL:-$inherited_deployment_rpc_url}
eval "$(./script/utils/determineArgs.sh "$@")"
eval 'set -- $SCRIPT_ARGS'

chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
gasPrice=$(echo "($(cast gas-price --rpc-url "$DEPLOYMENT_RPC_URL") * 1.25)/1" | bc)

#if [[ $chainId == "1" ]]; then
#    gasPrice=$(echo "if ($gasPrice > 1000000000) $gasPrice else 1000000000" | bc)
#fi

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

    if [[ "$@" == *"--safe-owner-simulate"* ]]; then
        set -- "${@/--safe-owner-simulate/}"
        safe_owner_simulate="--safe-owner-simulate"
    fi
fi

if [[ "$@" == *"--skip-safe-simulation"* ]]; then
    set -- "${@/--skip-safe-simulation/}"
    skip_safe_simulation="--skip-safe-simulation"
fi

if [[ "$@" == *"--skip-pending-simulation"* ]]; then
    set -- "${@/--skip-pending-simulation/}"
    skip_pending_simulation="--skip-pending-simulation"
fi

if [[ "$@" == *"--simulate-safe-address"* ]]; then
    simulate_safe_address=$(echo "$@" | grep -o '\--simulate-safe-address [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--simulate-safe-address $simulate_safe_address//")
fi

if [[ "$@" == *"--simulate-timelock-address"* ]]; then
    simulate_timelock_address=$(echo "$@" | grep -o '\--simulate-timelock-address [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--simulate-timelock-address $simulate_timelock_address//")
fi

if [[ "$@" == *"--timelock-address"* ]]; then
    timelock_address=$(echo "$@" | grep -o '\--timelock-address [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--timelock-address $timelock_address//")
fi

if [[ "$@" == *"--timelock-id"* ]]; then
    timelock_id=$(echo "$@" | grep -o '\--timelock-id [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--timelock-id $timelock_id//")
fi

if [[ "$@" == *"--timelock-salt"* ]]; then
    timelock_salt=$(echo "$@" | grep -o '\--timelock-salt [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--timelock-salt $timelock_salt//")
fi

if [[ "$@" == *"--risk-steward-address"* ]]; then
    risk_steward_address=$(echo "$@" | grep -o '\--risk-steward-address [^ ]*' | cut -d ' ' -f 2)

    if [[ "$risk_steward_address" == "" ]]; then
        risk_steward_address="default"
    fi

    set -- $(echo "$@" | sed "s/--risk-steward-address $risk_steward_address//")
fi

if [[ "$@" == *"--emergency"* ]]; then
    if [[ "$@" == *"--emergency-ltv-collateral"* ]]; then
        set -- "${@/--emergency-ltv-collateral/}"
        emergency_ltv_collateral="--emergency-ltv-collateral"
    fi

    if [[ "$@" == *"--emergency-ltv-borrowing"* ]]; then
        set -- "${@/--emergency-ltv-borrowing/}"
        emergency_ltv_borrowing="--emergency-ltv-borrowing"
    fi

    if [[ "$@" == *"--emergency-caps"* ]]; then
        set -- "${@/--emergency-caps/}"
        emergency_caps="--emergency-caps"
    fi

    if [[ "$@" == *"--emergency-operations"* ]]; then
        set -- "${@/--emergency-operations/}"
        emergency_operations="--emergency-operations"
    fi

    if [[ "$@" == *"--vault-address"* ]]; then
        vault_address=$(echo "$@" | grep -o '\--vault-address [^ ]*' | cut -d ' ' -f 2)
        set -- $(echo "$@" | sed "s/--vault-address $vault_address//")
    fi
fi

if [[ "$@" == *"--no-stub-oracle"* ]]; then
    set -- "${@/--no-stub-oracle/}"
    no_stub_oracle="--no-stub-oracle"
fi

if [[ "$@" == *"--force-zero-oracle"* ]]; then
    set -- "${@/--force-zero-oracle/}"
    force_zero_oracle="--force-zero-oracle"
fi

if [[ "$@" == *"--skip-oft-config-eul"* ]]; then
    set -- "${@/--skip-oft-config-eul/}"
    skip_oft_config_eul="--skip-oft-config-eul"
fi

if [[ "$@" == *"--check-phased-out-vaults"* ]]; then
    set -- "${@/--check-phased-out-vaults/}"
    check_phased_out_vaults="--check-phased-out-vaults"
fi

if [[ "$@" == *"--from-block"* ]]; then
    from_block=$(echo "$@" | grep -o '\--from-block [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--from-block $from_block//")
fi

if [[ "$@" == *"--to-block"* ]]; then
    to_block=$(echo "$@" | grep -o '\--to-block [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--to-block $to_block//")
fi

if [[ "$@" == *"--source-wallet"* ]]; then
    source_wallet=$(echo "$@" | grep -o '\--source-wallet [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--source-wallet $source_wallet//")
fi

if [[ "$@" == *"--destination-wallet"* ]]; then
    destination_wallet=$(echo "$@" | grep -o '\--destination-wallet [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--destination-wallet $destination_wallet//")
fi

if [[ "$@" == *"--source-account-id"* ]]; then
    source_account_id=$(echo "$@" | grep -o '\--source-account-id [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--source-account-id $source_account_id//")
fi

if [[ "$@" == *"--destination-account-id"* ]]; then
    destination_account_id=$(echo "$@" | grep -o '\--destination-account-id [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--destination-account-id $destination_account_id//")
fi

if [[ "$@" == *"--path "* ]]; then
    path=$(echo "$@" | grep -o -- '--path [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s#--path $path##")
fi

if [[ -n "$safe_address" ]] || [[ -n "$simulate_safe_address" ]] || [[ -n "$path" ]]; then
    if [[ "$@" != *"--ffi"* ]]; then
        set -- "$@" --ffi
    fi
fi

# forge script runs the whole script in simulation before broadcasting anything, and saveAddresses() writes the address
# books during that phase. A broadcast that then fails (out of gas money, RPC rejection, interrupt) would otherwise
# leave euler-interfaces recording addresses for contracts that were never deployed, and those addresses are the
# simulated CREATE addresses, so they can be wrong even after a later successful retry. Snapshot first, roll back on
# failure.
addressesDir=""
bridgeCache=""
snapshotDir=""
addressesDirExisted=false
bridgeCacheExisted=false

if [[ -n "$ADDRESSES_DIR_PATH" && -n "$chainId" && "$broadcast" == "--broadcast" ]]; then
    addressesDir="$ADDRESSES_DIR_PATH/$chainId"
    bridgeCache="$ADDRESSES_DIR_PATH/../config/bridge/BridgeConfigCache.json"
    snapshotDir=$(mktemp -d)

    # snapshot whatever is actually there rather than a list of names, so a new address book added to saveAddresses()
    # is covered without this having to be kept in step
    mkdir -p "$snapshotDir/addresses"

    if [ -d "$addressesDir" ]; then
        addressesDirExisted=true
        cp -R "$addressesDir/." "$snapshotDir/addresses/"
    fi

    if [ -f "$bridgeCache" ]; then
        bridgeCacheExisted=true
        cp "$bridgeCache" "$snapshotDir/BridgeConfigCache.json"
    fi
fi

restore_address_books() {
    [ -z "$snapshotDir" ] && return 0

    # drop anything this run created that was not there beforehand
    if [ -d "$addressesDir" ]; then
        find "$addressesDir" -type f | while read -r f; do
            rel=${f#"$addressesDir"/}
            [ -f "$snapshotDir/addresses/$rel" ] || rm -f "$f"
        done
    fi

    if [ "$addressesDirExisted" = true ]; then
        mkdir -p "$addressesDir"
        cp -R "$snapshotDir/addresses/." "$addressesDir/"
    elif [ -d "$addressesDir" ]; then
        rmdir "$addressesDir" 2>/dev/null
    fi

    if [ "$bridgeCacheExisted" = true ]; then
        cp "$snapshotDir/BridgeConfigCache.json" "$bridgeCache"
    elif [ -f "$bridgeCache" ]; then
        rm -f "$bridgeCache"
    fi

    echo "! Deployment failed; the recorded addresses were rolled back to their previous state."
}

if ! env broadcast=$broadcast safe_address=$safe_address safe_nonce=$safe_nonce batch_via_safe=$batch_via_safe \
    safe_owner_simulate=$safe_owner_simulate skip_safe_simulation=$skip_safe_simulation skip_pending_simulation=$skip_pending_simulation \
    simulate_safe_address=$simulate_safe_address simulate_timelock_address=$simulate_timelock_address \
    timelock_address=$timelock_address timelock_id=$timelock_id timelock_salt=$timelock_salt \
    risk_steward_address=$risk_steward_address path=$path \
    emergency_ltv_collateral=$emergency_ltv_collateral emergency_ltv_borrowing=$emergency_ltv_borrowing \
    emergency_caps=$emergency_caps emergency_operations=$emergency_operations \
    vault_address=$vault_address no_stub_oracle=$no_stub_oracle force_zero_oracle=$force_zero_oracle \
    skip_oft_config_eul=$skip_oft_config_eul \
    check_phased_out_vaults=$check_phased_out_vaults \
    from_block=$from_block to_block=$to_block source_wallet=$source_wallet destination_wallet=$destination_wallet \
    source_account_id=$source_account_id destination_account_id=$destination_account_id \
    forge script script/$scriptPath --rpc-url "$DEPLOYMENT_RPC_URL" $broadcast --legacy --slow --with-gas-price $gasPrice $@; then
    restore_address_books
    [ -n "$snapshotDir" ] && rm -rf "$snapshotDir"
    exit 1
fi

[ -n "$snapshotDir" ] && rm -rf "$snapshotDir"

if [[ "$verify" == "--verify" && "$broadcast" == "--broadcast" ]]; then
    broadcastFileName=$(basename "${scriptPath%%:*}")

    if ! script/utils/verifyContracts.sh "broadcast/$broadcastFileName/$chainId/run-latest.json" --verifier $verifier; then
        echo "! Contract verification reported a failure. The deployment itself succeeded."
    fi
fi

# The contracts are already broadcast at this point, so the exit status must reflect the deployment only. Letting
# verification decide it makes callers discard the deployment records for contracts that are live on chain.
exit 0
