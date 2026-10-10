#!/usr/bin/env bash

set -euo pipefail

usage() {
    printf '%s\n' \
        'Usage:' \
        '  plan.sh --input FILE --output DIR --rpc-url URL --addresses-dir DIR' \
        '    --route-kind KIND [route options]' \
        '' \
        'Required:' \
        '  --input FILE             DynamicCluster JSON input.' \
        '  --output DIR             New or empty request-scoped artifact directory.' \
        '  --rpc-url URL            RPC endpoint used only for exact-state simulation.' \
        '  --addresses-dir DIR      Euler interfaces addresses root.' \
        '  --route-kind KIND        deployer-direct, direct, safe, safe-timelock,' \
        '                           timelock, risk-steward, or emergency.' \
        '' \
        'Route options:' \
        '  --safe-address ADDRESS' \
        '  --safe-nonce NONCE' \
        '  --timelock-address ADDRESS' \
        '  --risk-steward-address ADDRESS' \
        '  --emergency-kind ltv-collateral|ltv-borrowing|caps|operations' \
        '  --emergency-vault ADDRESS|all' \
        '  --skip-safe-simulation' \
        '' \
        'This command never signs or broadcasts. Route values are controlled-provider' \
        'configuration, not browser-supplied Market Ops intent.'
}

fail() {
    printf 'market-ops planner: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

absolute_file() {
    local path=$1
    local directory
    directory=$(cd "$(dirname "$path")" && pwd -P)
    printf '%s/%s\n' "$directory" "$(basename "$path")"
}

input_path=""
output_dir=""
rpc_url=""
addresses_dir=""
route_kind=""
safe_address=""
safe_nonce=""
timelock_address=""
risk_steward_address=""
emergency_kind=""
emergency_vault=""
skip_safe_simulation=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --input|--output|--rpc-url|--addresses-dir|--route-kind|--safe-address|--safe-nonce|--timelock-address|--risk-steward-address|--emergency-kind|--emergency-vault)
            [[ $# -ge 2 ]] || fail "missing value for $1"
            case "$1" in
                --input) input_path=$2 ;;
                --output) output_dir=$2 ;;
                --rpc-url) rpc_url=$2 ;;
                --addresses-dir) addresses_dir=$2 ;;
                --route-kind) route_kind=$2 ;;
                --safe-address) safe_address=$2 ;;
                --safe-nonce) safe_nonce=$2 ;;
                --timelock-address) timelock_address=$2 ;;
                --risk-steward-address) risk_steward_address=$2 ;;
                --emergency-kind) emergency_kind=$2 ;;
                --emergency-vault) emergency_vault=$2 ;;
            esac
            shift 2
            ;;
        --skip-safe-simulation)
            skip_safe_simulation="--skip-safe-simulation"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unsupported option: $1"
            ;;
    esac
done

[[ -n "$input_path" ]] || fail "--input is required"
[[ -n "$output_dir" ]] || fail "--output is required"
[[ -n "$rpc_url" ]] || fail "--rpc-url is required"
[[ -n "$addresses_dir" ]] || fail "--addresses-dir is required"
[[ -n "$route_kind" ]] || fail "--route-kind is required"

require_command cast
require_command cmp
require_command forge
require_command git
require_command jq

[[ -f "$input_path" ]] || fail "input file does not exist"
[[ -d "$addresses_dir" ]] || fail "addresses directory does not exist"

repo_root=$(git rev-parse --show-toplevel)
input_path=$(absolute_file "$input_path")
addresses_dir=$(cd "$addresses_dir" && pwd -P)
if [[ -e "$output_dir" ]]; then
    [[ -d "$output_dir" ]] || fail "output path is not a directory"
    [[ -z "$(find "$output_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]] \
        || fail "output directory must be empty"
else
    mkdir -p "$output_dir"
fi
output_dir=$(cd "$output_dir" && pwd -P)

schema=$(jq -er '.schema' "$input_path")
[[ "$schema" == "evk-market-ops-cluster-input-v1" ]] || fail "unsupported input schema"
source_commit=$(jq -er '.sourceCommit' "$input_path")
request_hash=$(jq -er '.requestHash' "$input_path")
chain_id=$(jq -er '.chainId' "$input_path")
block_number=$(jq -er '.blockNumber' "$input_path")
block_hash=$(jq -er '.blockHash | ascii_downcase' "$input_path")
deployer=$(jq -er '.deployer' "$input_path")

