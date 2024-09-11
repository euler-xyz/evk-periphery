#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <old_perspective_address> <new_perspective_address>"
  exit 1
fi

source .env

old_perspective="$1"
new_perspective="$2"
addresses_dir_path="${ADDRESSES_DIR_PATH%/}"
evc=$(jq -r '.evc' "$addresses_dir_path/CoreAddresses.json")

if ! script/utils/checkEnvironment.sh; then
    echo "Environment check failed. Exiting."
    exit 1
fi

perspectiveName=$(cast call $new_perspective "name()(string)" --rpc-url $DEPLOYMENT_RPC_URL)
vaults=$(cast call $old_perspective "verifiedArray()(address[])" --rpc-url $DEPLOYMENT_RPC_URL)
onBehalfOf=$(cast wallet address --private-key $DEPLOYER_KEY)
items="["

for vault in $(echo $vaults | tr -d '[]' | tr ',' ' '); do
    result=$(cast call $new_perspective "perspectiveVerify(address,bool)" $vault true --rpc-url $DEPLOYMENT_RPC_URL --private-key $DEPLOYER_KEY)
    
    if [ "$result" == "0x" ]; then
        echo "Adding 'perspectiveVerify' batch item for vault $vault and perspective $perspectiveName."
        items+="($new_perspective,$onBehalfOf,0,$(cast calldata "perspectiveVerify(address,bool)" $vault true)),"
    else
        echo "Vault $vault cannot be verified by $perspectiveName."
    fi
done

items="${items%,}]"

if [[ "$@" == *"--dry-run"* ]]; then
    echo "Dry run. Exiting..."
    exit 0
fi

echo "Executing batch transaction..."
currentGasPrice=$(cast gas-price --rpc-url "$DEPLOYMENT_RPC_URL")
gasPrice=$(echo "if ($currentGasPrice * 1.25 > 2000000000) ($currentGasPrice * 1.25)/1 else 2000000000" | bc)

if cast send $evc "batch((address,address,uint256,bytes)[])" $items --rpc-url $DEPLOYMENT_RPC_URL --private-key $DEPLOYER_KEY --legacy --gas-price $gasPrice; then
    echo "Batch transaction successful."
else
    echo "Batch transaction failed."
fi
