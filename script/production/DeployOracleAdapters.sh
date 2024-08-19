#!/bin/bash

# Check if the file path is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <csv_file_path>"
  exit 1
fi

csv_file="$1"

read -p "Do you want to verify the deployed contracts? (y/n) (default: n): " verify_contracts
verify_contracts=${verify_contracts:-n}

if ! script/utils/checkEnvironment.sh $verify_contracts; then
    echo "Environment check failed. Exiting."
    exit 1
fi

read -p "Provide the deployment name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

read -p "Enter the Adapter Registry address: " adapter_registry

source .env
deployment_dir="script/deployments/$deployment_name"
adaptersList="$deployment_dir/output/adaptersList.csv"
chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)

mkdir -p "$deployment_dir/input" "$deployment_dir/output" "$deployment_dir/broadcast"

if [[ ! -f "$adaptersList" ]]; then
    echo "Asset,Quote,Provider,Adapter" > "$adaptersList"
fi

while IFS=, read -r -a columns || [ -n "$columns" ]; do
    provider_index="${columns[2]}"
    deploy_index="${columns[3]}"

    if [[ "$deploy_index" == "Deploy" || "$deploy_index" == "No" ]]; then
        continue
    fi

    if [[ "$provider_index" == "Chainlink" ]]; then
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
    elif [[ "$provider_index" == *Cross* ]]; then
        # Sanity check
        timestamp=$(date +%s)
        baseCrossAdapters=$(cast call "$adapter_registry" "getValidAddresses(address,address,uint256)(address[])" "${columns[6]}" "${columns[7]}" "$timestamp" --rpc-url "$DEPLOYMENT_RPC_URL")
        crossQuoteAdapters=$(cast call "$adapter_registry" "getValidAddresses(address,address,uint256)(address[])" "${columns[7]}" "${columns[8]}" "$timestamp" --rpc-url "$DEPLOYMENT_RPC_URL")

        if [[ $baseCrossAdapters != *"${columns[9]}"* ]]; then
            echo "${columns[9]} is not a valid adapter. Skipping..."
            continue
        fi

        if [[ $crossQuoteAdapters != *"${columns[10]}"* ]]; then
            echo "${columns[10]} is not a valid adapter. Skipping..."
            continue
        fi

        baseName=03_OracleAdapters
        scriptName=${baseName}.s.sol:CrossAdapterDeployer
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
                cross: $cross,
                quote: $quote,
                oracleBaseCross: $oracleBaseCross,
                oracleCrossQuote: $oracleCrossQuote
            }' --indent 4 > script/${jsonName}_input.json
    else
        echo "Error!"
        exit 1
    fi

    if script/utils/executeForgeScript.sh $scriptName $verify_contracts; then
        counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/input/${jsonName}.json")

        echo "${columns[0]},${columns[1]},${columns[2]},$(jq -r '.adapter' "script/${jsonName}_output.json")" >> "$adaptersList"
        mv "script/${jsonName}_input.json" "$deployment_dir/input/${jsonName}_${counter}.json"
        mv "script/${jsonName}_output.json" "$deployment_dir/output/${jsonName}_${counter}.json"
        cp "broadcast/${baseName}.s.sol/$chainId/run-latest.json" "$deployment_dir/broadcast/${jsonName}_${counter}.json"
    else
        rm "script/${jsonName}_input.json"
    fi
done < <(tr -d '\r' < "$csv_file")
