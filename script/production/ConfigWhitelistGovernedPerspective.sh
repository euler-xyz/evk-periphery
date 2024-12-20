#!/bin/bash

# Check if the file path is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <csv_file_path>"
  exit 1
fi

source .env
eval "$(./script/utils/getDeploymentRpcUrl.sh "$@")"

csv_file="$1"
shift

addresses_dir_path="${ADDRESSES_DIR_PATH%/}/$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)"
evc=$(jq -r '.evc' "$addresses_dir_path/CoreAddresses.json")
governed_perspective=$(jq -r '.governedPerspective' "$addresses_dir_path/PeripheryAddresses.json")

if ! script/utils/checkEnvironment.sh; then
    echo "Environment check failed. Exiting."
    exit 1
fi

echo "The EVC address is: $evc"
echo "The Governed Perspective address is: $governed_perspective"

if [[ "$@" == *"--verbose"* ]]; then
    set -- "${@/--verbose/}"
    verbose="--verbose"
fi

broadcast="--broadcast"
if [[ "$@" == *"--dry-run"* ]]; then
    set -- "${@/--dry-run/}"
    broadcast=""
fi

if [[ "$@" == *"--safe-address"* ]]; then
    safe_address=$(echo "$@" | grep -o '\--safe-address [^ ]*' | cut -d ' ' -f 2)
    set -- "${@/--safe-address $safe_address/}"
else
    safe_address=$SAFE_ADDRESS
fi

if [ -n "$DEPLOYER_KEY" ]; then
    set -- "$@" --private-key "$DEPLOYER_KEY"
fi

if [[ "$@" == *"--batch-via-safe"* ]]; then
    if [[ ! "$safe_address" =~ ^0x ]]; then
        safe_address=$(jq -r ".[\"$safe_address\"]" "$addresses_dir_path/MultisigAddresses.json")
    fi

    echo "The Safe address is: $safe_address"
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

    onBehalfOf=$safe_address

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

if [[ ! "$onBehalfOf" =~ ^0x ]]; then
    echo "Cannot retrieve the onBehalfOf address. Exiting..."
    exit 1
fi

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
        elif [[ "$verbose" == "--verbose" ]]; then
            echo "Vault $vault is already verified. Skipping..."
        fi
    elif [[ "$whitelist" == "No" ]]; then
        if [[ $isVerified == *true* ]]; then
            echo "Adding 'perspectiveUnverify' batch item for vault $vault."
            items+="($governed_perspective,$onBehalfOf,0,$(cast calldata "perspectiveUnverify(address)" $vault)),"
        elif [[ "$verbose" == "--verbose" ]]; then
            echo "Vault $vault is not verified. Skipping..."
        fi
    else
        echo "Invalid Whitelist value for vault $vault. Skipping..."
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
        nonce=$(forge script script/utils/SafeUtils.s.sol:SafeTransaction --sig "getNextNonce(address)" $safe_address --rpc-url "$DEPLOYMENT_RPC_URL" $ffi $@ | grep -oE '[0-9]+$')
    else
        nonce=$SAFE_NONCE
    fi

    if env broadcast=$broadcast safe_address=$safe_address batch_via_safe=$batch_via_safe use_safe_api=$use_safe_api \
        forge script script/utils/SafeUtils.s.sol:SafeTransaction --sig "create(bool,address,address,uint256,bytes memory,uint256)" true $safe_address $evc 0 $calldata $nonce --rpc-url "$DEPLOYMENT_RPC_URL" $ffi $broadcast --legacy --slow $@; then

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
    echo "Executing the batch directly on the EVC..."
    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    gasPrice=$(echo "($(cast gas-price --rpc-url "$DEPLOYMENT_RPC_URL") * 1.25)/1" | bc)

    if [[ $chainId == "1" ]]; then
        gasPrice=$(echo "if ($gasPrice > 2000000000) $gasPrice else 2000000000" | bc)
    fi

    cast send $evc "batch((address,address,uint256,bytes)[])" $items --rpc-url $DEPLOYMENT_RPC_URL --legacy --gas-price $gasPrice $@
fi
