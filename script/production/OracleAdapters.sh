#!/bin/bash

function execute_forge_script {
    local scriptName=$1
    local shouldVerify=$2

    forge script script/$scriptName --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy --slow

    if [[ $shouldVerify == "y" ]]; then
        chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
        broadcastFileName=${scriptName%%:*}

        ./script/utils/verifyContracts.sh "./broadcast/$broadcastFileName/$chainId/run-latest.json"
    fi
}

function save_results {
    local jsonName=$1
    local deployment_name=$5
    local deployment_dir="script/deployments/$deployment_name"
    local adaptersList="$deployment_dir/output/adaptersList.txt"
    local timestamp=$(date +%s)
    local chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)

    mkdir -p "$deployment_dir/input" "$deployment_dir/output" "$deployment_dir/broadcast"

    if [[ ! -f "$adaptersList" ]]; then
        echo "Asset,Quote,Provider,Adapter" > "$adaptersList"
    fi

    if [[ -f "script/${jsonName}_output.json" ]]; then
        echo "$2,$3,$4,$(jq -r '.adapter' "script/${jsonName}_output.json")" >> "$adaptersList"
        
        mv "script/${jsonName}_input.json" "$deployment_dir/input/${jsonName}_${timestamp}.json"
        mv "script/${jsonName}_output.json" "$deployment_dir/output/${jsonName}_${timestamp}.json"
        mv "./broadcast/${jsonName}.s.sol/$chainId/run-latest.json" "$deployment_dir/broadcast/${jsonName}_${timestamp}.json"
    else
        rm "script/${jsonName}_input.json"
    fi
}

# Check if the file path is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <csv_file_path>"
  exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "jq could not be found. Please install jq first."
    echo "You can install jq by running: sudo apt-get install jq"
    exit 1
fi

if [[ ! -d "$(pwd)/script" ]]; then
    echo "Error: script directory does not exist in the current directory."
    echo "Please ensure this script is run from the top project directory."
    exit 1
fi

if [[ -f .env ]]; then
    source .env
else
    echo "Error: .env file does not exist. Please create it and try again."
    exit 1
fi

if [ -z "$DEPLOYMENT_RPC_URL" ]; then
    echo "Error: DEPLOYMENT_RPC_URL environment variable is not set. Please set it and try again."
    exit 1
fi

read -p "Do you want to verify the deployed contracts? (y/n) (default: n): " verify_contracts
verify_contracts=${verify_contracts:-n}

if [[ $verify_contracts == "y" ]]; then
    if [ -z "$VERIFIER_URL" ]; then
        echo "Error: VERIFIER_URL environment variable is not set. Please set it and try again."
        exit 1
    fi

    if [ -z "$VERIFIER_API_KEY" ]; then
        echo "Error: VERIFIER_API_KEY environment variable is not set. Please set it and try again."
        exit 1
    fi
fi

read -p "Provide the deployment name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

read -p "Enter the Adapter Registry address: " adapter_registry
csv_file="$1"

