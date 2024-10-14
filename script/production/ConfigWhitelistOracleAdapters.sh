#!/bin/bash

# Check if the file path is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <csv_file_path>"
  exit 1
fi

source .env

csv_file="$1"
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

onBehalfOf=$(cast wallet address --private-key $DEPLOYER_KEY)
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
        else
            echo "Adapter $adapterName ($adapter) is already added to the registry or has been revoked. Skipping..."
        fi
    elif [[ "$whitelist" == "No" ]]; then
        if [[ $addedAt != "0" && $revokedAt == "0" ]]; then
            echo "Adding 'revoke' batch item for adapter $adapterName ($adapter)."
            items+="($registry,$onBehalfOf,0,$(cast calldata "revoke(address)" $adapter)),"
        else
            echo "Adapter $adapterName ($adapter) is not added yet to the registry or has been revoked. Skipping..."
        fi
    else
        echo "Invalid Whitelist value for adapter $adapterName ($adapter). Skipping..."
    fi
done < <(tr -d '\r' < "$csv_file")

items="${items%,}]"

if [[ "$@" == *"--dry-run"* ]]; then
    echo "Dry run. Exiting..."
    exit 0
fi

echo "Executing batch transaction..."
chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
gasPrice=$(echo "($(cast gas-price --rpc-url "$DEPLOYMENT_RPC_URL") * 1.25)/1" | bc)

if [[ $chainId == "1" ]]; then
    gasPrice=$(echo "if ($gasPrice > 2000000000) $gasPrice else 2000000000" | bc)
fi

if cast send $evc "batch((address,address,uint256,bytes)[])" $items --rpc-url $DEPLOYMENT_RPC_URL --private-key $DEPLOYER_KEY --legacy --gas-price $gasPrice; then
    echo "Batch transaction successful."
else
    echo "Batch transaction failed."
fi