[[ "$source_commit" =~ ^[0-9a-f]{40}$ ]] || fail "input source commit is invalid"
[[ "$request_hash" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "input request hash is invalid"
[[ "$chain_id" =~ ^[1-9][0-9]*$ ]] || fail "input chain ID is invalid"
[[ "$block_number" =~ ^[1-9][0-9]*$ ]] || fail "input block number is invalid"
[[ "$block_hash" =~ ^0x[0-9a-f]{64}$ ]] || fail "input block hash is invalid"
[[ "$deployer" =~ ^0x[0-9a-fA-F]{40}$ ]] || fail "input deployer is invalid"
input_size=$(wc -c < "$input_path")
[[ "$input_size" -le 5242880 ]] || fail "input file exceeds 5 MiB"
if [[ -n "$safe_nonce" ]]; then
    [[ "$safe_nonce" =~ ^[0-9]+$ ]] || fail "safe nonce is invalid"
fi

head_commit=$(git -C "$repo_root" rev-parse HEAD)
[[ "$source_commit" == "$head_commit" ]] || fail "input source commit does not match this EVK checkout"
[[ -z "$(git -C "$repo_root" status --porcelain --untracked-files=all --ignore-submodules=dirty)" ]] \
    || fail "EVK source worktree is dirty"

rpc_chain_id=$(cast chain-id --rpc-url "$rpc_url")
[[ "$rpc_chain_id" == "$chain_id" ]] || fail "RPC chain does not match input"
block_hex=$(printf '0x%x' "$block_number")
rpc_block=$(cast rpc --rpc-url "$rpc_url" eth_getBlockByNumber "$block_hex" false)
rpc_block_hash=$(printf '%s' "$rpc_block" | jq -er '.hash | ascii_downcase')
[[ "$rpc_block_hash" == "$block_hash" ]] || fail "RPC block hash does not match input"

batch_via_safe=""
emergency_ltv_collateral=""
emergency_ltv_borrowing=""
emergency_caps=""
emergency_operations=""

case "$route_kind" in
    deployer-direct|direct)
        [[ -z "$safe_address$timelock_address$risk_steward_address$emergency_kind$emergency_vault" ]] \
            || fail "direct route contains incompatible route options"
        ;;
    safe)
        [[ "$safe_address" =~ ^0x[0-9a-fA-F]{40}$ ]] || fail "safe route requires --safe-address"
        [[ -n "$safe_nonce" ]] || fail "safe route requires --safe-nonce, including an explicit zero"
        [[ -z "$timelock_address$risk_steward_address$emergency_kind$emergency_vault" ]] \
            || fail "safe route contains incompatible route options"
        batch_via_safe="--batch-via-safe"
        ;;
    safe-timelock)
        [[ "$safe_address" =~ ^0x[0-9a-fA-F]{40}$ ]] || fail "safe timelock route requires --safe-address"
        [[ -n "$safe_nonce" ]] || fail "safe timelock route requires --safe-nonce, including an explicit zero"
        [[ "$timelock_address" =~ ^0x[0-9a-fA-F]{40}$ ]] || fail "safe timelock route requires --timelock-address"
        [[ -z "$risk_steward_address$emergency_kind$emergency_vault" ]] \
            || fail "safe timelock route contains incompatible route options"
        batch_via_safe="--batch-via-safe"
        ;;
    timelock)
        [[ "$timelock_address" =~ ^0x[0-9a-fA-F]{40}$ ]] || fail "timelock route requires --timelock-address"
        [[ -z "$safe_address$risk_steward_address$emergency_kind$emergency_vault" ]] \
            || fail "timelock route contains incompatible route options"
        ;;
    risk-steward)
        [[ "$risk_steward_address" =~ ^0x[0-9a-fA-F]{40}$ ]] \
            || fail "risk steward route requires --risk-steward-address"
        [[ -z "$emergency_kind$emergency_vault" ]] \
            || fail "risk steward route contains emergency options"
        if [[ -n "$safe_address" ]]; then
            [[ "$safe_address" =~ ^0x[0-9a-fA-F]{40}$ ]] || fail "safe address is invalid"
            [[ -n "$safe_nonce" ]] || fail "Safe-backed risk steward route requires --safe-nonce"
            batch_via_safe="--batch-via-safe"
        fi
        if [[ -n "$timelock_address" ]]; then
            [[ "$timelock_address" =~ ^0x[0-9a-fA-F]{40}$ ]] || fail "timelock address is invalid"
        fi
        ;;
    emergency)
        [[ "$emergency_vault" == "all" || "$emergency_vault" =~ ^0x[0-9a-fA-F]{40}$ ]] \
            || fail "emergency route requires --emergency-vault ADDRESS|all"
        case "$emergency_kind" in
            ltv-collateral) emergency_ltv_collateral="--emergency-ltv-collateral" ;;
            ltv-borrowing) emergency_ltv_borrowing="--emergency-ltv-borrowing" ;;
            caps) emergency_caps="--emergency-caps" ;;
            operations) emergency_operations="--emergency-operations" ;;
            *) fail "emergency route requires a supported --emergency-kind" ;;
        esac
        [[ -z "$timelock_address$risk_steward_address" ]] \
            || fail "emergency route contains incompatible route options"
        if [[ -n "$safe_address" ]]; then
            [[ "$safe_address" =~ ^0x[0-9a-fA-F]{40}$ ]] || fail "safe address is invalid"
            [[ -n "$safe_nonce" ]] || fail "Safe-backed emergency route requires --safe-nonce"
            batch_via_safe="--batch-via-safe"
        fi
        ;;
    *)
        fail "unsupported route kind: $route_kind"
        ;;
