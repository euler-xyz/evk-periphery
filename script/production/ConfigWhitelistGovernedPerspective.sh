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
governed_perspective=$(jq -r '.governedPerspective' "$addresses_dir_path/PeripheryAddresses.json")

if ! script/utils/checkEnvironment.sh; then
    echo "Environment check failed. Exiting."
    exit 1
fi

echo "The EVC address is: $evc"
echo "The Governed Perspective address is: $governed_perspective"

onBehalfOf=$(cast wallet address --private-key $DEPLOYER_KEY)
items="["

while IFS=, read -r -a columns || [ -n "$columns" ]; do
    vault="${columns[0]}"
    whitelist="${columns[2]}"

    if [[ "$vault" == "Vault" ]]; then
        continue
    fi

    isVerified=$(cast call $governed_perspective "isVerified(address)((bool))" $vault --rpc-url $DEPLOYMENT_RPC_URL)

    if [[ "$whitelist" == "Yes" ]]; then
        if [[ $isVerified == *false* ]]; then
            echo "Adding 'perspectiveVerify' batch item for vault $vault."
            items+="($governed_perspective,$onBehalfOf,0,$(cast calldata "perspectiveVerify(address,bool)" $vault true)),"
        else
            echo "Vault $vault is already verified. Skipping..."
        fi
    elif [[ "$whitelist" == "No" ]]; then
        if [[ $isVerified == *true* ]]; then
            echo "Adding 'perspectiveUnverify' batch item for vault $vault."
            items+="($governed_perspective,$onBehalfOf,0,$(cast calldata "perspectiveUnverify(address)" $vault)),"
        else
            echo "Vault $vault is not verified. Skipping..."
        fi
    else
        echo "Invalid Whitelist value for vault $vault. Skipping..."
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
