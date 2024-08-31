#!/bin/bash

# Check if the file path is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <csv_file_path>"
  exit 1
fi

csv_file="$1"

if ! script/utils/checkEnvironment.sh; then
    echo "Environment check failed. Exiting."
    exit 1
fi

source .env

read -p "Enter the Adapter Registry address: " adapter_registry
read -p "Do you want to perform the operation in a batch? (y/n) (default: y): " is_batch
is_batch=${is_batch:-y}

if [ "$is_batch" == "y" ]; then
    read -p "Enter the EVC address: " evc
fi

onBehalfOf=$(cast wallet address --private-key $DEPLOYER_KEY)
items="["

while IFS=, read -r -a columns || [ -n "$columns" ]; do
    adapterName="${columns[3]}"
    adapter="${columns[4]}"

    if [[ "$adapter" == "Adapter" ]]; then
        continue
    fi

    entry=$(cast call $adapter_registry "entries(address)((uint128,uint128))" $adapter --rpc-url $DEPLOYMENT_RPC_URL)
    addedAt=$(echo $entry | cut -d'(' -f2 | cut -d',' -f1)
    revokedAt=$(echo $entry | cut -d',' -f2 | cut -d')' -f1 | tr -d ' ')

    if [[ $addedAt != "0" && $revokedAt == "0" ]]; then
        if [ "$is_batch" != "y" ]; then
            gasPrice=$(cast gas-price --rpc-url "$DEPLOYMENT_RPC_URL")

            if cast send $adapter_registry "revoke(address)()" $adapter --rpc-url $DEPLOYMENT_RPC_URL --private-key $DEPLOYER_KEY --legacy --gas-price $gasPrice > /dev/null; then
                echo "Successfully revoked adapter $adapterName ($adapter) from the registry."
            else
                echo "Failed to revoke adapter $adapterName ($adapter) from the registry."
            fi
        else
            echo "Adding adapter revoke batch item for adapter $adapterName ($adapter)."
            items+="($adapter_registry,$onBehalfOf,0,$(cast calldata "revoke(address)" $adapter)),"
        fi
    else
        echo "Adapter $adapterName ($adapter) is not added yet to the registry or has been revoked. Skipping..."
    fi
done < <(tr -d '\r' < "$csv_file")

items="${items%,}]"

echo "Executing batch transaction..."
if [ "$is_batch" == "y" ]; then
    if cast send $evc "batch((address,address,uint256,bytes)[])" $items --rpc-url $DEPLOYMENT_RPC_URL --private-key $DEPLOYER_KEY --legacy > /dev/null; then
        echo "Batch transaction successful."
    else
        echo "Batch transaction failed."
    fi
fi
