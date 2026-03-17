#!/bin/bash

show_help() {
    echo "Usage: $0 <solidity_script_path> [options]"
    echo ""
    echo "Execute a Solidity script using Forge with deployment tracking."
    echo ""
    echo "Arguments:"
    echo "  solidity_script_path       Path to the .s.sol script (relative to script/)"
    echo ""
    echo "Options:"
    echo "  --rpc-url <URL|CHAIN_ID>   RPC endpoint, chain ID, or network name (can be comma-separated)"
    echo "  --account <NAME>           Use named Foundry account"
    echo "  --ledger                   Use Ledger hardware wallet"
    echo "  --dry-run                  Simulate without broadcasting"
    echo "  --verify                   Verify contracts after deployment"
    echo "  --verifier <TYPE>          Verifier type (etherscan, blockscout, sourcify, custom)"
    echo "  --batch-via-safe           Execute via Safe multisig"
    echo "  --safe-address <ADDR>      Safe address for batch execution"
    echo "  --timelock-address <ADDR>  Timelock controller address"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 production/CustomScripts.s.sol:GetVaultInfoFull --rpc-url mainnet"
    echo "  $0 production/Cluster.s.sol --rpc-url 1,8453 --dry-run"
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if [ -z "$1" ]; then
    show_help
    exit 1
fi

scriptPath="${1#./}"
scriptPath="${scriptPath#script/}"
scriptName=$(basename "$1")
shift

# Cache --rpc-url option and remove it from arguments
rpc_urls=""
remaining_args=()
i=0
while [ $i -lt $# ]; do
    i=$((i + 1))
    arg="${!i}"
    
    if [ "$arg" = "--rpc-url" ]; then
        i=$((i + 1))
        if [ $i -le $# ]; then
            rpc_urls="${!i}"
        fi
    else
        remaining_args+=("$arg")
    fi
done

# If no --rpc-url specified, create a single-element array with empty string
if [ -z "$rpc_urls" ]; then
    rpc_urls_array=("")
else
    IFS=',' read -ra rpc_urls_array <<< "$rpc_urls"
fi

read -p "Provide the deployment name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

for rpc_url in "${rpc_urls_array[@]}"; do
    source .env
    if [ -n "$rpc_url" ]; then
        eval "$(./script/utils/determineArgs.sh --rpc-url "$rpc_url" "${remaining_args[@]}")"
    else
        eval "$(./script/utils/determineArgs.sh "${remaining_args[@]}")"
    fi
    eval 'set -- $SCRIPT_ARGS'

    if ! script/utils/checkEnvironment.sh "$@"; then
        echo "Environment check failed. Skipping."
        continue
    fi

    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)

    echo "Executing the script for chain id: $chainId"
    if script/utils/executeForgeScript.sh "$scriptPath" "$@"; then
        deployment_dir="script/deployments/$deployment_name/$chainId"
        broadcast_dir="broadcast/${scriptName}/$chainId"
        jsonName="${scriptName%.s.*}"

        if [[ "$@" == *"--dry-run"* ]]; then
            deployment_dir="$deployment_dir/dry-run"
            broadcast_dir="$broadcast_dir/dry-run"
        fi

        mkdir -p "$deployment_dir/broadcast" "$deployment_dir/output"

        if [ -e "$broadcast_dir/run-latest.json" ]; then
            counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/broadcast/${jsonName}.json")
            cp "$broadcast_dir/run-latest.json" "$deployment_dir/broadcast/${jsonName}_${counter}.json"
        fi

        for json_file in script/*.json; do
            [ -e "$json_file" ] || continue
            jsonFileName=$(basename "$json_file")
            counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/output/$jsonFileName")

            mv "$json_file" "$deployment_dir/output/${jsonFileName%.json}_$counter.json"
        done

        for txt_file in script/*.txt; do
            [ -e "$txt_file" ] || continue
            txtFileName=$(basename "$txt_file")
            counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/output/$txtFileName")

            mv "$txt_file" "$deployment_dir/output/${txtFileName%.txt}_$counter.txt"
        done

        for csv_file in script/*.csv; do
            [ -e "$csv_file" ] || continue
            csvFileName=$(basename "$csv_file")
            counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/output/$csvFileName")

            mv "$csv_file" "$deployment_dir/output/${csvFileName%.csv}_$counter.csv"
        done
    else
        for json_file in script/*.json; do
            [ -e "$json_file" ] || continue
            rm "$json_file"
        done
    fi

    unset DEPLOYMENT_RPC_URL
done
