#!/bin/bash

show_help() {
    echo "Usage: $0 <csv_file_path> <--evk|--earn> [options]"
    echo ""
    echo "Verify or unverify vaults in a Governed Perspective based on a CSV file."
    echo ""
    echo "CSV Format: Vault,Label,Whitelist"
    echo "  - Whitelist: 'Yes' to verify, 'No' to unverify"
    echo ""
    echo "Required:"
    echo "  --evk                      Use EVK Governed Perspective"
    echo "  --earn                     Use Euler Earn Governed Perspective"
    echo ""
    echo "Options:"
    echo "  --rpc-url <URL|CHAIN_ID>   RPC endpoint or chain ID"
    echo "  --account <NAME>           Use named Foundry account"
    echo "  --ledger                   Use Ledger hardware wallet"
    echo "  --batch-via-safe           Execute via Safe multisig"
    echo "  --safe-address <ADDR>      Safe address or alias (DAO, labs, etc.)"
    echo "  --safe-nonce <N>           Override Safe nonce"
    echo "  --dry-run                  Simulate without executing"
    echo "  --verbose                  Show skipped vaults"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Verify EVK vaults directly"
    echo "  $0 vaults.csv --evk --rpc-url mainnet --account DEPLOYER"
    echo ""
    echo "  # Verify Euler Earn vaults via Safe"
    echo "  $0 vaults.csv --earn --rpc-url mainnet --batch-via-safe --safe-address DAO"
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if [ -z "$1" ]; then
    show_help
    exit 1
fi

csv_file="$1"
shift

source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval 'set -- $SCRIPT_ARGS'

addresses_dir_path="${ADDRESSES_DIR_PATH%/}/$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)"
evc=$(jq -r '.evc' "$addresses_dir_path/CoreAddresses.json")

if [[ "$@" != *"--earn"* && "$@" != *"--evk"* ]]; then
    echo "Error: Either --earn or --evk option must be provided"
    echo "Usage: $0 <csv_file_path> [--earn|--evk] [other_options...]"
    exit 1
fi

if [[ "$@" == *"--earn"* ]]; then
    governed_perspective=$(jq -r '.eulerEarnGovernedPerspective' "$addresses_dir_path/PeripheryAddresses.json")
else
    governed_perspective=$(jq -r '.governedPerspective' "$addresses_dir_path/PeripheryAddresses.json")
fi

set -- "${@/--evk/}"
set -- "${@/--earn/}"

if ! script/utils/checkEnvironment.sh "$@"; then
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
    set -- $(echo "$@" | sed "s/--safe-address $safe_address//")
else
    safe_address=$SAFE_ADDRESS
fi

if [[ "$@" == *"--safe-nonce"* ]]; then
    safe_nonce=$(echo "$@" | grep -o '\--safe-nonce [^ ]*' | cut -d ' ' -f 2)
    set -- $(echo "$@" | sed "s/--safe-nonce $safe_nonce//")
else
    safe_nonce=$SAFE_NONCE
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
    label="${columns[1]}"
    whitelist="${columns[2]}"

    if [[ "$vault" == "Vault" ]]; then
        continue
    fi

    isVerified=$(cast call $governed_perspective "isVerified(address)((bool))" $vault --rpc-url $DEPLOYMENT_RPC_URL)

    if [[ "$whitelist" == "Yes" ]]; then
        if [[ $isVerified == *false* ]]; then
            echo "Adding 'perspectiveVerify' batch item for vault $vault ($label)"
            items+="($governed_perspective,$onBehalfOf,0,$(cast calldata "perspectiveVerify(address,bool)" $vault true)),"
        elif [[ "$verbose" == "--verbose" ]]; then
            echo "Vault $vault ($label) is already verified. Skipping..."
        fi
    elif [[ "$whitelist" == "No" ]]; then
        if [[ $isVerified == *true* ]]; then
            echo "Adding 'perspectiveUnverify' batch item for vault $vault ($label)"
            items+="($governed_perspective,$onBehalfOf,0,$(cast calldata "perspectiveUnverify(address)" $vault)),"
        elif [[ "$verbose" == "--verbose" ]]; then
            echo "Vault $vault ($label) is not verified. Skipping..."
        fi
    else
        echo "Invalid Whitelist value for vault $vault ($label). Skipping..."
    fi
done < <(tr -d '\r' < "$csv_file")

items="${items%,}]"

if [[ "$items" == "[]" ]]; then
    echo "No vaults to verify or unverify. Exiting..."
    exit 0
fi

if [[ "$broadcast" == "" ]]; then
    echo "Dry run. Exiting..."
    exit 0
fi

if [[ "$batch_via_safe" == "--batch-via-safe" ]]; then
    echo "Executing the batch via Safe..."
    calldata=$(cast calldata "batch((address,address,uint256,bytes)[])" $items)
    
    if [ -z "$safe_nonce" ]; then
        if [ "$(forge script script/utils/SafeUtils.s.sol:SafeUtil --sig "isTransactionServiceAPIAvailable()" --rpc-url "$DEPLOYMENT_RPC_URL" $@ | grep -oE 'true|false')" != "true" ]; then
            echo "Transaction service API is not available. Failed to get next nonce. Provide it via --safe-nonce or SAFE_NONCE in .env Exiting..."
            exit 1
        fi

        safe_nonce=$(forge script script/utils/SafeUtils.s.sol:SafeUtil --sig "getNextNonce(address)" $safe_address --rpc-url "$DEPLOYMENT_RPC_URL" $ffi $@ | grep -oE '[0-9]+$')
    fi

    if env broadcast=$broadcast safe_address=$safe_address batch_via_safe=$batch_via_safe \
        forge script script/utils/SafeUtils.s.sol:SafeTransaction --sig "create(bool,address,address,uint256,bytes memory,uint256)" true $safe_address $evc 0 $calldata $safe_nonce --rpc-url "$DEPLOYMENT_RPC_URL" $ffi $broadcast --legacy --slow $@; then

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
