#!/bin/bash

find_adapter_address() {
    local adapter_name="$1"
    local adapters_list="$2"
    local result="$adapter_name"

    if [[ ! "$adapter_name" =~ ^0x ]]; then
        adapter_name="${adapter_name//[/}"
        adapter_name="${adapter_name//]/}"
        adapter_name=$(echo "$adapter_name" | tr '[:upper:]' '[:lower:]')
        
        if [[ -f "$adapters_list" ]]; then
            while IFS=, read -r -a adapter_columns || [ -n "$adapter_columns" ]; do
                adapter_name_list=$(echo "${adapter_columns[3]}" | tr '[:upper:]' '[:lower:]')

                if [[ "${adapter_name_list}" == "$adapter_name" ]]; then
                    result="${adapter_columns[4]}"
                    break
                fi
            done < <(tr -d '\r' < "$adapters_list")
        fi
    fi

    echo "$result"
}

if [ -z "$1" ]; then
    echo "Usage: $0 <csv_input_file_path> [csv_oracle_adapters_addresses_path]"
    exit 1
fi

if [ ! -z "$2" ] && [[ ! -f "$2" ]]; then
    echo "Error: The specified adapters list file does not exist."
    echo "Usage: $0 <csv_input_file_path> [csv_oracle_adapters_addresses_path]"
    exit 1
fi

csv_file="$1"
past_oracle_adapters_addresses_path="$2"

read -p "Do you want to verify the deployed contracts? (y/n) (default: n): " verify_contracts
verify_contracts=${verify_contracts:-n}

if ! script/utils/checkEnvironment.sh $verify_contracts; then
    echo "Environment check failed. Exiting."
    exit 1
fi

read -p "Provide the deployment name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

source .env
deployment_dir="script/deployments/$deployment_name"
oracleAdaptersAddresses="$deployment_dir/output/OracleAdaptersAddresses.csv"
chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)

mkdir -p "$deployment_dir/input" "$deployment_dir/output" "$deployment_dir/broadcast"

baseName=03_OracleAdapters

read -p "Should the adapter be added to the Adapter Registry? (y/n) (default: y): " add_to_adapter_registry
add_to_adapter_registry=${add_to_adapter_registry:-y}

read -p "Enter the Adapter Registry address: " adapter_registry

if [ -f "$past_oracle_adapters_addresses_path" ]; then
    read -p "Should avoid deploying duplicates based on the provided $oracleAdaptersAddresses file? (y/n) (default: y): " avoid_duplicates
    avoid_duplicates=${avoid_duplicates:-y}
fi

if [[ ! -f "$oracleAdaptersAddresses" ]]; then
    echo "Asset,Quote,Provider,Adapter Name,Adapter,Base,Quote" > "$oracleAdaptersAddresses"
fi

