#!/bin/bash

echo "Compiling the smart contracts..."
forge compile
if [ $? -ne 0 ]; then
    echo "Compilation failed, retrying..."
    forge compile
    if [ $? -ne 0 ]; then
        echo "Compilation failed again, please check the errors and try again."
        exit 1
    else
        echo "Compilation successful on retry."
    fi
else
    echo "Compilation successful."
fi

if [[ -f $(pwd)/.env ]]; then
    source .env
    echo ".env file loaded successfully."
else
    echo "Error: .env file does not exist. Please create it and try again."
    exit 1
fi

echo ""
echo "Welcome to the lens caller script!"
echo "This script will guide you through the calling the appropriate lens and getting the information you need."

read -p "Do you want to query a local fork? (y/n) (default: y): " deploy_local_fork
deploy_local_fork=${deploy_local_fork:-y}

if [[ $deploy_local_fork == "y" ]]; then
    # Check if Anvil is running
    if ! pgrep -x "anvil" > /dev/null; then
        echo "Anvil is not running. Please start Anvil and try again."
        echo "You can spin up a local fork with the following command:"
        echo "anvil --fork-url ${FORK_RPC_URL}"
        exit 1
    fi
else
    # Check if DEPLOYMENT_RPC_URL environment variable is set
    if [ -z "$DEPLOYMENT_RPC_URL" ]; then
        echo "Error: DEPLOYMENT_RPC_URL environment variable is not set. Please set it and try again."
        exit 1
    else
        echo "DEPLOYMENT_RPC_URL is set to: $DEPLOYMENT_RPC_URL"
    fi
fi

echo "Provide lenses addresses..."

fileName=_lens
scriptFileName=08_Lenses.s.sol
scriptJsonFileName=$fileName.json
tempScriptJsonFileName=temp_$scriptJsonFileName
scriptJsonResultFileName=${fileName}_result.json

read -p "Do you want to manually enter the lens? If no, they will be loaded from a config file. (y/n) (default: y): " lens_input_choice
lens_input_choice=${lens_input_choice:-y}

if [[ $lens_input_choice == "n" ]]; then
    if [[ -f script/$scriptJsonFileName ]]; then
        account_lens=$(jq -r '.accountLens' script/$scriptJsonFileName)
        vault_lens=$(jq -r '.vaultLens' script/$scriptJsonFileName)

        echo "Loaded lens addresses from config file:"
        echo "Account Lens: $account_lens"
        echo "Vault Lens: $vault_lens"
    else
        echo "Error: Config file not found. Please ensure _lens.json exists in the script directory."
        exit 1
    fi
elif [[ $lens_input_choice != "y" ]]; then
    echo "Invalid input. Please enter 'enter' to manually input addresses or 'load' to load from config file."
    exit 1
fi

echo ""
echo "Select an option to query:"
echo "0. Account Lens"
echo "1. Vault Lens"
echo "2. Exit"
read -p "Enter your choice (0-2): " option_id

if [[ "$lens_choice" == "2" ]]; then
    echo "Exiting..."
    break
fi

if [[ $option_id == "0" && -z $account_lens ]]; then
    read -p "Enter the Account Lens address: " account_lens
elif [[ $option_id == "1" && -z $vault_lens ]]; then
    read -p "Enter the Vault Lens address: " vault_lens
fi

if [[ $option_id == "0" ]]; then
    echo "Querying the Account Lens getAccountInfo..."
    echo "Provide the inputs..."
    read -p "Provide the account address: " account_address
    read -p "Provide the vault address: " vault_address
elif [[ $option_id == "1" ]]; then
    echo "Querying the Vault Lens getVaultInfoFull..."
    echo "Provide the inputs..."
    read -p "Provide the vault address: " vault_address
fi

if [[ -f script/$scriptJsonFileName ]]; then
    cp script/$scriptJsonFileName script/$tempScriptJsonFileName
fi

jq -n \
    --arg accountLens "$account_lens" \
    --arg vaultLens "$vault_lens" \
    --arg account "$account_address" \
    --arg vault "$vault_address" \
    --argjson optionId "$option_id" \
    '{
        accountLens: $accountLens,
        vaultLens: $vaultLens,
        account: $account,
        vault: $vault,
        optionId: $optionId
    }' --indent 4 > script/$scriptJsonFileName

forge script script/$scriptFileName:UseLenses --rpc-url $DEPLOYMENT_RPC_URL

cat script/$scriptJsonResultFileName
rm script/$scriptJsonResultFileName

if [[ -f script/$tempScriptJsonFileName ]]; then
    cp script/$tempScriptJsonFileName script/$scriptJsonFileName
    rm script/$tempScriptJsonFileName
fi