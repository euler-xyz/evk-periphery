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

read -p "Enter the EVC address: " evc
read -p "Enter the Governed Perspective address: " governed_perspective

onBehalfOf=$(cast wallet address --private-key $DEPLOYER_KEY)
items="["

while IFS=, read -r -a columns || [ -n "$columns" ]; do
    vault="${columns[0]}"
    whitelist="${columns[1]}"

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

echo "Executing batch transaction..."
currentGasPrice=$(cast gas-price --rpc-url "$DEPLOYMENT_RPC_URL")
gasPrice=$(echo "if ($currentGasPrice * 1.25 > 2000000000) ($currentGasPrice * 1.25)/1 else 2000000000" | bc)

if cast send $evc "batch((address,address,uint256,bytes)[])" $items --rpc-url $DEPLOYMENT_RPC_URL --private-key $DEPLOYER_KEY --legacy --gas-price $gasPrice; then
    echo "Batch transaction successful."
else
    echo "Batch transaction failed."
fi
