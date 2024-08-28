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

while IFS=, read -r -a columns || [ -n "$columns" ]; do
    adapterName="${columns[3]}"
    adapter="${columns[4]}"
    base="${columns[5]}"
    quote="${columns[6]}"

    if [[ "$adapter" == "Adapter" ]]; then
        continue
    fi

    if [[ "$base" == "" || "$quote" == "" ]]; then
        echo "No base or quote address found for the adapter $adapter. Skipping..."
        continue
    fi

    entry=$(cast call $adapter_registry "entries(address)((uint128,uint128))" $adapter --rpc-url $DEPLOYMENT_RPC_URL)

    if [[ $entry == "(0, 0)" ]]; then
        if cast send $adapter_registry "add(address,address,address)()" $adapter $base $quote --rpc-url $DEPLOYMENT_RPC_URL --private-key $DEPLOYER_KEY > /dev/null; then
            echo "Successfully added adapter $adapterName ($adapter) to the registry."
        else
            echo "Failed to add adapter $adapterName ($adapter) to the registry."
        fi
    else
        echo "Adapter $adapterName ($adapter) is already added to the registry or has been revoked. Skipping..."
    fi
done < <(tr -d '\r' < "$csv_file")
