#!/bin/bash

find_adapter_address() {
    local adapter_name="$1"
    local adapters_list="$2"
    local result="$adapter_name"

    if [[ ! "$adapter_name" =~ ^0x ]]; then
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
csv_oracle_adapters_addresses_path="$2"

read -p "Do you want to verify the deployed contracts? (y/n) (default: n): " verify_contracts
verify_contracts=${verify_contracts:-n}

if [[ $verify_contracts == "y" ]]; then
    verify_contracts="--verify"
fi

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

if [ -f "$csv_oracle_adapters_addresses_path" ]; then
    read -p "Shall we avoid deploying duplicates based on the provided $csv_oracle_adapters_addresses_path file? (y/n) (default: y): " avoid_duplicates
    avoid_duplicates=${avoid_duplicates:-y}

    read -p "Shall we add deployed adapters directly to the provided $csv_oracle_adapters_addresses_path file? (y/n) (default: n): " add_to_csv
    add_to_csv=${add_to_csv:-n}
fi

if [[ ! -f "$oracleAdaptersAddresses" ]]; then
    echo "Asset,Quote,Provider,Adapter Name,Adapter,Base,Quote,Whitelist" > "$oracleAdaptersAddresses"
fi

while IFS=, read -r -a columns || [ -n "$columns" ]; do
    baseSymbol="${columns[0]}"
    quoteSymbol="${columns[1]}"
    provider="${columns[2]}"
    shouldDeploy="${columns[3]}"
    shouldWhitelist="${columns[4]}"
    oracleBaseCross="${columns[9]//[\[\]]}"
    oracleCrossQuote="${columns[10]//[\[\]]}"

    if [[ "$shouldDeploy" == "Deploy" || "$shouldDeploy" == "No" ]]; then
        continue
    fi

    if [[ "$provider" == *Cross* ]]; then
        adapterName="${provider// /}_${baseSymbol}/${quoteSymbol}=${oracleBaseCross}+${oracleCrossQuote}"
        oracleBaseCross=$(find_adapter_address "${oracleBaseCross}" "$csv_oracle_adapters_addresses_path")
        oracleCrossQuote=$(find_adapter_address "${oracleCrossQuote}" "$csv_oracle_adapters_addresses_path")

        if [[ ! "$oracleBaseCross" =~ ^0x ]]; then
            echo "Skipping deployment of $adapterName. Missing oracle adapter: $oracleBaseCross"
            continue
        fi

        if [[ ! "$oracleCrossQuote" =~ ^0x ]]; then
            echo "Skipping deployment of $adapterName. Missing oracle adapter: $oracleCrossQuote"
            continue
        fi
    else
        adapterName="${provider// /}_${baseSymbol}/${quoteSymbol}"
    fi

    for i in "${!columns[@]}"; do
        stripped=$(echo "${columns[$i]}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        if [[ "$stripped" != "${columns[$i]}" ]]; then
            echo "Skipping deployment of $adapterName. Whitespace detected in column $i"
            continue
        fi
    done

    if [[ "$avoid_duplicates" == "y" ]]; then
        adapterAddress=$(find_adapter_address "$adapterName" "$csv_oracle_adapters_addresses_path")

        if [[ "$adapterAddress" =~ ^0x ]]; then
            echo "Skipping deployment of $adapterName. Adapter already deployed: $adapterAddress"
            continue
        fi
    fi

    if [[ "$provider" == "Chainlink" ]]; then
        scriptName=${baseName}.s.sol:ChainlinkAdapter
        jsonName=03_ChainlinkAdapter

        base="${columns[8]}"
        quote="${columns[9]}"

        jq -n \
            --argjson addToAdapterRegistry false \
            --arg adapterRegistry "0x0000000000000000000000000000000000000000" \
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
    elif [[ "$provider" == "Chronicle" ]]; then
        scriptName=${baseName}.s.sol:ChronicleAdapter
        jsonName=03_ChronicleAdapter

        base="${columns[8]}"
        quote="${columns[9]}"

        jq -n \
            --argjson addToAdapterRegistry false \
            --arg adapterRegistry "0x0000000000000000000000000000000000000000" \
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
    elif [[ "$provider" == "Lido" ]]; then
        scriptName=${baseName}.s.sol:LidoAdapter
        jsonName=03_LidoAdapter

        if [[ $chainId == "1" ]]; then
            base=0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
            quote=0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84
        else
            base=""
            quote=""
        fi

        jq -n \
            --argjson addToAdapterRegistry false \
            --arg adapterRegistry "0x0000000000000000000000000000000000000000" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
                adapterRegistry: $adapterRegistry
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider" == "Lido Fundamental" ]]; then
        scriptName=${baseName}.s.sol:LidoFundamentalAdapter
        jsonName=03_LidoFundamentalAdapter

        if [[ $chainId == "1" ]]; then
            base=0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0
            quote=0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        else
            base=""
            quote=""
        fi

        jq -n \
            --argjson addToAdapterRegistry false \
            --arg adapterRegistry "0x0000000000000000000000000000000000000000" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
                adapterRegistry: $adapterRegistry
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider" == "RedStone Classic" ]]; then
        scriptName=${baseName}.s.sol:ChainlinkAdapter
        jsonName=03_ChainlinkAdapter

        base="${columns[8]}"
        quote="${columns[9]}"

        jq -n \
            --argjson addToAdapterRegistry false \
            --arg adapterRegistry "0x0000000000000000000000000000000000000000" \
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
    elif [[ "$provider" == "RedStone Core" ]]; then
        scriptName=${baseName}.s.sol:RedstoneAdapter
        jsonName=03_RedstoneAdapter

        base="${columns[6]}"
        quote="${columns[7]}"

        jq -n \
            --argjson addToAdapterRegistry false \
            --arg adapterRegistry "0x0000000000000000000000000000000000000000" \
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
    elif [[ "$provider" == "Pyth" ]]; then
        scriptName=${baseName}.s.sol:PythAdapter
        jsonName=03_PythAdapter

        base="${columns[7]}"
        quote="${columns[8]}"

        jq -n \
            --argjson addToAdapterRegistry false \
            --arg adapterRegistry "0x0000000000000000000000000000000000000000" \
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
    elif [[ "$provider" == "Fixed Rate" ]]; then
        scriptName=${baseName}.s.sol:FixedRateAdapter
        jsonName=03_FixedRateAdapter

        base="${columns[6]}"
        quote="${columns[7]}"

        jq -n \
            --argjson addToAdapterRegistry false \
            --arg adapterRegistry "0x0000000000000000000000000000000000000000" \
            --arg base "${columns[6]}" \
            --arg quote "${columns[7]}" \
            --argjson rate "${columns[8]}" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
                adapterRegistry: $adapterRegistry,
                base: $base,
                quote: $quote,
                rate: $rate
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider" == "Rate Provider" ]]; then
        scriptName=${baseName}.s.sol:RateProviderAdapter
        jsonName=03_RateProviderAdapter

        base="${columns[6]}"
        quote="${columns[7]}"

        jq -n \
            --argjson addToAdapterRegistry false \
            --arg adapterRegistry "0x0000000000000000000000000000000000000000" \
            --arg base "${columns[6]}" \
            --arg quote "${columns[7]}" \
            --arg rateProvider "${columns[8]}" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
                adapterRegistry: $adapterRegistry,
                base: $base,
                quote: $quote,
                rateProvider: $rateProvider
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider" == *Cross* ]]; then
        scriptName=${baseName}.s.sol:CrossAdapterDeployer
        jsonName=03_CrossAdapter

        base="${columns[6]}"
        quote="${columns[8]}"

        jq -n \
            --argjson addToAdapterRegistry false \
            --arg adapterRegistry "0x0000000000000000000000000000000000000000" \
            --arg base "${columns[6]}" \
            --arg cross "${columns[7]}" \
            --arg quote "${columns[8]}" \
            --arg oracleBaseCross "${oracleBaseCross}" \
            --arg oracleCrossQuote "${oracleCrossQuote}" \
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

    if [[ "$@" == *"--dry-run"* ]]; then
        echo "Dry run: Deploying $adapterName..."
        continue
    fi

    script/utils/executeForgeScript.sh $scriptName $verify_contracts

    if [[ -f "script/${jsonName}_output.json" ]]; then
        counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/input/${jsonName}.json")
        adapter=$(jq -r '.adapter' "script/${jsonName}_output.json")
        entry="${baseSymbol},${quoteSymbol},${provider},${adapterName},${adapter},$base,$quote,${shouldWhitelist}"

        echo "Successfully deployed $adapterName: $adapter"
        echo "$entry" >> "$oracleAdaptersAddresses"

        if [[ "$add_to_csv" == "y" ]]; then
            echo "$entry" >> "$csv_oracle_adapters_addresses_path"
        fi

        mv "script/${jsonName}_input.json" "$deployment_dir/input/${jsonName}_${counter}.json"
        mv "script/${jsonName}_output.json" "$deployment_dir/output/${jsonName}_${counter}.json"
        cp "broadcast/${baseName}.s.sol/$chainId/run-latest.json" "$deployment_dir/broadcast/${jsonName}_${counter}.json"
    else
        echo "Error deploying $adapterName..."
        rm "script/${jsonName}_input.json"
    fi
done < <(tr -d '\r' < "$csv_file")
