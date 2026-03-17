#!/bin/bash

# Interactive Deployment Loop
# Run the same deployment option across multiple chains without repeated password prompts
#
# Usage:
#   ./script/interactiveDeploymentLoop.sh --rpc-url "mainnet,arbitrum,optimism" --choice 50 [--verify] [--dry-run]
#
# The script will:
#   1. Prompt for the account name for each chain
#   2. Prompt for passwords for each unique account (once per account)
#   3. Run the deployment for each chain sequentially
#   4. Use non-interactive mode (defaults for all prompts)
#
# Examples:
#   # Deploy option 50 on mainnet, arbitrum, and optimism with verification
#   ./script/interactiveDeploymentLoop.sh --rpc-url "mainnet,arbitrum,optimism" --choice 50 --verify
#
#   # Dry run on multiple chains (using chain IDs)
#   ./script/interactiveDeploymentLoop.sh --rpc-url "1,42161,10" --choice 50 --dry-run

set -e

# Parse arguments
rpc_urls=""
choice=""
deployment_name="default"
extra_args=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --rpc-url)
            rpc_urls="$2"
            shift 2
            ;;
        --rpc-url=*)
            rpc_urls="${1#*=}"
            shift
            ;;
        --choice)
            choice="$2"
            shift 2
            ;;
        --choice=*)
            choice="${1#*=}"
            shift
            ;;
        --deployment-name)
            deployment_name="$2"
            shift 2
            ;;
        --deployment-name=*)
            deployment_name="${1#*=}"
            shift
            ;;
        *)
            extra_args+=("$1")
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$rpc_urls" ]; then
    echo "Error: --rpc-url is required"
    echo "Usage: ./script/interactiveDeploymentLoop.sh --rpc-url \"chain1,chain2\" --choice N [options]"
    exit 1
fi

if [ -z "$choice" ]; then
    echo "Error: --choice is required"
    exit 1
fi

# Helper function to trim whitespace (bash 3.x compatible)
trim() {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

# Convert rpc_urls string to array
IFS=',' read -ra rpc_url_array <<< "$rpc_urls"

echo "=========================================="
echo "Interactive Deployment Loop"
echo "=========================================="
echo "RPC URLs: ${rpc_url_array[*]}"
echo "Choice: $choice"
echo "Deployment name: $deployment_name"
echo "Extra args: ${extra_args[*]}"
echo "=========================================="
echo ""

# Step 1: Prompt for account name for each chain
# Using parallel arrays instead of associative arrays (for bash 3.x compatibility)
chain_accounts=()
unique_accounts=()

echo "Step 1: Configure accounts for each chain"
echo "------------------------------------------"
for rpc_url in "${rpc_url_array[@]}"; do
    rpc_url=$(trim "$rpc_url")
    read -p "Enter account name for $rpc_url: " account_name
    chain_accounts+=("$account_name")
    
    # Track unique accounts
    is_unique=true
    for existing in "${unique_accounts[@]}"; do
        if [ "$existing" = "$account_name" ]; then
            is_unique=false
            break
        fi
    done
    if [ "$is_unique" = true ]; then
        unique_accounts+=("$account_name")
    fi
done
echo ""

# Step 2: Prompt for passwords for each unique account
# Using parallel arrays for account -> password mapping
account_passwords=()

echo "Step 2: Enter passwords for each account"
echo "-----------------------------------------"
for account in "${unique_accounts[@]}"; do
    read -s -p "Enter keystore password for account '$account': " password
    echo ""
    account_passwords+=("$password")
done
echo ""

# Helper function to get password for an account
get_password_for_account() {
    local target_account="$1"
    local i=0
    for account in "${unique_accounts[@]}"; do
        if [ "$account" = "$target_account" ]; then
            echo "${account_passwords[$i]}"
            return
        fi
        i=$((i + 1))
    done
}

# Display configuration summary
echo "=========================================="
echo "Configuration Summary"
echo "=========================================="
i=0
for rpc_url in "${rpc_url_array[@]}"; do
    rpc_url=$(trim "$rpc_url")
    echo "  $rpc_url -> account: ${chain_accounts[$i]}"
    i=$((i + 1))
done
echo "=========================================="
echo ""

read -p "Proceed with deployments? (y/n): " confirm
if [ "$confirm" != "y" ]; then
    echo "Aborted."
    exit 0
fi

echo ""
echo "Starting deployments..."
echo ""

# Track results using parallel arrays
result_urls=()
result_statuses=()

# Run deployment for each rpc-url
i=0
for rpc_url in "${rpc_url_array[@]}"; do
    rpc_url=$(trim "$rpc_url")
    account="${chain_accounts[$i]}"
    
    # Get the password for this account
    export KEYSTORE_PASSWORD=$(get_password_for_account "$account")
    
    echo "=========================================="
    echo "Deploying to: $rpc_url (account: $account)"
    echo "=========================================="
    
    if ./script/interactiveDeployment.sh \
        --rpc-url "$rpc_url" \
        --account "$account" \
        --choice="$choice" \
        --deployment-name="$deployment_name" \
        --non-interactive \
        "${extra_args[@]}"; then
        result_urls+=("$rpc_url")
        result_statuses+=("✓ SUCCESS")
        echo ""
        echo "✓ Deployment to $rpc_url completed successfully"
    else
        result_urls+=("$rpc_url")
        result_statuses+=("✗ FAILED")
        echo ""
        echo "✗ Deployment to $rpc_url failed"
    fi
    
    echo ""
    i=$((i + 1))
done

# Clear password from environment
unset KEYSTORE_PASSWORD

# Print summary
echo "=========================================="
echo "Deployment Summary"
echo "=========================================="
i=0
for rpc_url in "${result_urls[@]}"; do
    echo "  $rpc_url: ${result_statuses[$i]}"
    i=$((i + 1))
done
echo "=========================================="