while IFS=, read -r -a columns || [ -n "$columns" ]; do
    provider_index="${columns[2]}"
    deploy_index="${columns[3]}"

    if [[ "$deploy_index" == "Deploy" || "$deploy_index" == "No" ]]; then
        continue
    fi

    adapterName="${provider_index// /}_${columns[0]}/${columns[1]}"

    if [[ "$avoid_duplicates" == "y" ]]; then
        adapterAddress=$(find_adapter_address "$adapterName" "$past_oracle_adapters_addresses_path")

        if [[ "$adapterAddress" =~ ^0x ]]; then
            echo "Skipping deployment of $adapterName. Adapter already deployed: $adapterAddress"
            continue
        fi
    fi

    if [[ "$provider_index" == "Chainlink" ]]; then
        scriptName=${baseName}.s.sol:ChainlinkAdapter
        jsonName=03_ChainlinkAdapter

        base="${columns[8]}"
        quote="${columns[9]}"

        jq -n \
            --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
            --arg adapterRegistry "$adapter_registry" \
            --arg base "${columns[8]}" \
            --arg quote "${columns[9]}" \
            --arg feed "${columns[10]}" \
            --argjson maxStaleness "${columns[11]}" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
                adapterRegistry: $adapterRegistry,
                base: $base,
                quote: $quote,
                feed: $feed,
                maxStaleness: $maxStaleness
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider_index" == "Chronicle" ]]; then
        scriptName=${baseName}.s.sol:ChronicleAdapter
        jsonName=03_ChronicleAdapter

        base="${columns[8]}"
        quote="${columns[9]}"

        jq -n \
            --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
            --arg adapterRegistry "$adapter_registry" \
            --arg base "${columns[8]}" \
            --arg quote "${columns[9]}" \
            --arg feed "${columns[10]}" \
            --argjson maxStaleness "${columns[11]}" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
                adapterRegistry: $adapterRegistry,
                base: $base,
                quote: $quote,
                feed: $feed,
                maxStaleness: $maxStaleness
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider_index" == "Lido" ]]; then
        scriptName=${baseName}.s.sol:LidoAdapter
        jsonName=03_LidoAdapter

        if [[ $chainId == "1" ]]; then
            base=0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
            quote=0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
        else
            base=""
            quote=""
        fi

        jq -n \
            --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
            --arg adapterRegistry "$adapter_registry" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
                adapterRegistry: $adapterRegistry
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider_index" == "RedStone Classic" ]]; then
        scriptName=${baseName}.s.sol:ChainlinkAdapter
        jsonName=03_ChainlinkAdapter

        base="${columns[8]}"
        quote="${columns[9]}"

        jq -n \
            --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
            --arg adapterRegistry "$adapter_registry" \
            --arg base "${columns[8]}" \
            --arg quote "${columns[9]}" \
            --arg feed "${columns[10]}" \
            --argjson maxStaleness "${columns[11]}" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
                adapterRegistry: $adapterRegistry,
                base: $base,
                quote: $quote,
                feed: $feed,
                maxStaleness: $maxStaleness
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider_index" == "RedStone Core" ]]; then
        scriptName=${baseName}.s.sol:RedstoneAdapter
        jsonName=03_RedstoneAdapter

        base="${columns[6]}"
        quote="${columns[7]}"

        jq -n \
            --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
            --arg adapterRegistry "$adapter_registry" \
            --arg base "${columns[6]}" \
            --arg quote "${columns[7]}" \
            --arg feedId "${columns[8]}" \
            --argjson feedDecimals "${columns[9]}" \
            --argjson maxStaleness "${columns[10]}" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
                adapterRegistry: $adapterRegistry,
                base: $base,
                quote: $quote,
                feedId: $feedId,
                feedDecimals: $feedDecimals,
                maxStaleness: $maxStaleness
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider_index" == "Pyth" ]]; then
        scriptName=${baseName}.s.sol:PythAdapter
        jsonName=03_PythAdapter

        base="${columns[7]}"
        quote="${columns[8]}"

        jq -n \
            --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
            --arg adapterRegistry "$adapter_registry" \
            --arg pyth "${columns[6]}" \
            --arg base "${columns[7]}" \
            --arg quote "${columns[8]}" \
            --arg feedId "${columns[9]}" \
            --argjson maxStaleness "${columns[10]}" \
            --argjson maxConfWidth "${columns[11]}" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
                adapterRegistry: $adapterRegistry,
                pyth: $pyth,
                base: $base,
                quote: $quote,
                feedId: $feedId,
                maxStaleness: $maxStaleness,
                maxConfWidth: $maxConfWidth
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider_index" == *Cross* ]]; then
        columns[9]=$(find_adapter_address "${columns[9]}" "$past_oracle_adapters_addresses_path")
        columns[10]=$(find_adapter_address "${columns[10]}" "$past_oracle_adapters_addresses_path")

        # Sanity check
        timestamp=$(date +%s)
        baseCrossAdapters=$(cast call "$adapter_registry" "getValidAddresses(address,address,uint256)(address[])" "${columns[6]}" "${columns[7]}" "$timestamp" --rpc-url "$DEPLOYMENT_RPC_URL")

        if [[ $baseCrossAdapters != *"${columns[9]}"* ]]; then
            echo "${columns[9]} is not a valid adapter. Skipping deployment of $adapterName..."
            continue
        fi

        crossQuoteAdapters=$(cast call "$adapter_registry" "getValidAddresses(address,address,uint256)(address[])" "${columns[7]}" "${columns[8]}" "$timestamp" --rpc-url "$DEPLOYMENT_RPC_URL")

        if [[ $crossQuoteAdapters != *"${columns[10]}"* ]]; then
            echo "${columns[10]} is not a valid adapter. Skipping deployment of $adapterName..."
            continue
        fi

        scriptName=${baseName}.s.sol:CrossAdapterDeployer
        jsonName=03_CrossAdapter

        base="${columns[6]}"
        quote="${columns[8]}"

        jq -n \
            --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
            --arg adapterRegistry "$adapter_registry" \
            --arg base "${columns[6]}" \
            --arg cross "${columns[7]}" \
            --arg quote "${columns[8]}" \
            --arg oracleBaseCross "${columns[9]}" \
            --arg oracleCrossQuote "${columns[10]}" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
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

    script/utils/executeForgeScript.sh $scriptName $verify_contracts > /dev/null 2>&1

    if [[ -f "script/${jsonName}_output.json" ]]; then
        counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/input/${jsonName}.json")
        adapter=$(jq -r '.adapter' "script/${jsonName}_output.json")

        echo "Successfully deployed $adapterName: $adapter"
        echo "${columns[0]},${columns[1]},${columns[2]},${adapterName},${adapter},$base,$quote" >> "$oracleAdaptersAddresses"

        mv "script/${jsonName}_input.json" "$deployment_dir/input/${jsonName}_${counter}.json"
        mv "script/${jsonName}_output.json" "$deployment_dir/output/${jsonName}_${counter}.json"
        cp "broadcast/${baseName}.s.sol/$chainId/run-latest.json" "$deployment_dir/broadcast/${jsonName}_${counter}.json"
    else
        echo "Error deploying $adapterName..."
        rm "script/${jsonName}_input.json"
    fi
done < <(tr -d '\r' < "$csv_file")
