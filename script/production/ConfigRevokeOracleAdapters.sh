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

gasPrice=$(echo "($(cast gas-price --rpc-url "$DEPLOYMENT_RPC_URL") * 1.2)/1" | bc)

while IFS=, read -r -a columns || [ -n "$columns" ]; do
    adapterName="${columns[3]}"
    adapter="${columns[4]}"

    if [[ "$adapter" == "Adapter" ]]; then
        continue
    fi

    cast send $adapter_registry "revoke(address)()" $adapter --rpc-url $DEPLOYMENT_RPC_URL --private-key $DEPLOYER_KEY --legacy --gas-price $gasPrice
done < <(tr -d '\r' < "$csv_file")