esac

safe_nonce=${safe_nonce:-0}
safe_nonce_explicit=false
if [[ -n "$safe_address" ]]; then
    safe_nonce_explicit=true
fi

mkdir -p "$repo_root/out"
provider_work_dir=$(mktemp -d "$repo_root/out/market-ops-planner.XXXXXX")
cleanup() {
    rm -rf "$provider_work_dir"
}
trap cleanup EXIT HUP INT TERM

provider_input_path="$provider_work_dir/request.json"
provider_output_dir="$provider_work_dir/artifacts"
provider_cache_dir="$provider_work_dir/cache"
provider_broadcast_dir="$provider_work_dir/broadcast"
cp "$input_path" "$provider_input_path"
cmp -s "$input_path" "$provider_input_path" || fail "failed to stage an exact input copy"
mkdir "$provider_output_dir" "$provider_cache_dir" "$provider_broadcast_dir"
if [[ -f "$repo_root/cache/solidity-files-cache.json" ]]; then
    cp "$repo_root/cache/solidity-files-cache.json" "$provider_cache_dir/solidity-files-cache.json"
fi

cd "$repo_root"
env \
    -u DEPLOYER_KEY \
    -u SAFE_KEY \
    ADDRESSES_DIR_PATH="$addresses_dir" \
    DEPLOYMENT_RPC_URL="$rpc_url" \
    FOUNDRY_BROADCAST="$provider_broadcast_dir" \
    FOUNDRY_CACHE_PATH="$provider_cache_dir" \
    MARKET_OPS_CLUSTER_INPUT="$provider_input_path" \
    MARKET_OPS_DEPLOYER="$deployer" \
    MARKET_OPS_FORK_BLOCK_NUMBER="$block_number" \
    MARKET_OPS_ROUTE_KIND="$route_kind" \
    MARKET_OPS_SAFE_NONCE_EXPLICIT="$safe_nonce_explicit" \
    SCRIPT_OUTPUT_DIR="$provider_output_dir" \
    batch_via_safe="$batch_via_safe" \
    broadcast="" \
    emergency_caps="$emergency_caps" \
    emergency_ltv_borrowing="$emergency_ltv_borrowing" \
    emergency_ltv_collateral="$emergency_ltv_collateral" \
    emergency_operations="$emergency_operations" \
    risk_steward_address="$risk_steward_address" \
    safe_address="$safe_address" \
    safe_nonce="$safe_nonce" \
    skip_pending_simulation="--skip-pending-simulation" \
    skip_safe_simulation="$skip_safe_simulation" \
    timelock_address="$timelock_address" \
    vault_address="$emergency_vault" \
    forge script \
        script/production/market-ops/DynamicCluster.s.sol:DynamicCluster \
        --rpc-url "$rpc_url"

provider_manifest="$provider_output_dir/MarketOpsManifest.json"
[[ -f "$provider_output_dir/Batches.json" ]] || fail "EVK did not emit Batches.json"
[[ -f "$provider_output_dir/Cluster.json" ]] || fail "EVK did not emit Cluster.json"
[[ -f "$provider_manifest" ]] || fail "EVK did not emit MarketOpsManifest.json"
[[ "$(jq -er '.broadcast' "$provider_manifest")" == "false" ]] \
    || fail "manifest unexpectedly reports broadcast"
[[ "$(jq -er '.requestHash' "$provider_manifest")" == "$request_hash" ]] \
    || fail "manifest request hash mismatch"
[[ "$(jq -er '.routeKind' "$provider_manifest")" == "$route_kind" ]] \
    || fail "manifest route mismatch"
jq -e '.batchesHash | test("^0x[0-9a-f]{64}$")' "$provider_manifest" >/dev/null \
    || fail "manifest batches hash is invalid"
jq -e '.clusterHash | test("^0x[0-9a-f]{64}$")' "$provider_manifest" >/dev/null \
    || fail "manifest cluster hash is invalid"

cp -R "$provider_output_dir"/. "$output_dir"/
manifest="$output_dir/MarketOpsManifest.json"
[[ -f "$manifest" ]] || fail "failed to export the validated planner artifacts"

printf '%s\n' "$manifest"
