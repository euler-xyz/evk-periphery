#!/bin/bash

# Check if the file path is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <csv_file_path>"
  exit 1
fi

source .env

csv_file="$1"
shift

addresses_dir_path="${ADDRESSES_DIR_PATH%/}"
evc=$(jq -r '.evc' "$addresses_dir_path/CoreAddresses.json")
adapter_registry=$(jq -r '.oracleAdapterRegistry' "$addresses_dir_path/PeripheryAddresses.json")
external_vault_registry=$(jq -r '.externalVaultRegistry' "$addresses_dir_path/PeripheryAddresses.json")

if ! script/utils/checkEnvironment.sh; then
    echo "Environment check failed. Exiting."
    exit 1
fi

echo "The EVC address is: $evc"
echo "The Adapter Registry address is: $adapter_registry"
echo "The External Vault Registry address is: $external_vault_registry"

if [[ "$@" == *"--verbose"* ]]; then
    set -- "${@/--verbose/}"
    verbose="--verbose"
fi

broadcast="--broadcast"
if [[ "$@" == *"--dry-run"* ]]; then
    set -- "${@/--dry-run/}"
    broadcast=""
fi

if [ -n "$DEPLOYER_KEY" ]; then
    set -- "$@" --private-key "$DEPLOYER_KEY"
fi

if [[ "$@" == *"--batch-via-safe"* ]]; then
    read -p "Provide the directory name to store the Safe Transaction data (default: default): " deployment_name        
    deployment_name=${deployment_name:-default}

    if [ -n "$SAFE_KEY" ]; then
        set -- "${@/--private-key/}"
        set -- "$@" --private-key "$SAFE_KEY"
    fi

    if [[ "$@" == *"--account"* && -z "$DEPLOYER_KEY" && -z "$SAFE_KEY" ]]; then
        read -s -p "Enter keystore password: " password
        set -- "$@" --password "$password"
        echo ""
    fi

    onBehalfOf=$SAFE_ADDRESS

    set -- "${@/--batch-via-safe/}"
    batch_via_safe="--batch-via-safe"
    ffi="--ffi"

    if [[ "$@" == *"--use-safe-api"* ]]; then
        set -- "${@/--use-safe-api/}"
        use_safe_api="--use-safe-api"
    fi
else
    onBehalfOf=$(cast wallet address $@)
fi

if [ -z "$onBehalfOf" ]; then
    echo "Cannot retrieve the onBehalfOf address. Exiting..."
    exit 1
fi

items="["

while IFS=, read -r -a columns || [ -n "$columns" ]; do
    provider="${columns[2]}"
    adapterName="${columns[3]}"
    adapter="${columns[4]}"
    base="${columns[5]}"
    quote="${columns[6]}"
    whitelist="${columns[7]}"
    registry=$adapter_registry

    if [[ "$adapter" == "Adapter" ]]; then
        continue
    fi

    if [[ "$provider" == "ExternalVault" ]]; then
        registry=$external_vault_registry
    fi

    entry=$(cast call $registry "entries(address)((uint128,uint128))" $adapter --rpc-url $DEPLOYMENT_RPC_URL)
    addedAt=$(echo $entry | cut -d'(' -f2 | cut -d',' -f1)
    revokedAt=$(echo $entry | cut -d',' -f2 | cut -d')' -f1 | tr -d ' ')

    if [[ "$whitelist" == "Yes" ]]; then
        if [[ "$base" == "" || "$quote" == "" ]]; then
            echo "No base or quote address found for the adapter $adapter. Skipping..."
            continue
        fi

        if [[ $addedAt == "0" && $revokedAt == "0" ]]; then
            echo "Adding 'add' batch item for adapter $adapterName ($adapter)."
            items+="($registry,$onBehalfOf,0,$(cast calldata "add(address,address,address)" $adapter $base $quote)),"
        elif [[ "$verbose" == "--verbose" ]]; then
            echo "Adapter $adapterName ($adapter) is already added to the registry or has been revoked. Skipping..."
        fi
    elif [[ "$whitelist" == "No" ]]; then
        if [[ $addedAt != "0" && $revokedAt == "0" ]]; then
            echo "Adding 'revoke' batch item for adapter $adapterName ($adapter)."
            items+="($registry,$onBehalfOf,0,$(cast calldata "revoke(address)" $adapter)),"
        elif [[ "$verbose" == "--verbose" ]]; then
            echo "Adapter $adapterName ($adapter) is not added yet to the registry or has been revoked. Skipping..."
        fi
    else
        echo "Invalid Whitelist value for adapter $adapterName ($adapter). Skipping..."
    fi
done < <(tr -d '\r' < "$csv_file")

items="${items%,}]"

if [[ "$broadcast" == "" ]]; then
    echo "Dry run. Exiting..."
    exit 0
fi

if [[ "$batch_via_safe" == "--batch-via-safe" ]]; then
    echo "Executing the batch via Safe..."
    calldata=$(cast calldata "batch((address,address,uint256,bytes)[])" $items)
    
    if [ -z "$SAFE_NONCE" ]; then
        nonce=$(forge script script/utils/SafeUtils.s.sol:SafeTransaction --sig "getNonce(address)" $SAFE_ADDRESS --rpc-url "$DEPLOYMENT_RPC_URL" $ffi $@ | grep -oE '[0-9]+$')
    else
        nonce=$SAFE_NONCE
    fi

    nonce=$((nonce + 1))

    if env broadcast=$broadcast batch_via_safe=$batch_via_safe use_safe_api=$use_safe_api \
        forge script script/utils/SafeUtils.s.sol:SafeTransaction --sig "create(address,address,uint256,bytes memory,uint256)" $SAFE_ADDRESS $evc 0 $calldata $nonce --rpc-url "$DEPLOYMENT_RPC_URL" $ffi $broadcast --legacy --slow $@; then
        
        chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
        deployment_dir="script/deployments/$deployment_name/$chainId"
        mkdir -p "$deployment_dir/output"

        for json_file in script/*.json; do
            jsonFileName=$(basename "$json_file")
            counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/output/$jsonFileName")

            mv "$json_file" "$deployment_dir/output/${jsonFileName%.json}_$counter.json"
        done
    fi
else
    echo "Executing batch transaction..."
    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    gasPrice=$(echo "($(cast gas-price --rpc-url "$DEPLOYMENT_RPC_URL") * 1.25)/1" | bc)

    if [[ $chainId == "1" ]]; then
        gasPrice=$(echo "if ($gasPrice > 2000000000) $gasPrice else 2000000000" | bc)
    fi

    cast send $evc "batch((address,address,uint256,bytes)[])" $items --rpc-url $DEPLOYMENT_RPC_URL --legacy --gas-price $gasPrice $@
fi
