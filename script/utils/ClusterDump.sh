#!/bin/bash

show_help() {
    echo "Usage: $0 <cluster_addresses_json_path> [options]"
    echo ""
    echo "Dump cluster configuration (LTVs, caps, IRMs, oracles) to CSV files."
    echo ""
    echo "Arguments:"
    echo "  cluster_addresses_json_path  Path to the cluster JSON file"
    echo ""
    echo "Options:"
    echo "  --rpc-url <URL|CHAIN_ID>   RPC endpoint or chain ID"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 /path/to/Cluster.json --rpc-url 1"
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if [ -z "$1" ]; then
    echo "Error: Please provide a cluster addresses JSON path"
    show_help
    exit 1
fi

CLUSTER_ADDRESSES_PATH=$1

source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval 'set -- $SCRIPT_ARGS'

if ! script/utils/checkEnvironment.sh "$@"; then
    echo "Environment check failed. Exiting."
    exit 1
fi

read -p "Provide the directory name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

if CLUSTER_ADDRESSES_PATH=$CLUSTER_ADDRESSES_PATH forge script script/utils/ClusterDump.s.sol --rpc-url $DEPLOYMENT_RPC_URL; then
    chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
    deployment_dir="script/deployments/$deployment_name/$chainId"

    mkdir -p "$deployment_dir/output"

    for csv_file in script/*.csv; do
        [ -e "$csv_file" ] || continue
        csvFileName=$(basename "$csv_file")
        mv "$csv_file" "$deployment_dir/output/$csvFileName"
    done
else
    for csv_file in script/*.csv; do
        [ -e "$csv_file" ] || continue
        rm "$csv_file"
    done
fi