while IFS=, read -r -a columns; do
    provider_index="${columns[2]}"
    deploy_index="${columns[3]}"

    if [[ "$deploy_index" == "Deploy" || "$deploy_index" == "No" ]]; then
        continue
    fi

    if [[ "$provider_index" == "API3" ]]; then
        baseName=03_OracleAdapters
        scriptName=${baseName}.s.sol:ChainlinkAdapter
        jsonName=03_ChainlinkAdapter

        jq -n \
            --arg adapterRegistry "$adapter_registry" \
            --arg base "${columns[9]}" \
            --arg quote "${columns[10]}" \
            --arg feed "${columns[11]}" \
            --argjson maxStaleness "${columns[12]}" \
            '{
                adapterRegistry: $adapterRegistry,
                base: $base,
                quote: $quote,
                feed: $feed,
                maxStaleness: $maxStaleness
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider_index" == "Chainlink" ]]; then
        baseName=03_OracleAdapters
        scriptName=${baseName}.s.sol:ChainlinkAdapter
        jsonName=03_ChainlinkAdapter

        jq -n \
            --arg adapterRegistry "$adapter_registry" \
            --arg base "${columns[8]}" \
            --arg quote "${columns[9]}" \
            --arg feed "${columns[10]}" \
            --argjson maxStaleness "${columns[11]}" \
            '{
                adapterRegistry: $adapterRegistry,
                base: $base,
                quote: $quote,
                feed: $feed,
                maxStaleness: $maxStaleness
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider_index" == "Chronicle" ]]; then
        baseName=03_OracleAdapters
        scriptName=${baseName}.s.sol:ChronicleAdapter
        jsonName=03_ChronicleAdapter

        jq -n \
            --arg adapterRegistry "$adapter_registry" \
            --arg base "${columns[8]}" \
            --arg quote "${columns[9]}" \
            --arg feed "${columns[10]}" \
            --argjson maxStaleness "${columns[11]}" \
            '{
                adapterRegistry: $adapterRegistry,
                base: $base,
                quote: $quote,
                feed: $feed,
                maxStaleness: $maxStaleness
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider_index" == "RedStone Classic" ]]; then
        baseName=03_OracleAdapters
        scriptName=${baseName}.s.sol:ChainlinkAdapter
        jsonName=03_ChainlinkAdapter

        jq -n \
            --arg adapterRegistry "$adapter_registry" \
            --arg base "${columns[8]}" \
            --arg quote "${columns[9]}" \
            --arg feed "${columns[10]}" \
            --argjson maxStaleness "${columns[11]}" \
            '{
                adapterRegistry: $adapterRegistry,
                base: $base,
                quote: $quote,
                feed: $feed,
                maxStaleness: $maxStaleness
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider_index" == "RedStone Core" ]]; then
        baseName=03_OracleAdapters
        scriptName=${baseName}.s.sol:RedstoneAdapter
        jsonName=03_RedstoneAdapter

        jq -n \
            --arg adapterRegistry "$adapter_registry" \
            --arg base "${columns[6]}" \
            --arg quote "${columns[7]}" \
            --arg feedId "${columns[8]}" \
            --argjson feedDecimals "${columns[9]}" \
            --argjson maxStaleness "${columns[10]}" \
            '{
                adapterRegistry: $adapterRegistry,
                base: $base,
                quote: $quote,
                feedId: $feedId,
                feedDecimals: $feedDecimals,
                maxStaleness: $maxStaleness
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider_index" == "Pyth" ]]; then
        baseName=03_OracleAdapters
        scriptName=${baseName}.s.sol:PythAdapter
        jsonName=03_PythAdapter

        jq -n \
            --arg adapterRegistry "$adapter_registry" \
            --arg pyth "${columns[6]}" \
            --arg base "${columns[7]}" \
            --arg quote "${columns[8]}" \
            --arg feedId "${columns[9]}" \
            --argjson maxStaleness "${columns[10]}" \
            --argjson maxConfWidth "${columns[11]}" \
            '{
                adapterRegistry: $adapterRegistry,
                pyth: $pyth,
                base: $base,
                quote: $quote,
                feedId: $feedId,
                maxStaleness: $maxStaleness,
                maxConfWidth: $maxConfWidth
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider_index" == "Cross (Chainlink)" ]]; then
        baseName=03_OracleAdapters
        scriptName=${baseName}.s.sol:CrossAdapter
        jsonName=03_CrossAdapter

        jq -n \
            --arg adapterRegistry "$adapter_registry" \
            --arg base "${columns[6]}" \
            --arg cross "${columns[7]}" \
            --arg quote "${columns[8]}" \
            --arg oracleBaseCross "${columns[9]}" \
            --arg oracleCrossQuote "${columns[10]}" \
            '{
                adapterRegistry: $adapterRegistry,
                base: $base,
                quote: $quote,
                feed: $feed,
                maxStaleness: $maxStaleness
            }' --indent 4 > script/${jsonName}_input.json
    else
        echo "Error!"
    fi

    execute_forge_script $scriptName $verify_contracts
    save_results "$jsonName" "${columns[0]}" "${columns[1]}" "${columns[2]}" "$deployment_name"
done < "$csv_file"
