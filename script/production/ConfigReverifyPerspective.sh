#!/bin/bash

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <old_perspective_address> <new_perspective_address>"
  exit 1
fi

old_perspective="$1"
new_perspective="$2"
shift 2

source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval 'set -- $SCRIPT_ARGS'

addresses_dir_path="${ADDRESSES_DIR_PATH%/}/$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)"
evc=$(jq -r '.evc' "$addresses_dir_path/CoreAddresses.json")

if ! script/utils/checkEnvironment.sh; then
    echo "Environment check failed. Exiting."
    exit 1
fi

broadcast="--broadcast"
if [[ "$@" == *"--dry-run"* ]]; then
    set -- "${@/--dry-run/}"
    broadcast=""
fi

if [ -n "$DEPLOYER_KEY" ]; then
    set -- "$@" --private-key "$DEPLOYER_KEY"
fi

perspectiveName=$(cast call $new_perspective "name()(string)" --rpc-url $DEPLOYMENT_RPC_URL)
vaults=$(cast call $old_perspective "verifiedArray()(address[])" --rpc-url $DEPLOYMENT_RPC_URL)
onBehalfOf=$(cast wallet address $@)
items="["

if [ -z "$onBehalfOf" ]; then
    echo "Cannot retrieve the onBehalfOf address. Exiting..."
    exit 1
fi

for vault in $(echo $vaults | tr -d '[]' | tr ',' ' '); do
    result=$(cast call $new_perspective "perspectiveVerify(address,bool)" $vault true --rpc-url $DEPLOYMENT_RPC_URL --from $onBehalfOf)
    
    if [ "$result" == "0x" ]; then
        echo "Adding 'perspectiveVerify' batch item for vault $vault and perspective $perspectiveName."
        items+="($new_perspective,$onBehalfOf,0,$(cast calldata "perspectiveVerify(address,bool)" $vault true)),"
    else
        echo "Vault $vault cannot be verified by $perspectiveName."
    fi
done

items="${items%,}]"

if [[ "$broadcast" == "" ]]; then
    echo "Dry run. Exiting..."
    exit 0
fi

echo "Executing the batch directly on the EVC..."
chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
gasPrice=$(echo "($(cast gas-price --rpc-url "$DEPLOYMENT_RPC_URL") * 1.25)/1" | bc)

if [[ $chainId == "1" ]]; then
    gasPrice=$(echo "if ($gasPrice > 2000000000) $gasPrice else 2000000000" | bc)
fi

cast send $evc "batch((address,address,uint256,bytes)[])" $items --rpc-url $DEPLOYMENT_RPC_URL --legacy --gas-price $gasPrice $@
