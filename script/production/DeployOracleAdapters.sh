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

show_help() {
    echo "Usage: $0 <csv_input_file_path> [csv_oracle_adapters_addresses_path] [options]"
    echo ""
    echo "Deploy oracle adapters based on a CSV configuration file."
    echo ""
    echo "Arguments:"
    echo "  csv_input_file_path              CSV file with adapter configurations to deploy"
    echo "  csv_oracle_adapters_addresses    Optional: existing adapters CSV to avoid duplicates"
    echo ""
    echo "Options:"
    echo "  --rpc-url <URL|CHAIN_ID>   RPC endpoint or chain ID"
    echo "  --account <NAME>           Use named Foundry account"
    echo "  --ledger                   Use Ledger hardware wallet"
    echo "  --dry-run                  Simulate without deploying"
    echo "  --verbose                  Show skipped adapters"
    echo "  --verify                   Verify contracts after deployment"
    echo "  -h, --help                 Show this help message"
    echo ""
    echo "Examples:"
    echo "  # Deploy adapters"
    echo "  $0 adapters.csv --rpc-url mainnet --account DEPLOYER"
    echo ""
    echo "  # Deploy avoiding duplicates from existing file"
    echo "  $0 new_adapters.csv existing_adapters.csv --rpc-url mainnet --account DEPLOYER"
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

csv_oracle_adapters_addresses_path="$1"
if [ -f "$csv_oracle_adapters_addresses_path" ]; then
    shift
fi

if [[ "$@" == *"--verbose"* ]]; then
    set -- "${@/--verbose/}"
    verbose="--verbose"
fi

if ! script/utils/checkEnvironment.sh "$@"; then
    echo "Environment check failed. Exiting."
    exit 1
fi

read -p "Provide the deployment name used to save results (default: default): " deployment_name
deployment_name=${deployment_name:-default}

if [ -n "$DEPLOYER_KEY" ]; then
    set -- "$@" --private-key "$DEPLOYER_KEY"
fi

if [[ "$@" == *"--account"* && -z "$DEPLOYER_KEY" ]]; then
    read -s -p "Enter keystore password: " password
    set -- "$@" --password "$password"
    echo ""
fi

source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval 'set -- $SCRIPT_ARGS'
chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
deployment_dir="script/deployments/$deployment_name/$chainId"
oracleAdaptersAddresses="$deployment_dir/output/OracleAdaptersAddresses.csv"

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

    has_whitespace=false
    for i in "${!columns[@]}"; do
        stripped=$(echo "${columns[$i]}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        if [[ "$stripped" != "${columns[$i]}" ]]; then
            echo "Skipping deployment of $adapterName. Whitespace detected in column $i"
            has_whitespace=true
            break
        fi
    done

    if [[ "$has_whitespace" == "true" ]]; then
        continue
    fi

    if [[ "$avoid_duplicates" == "y" ]]; then
        adapterAddress=$(find_adapter_address "$adapterName" "$csv_oracle_adapters_addresses_path")

        if [[ "$adapterAddress" =~ ^0x ]]; then
            if [[ "$verbose" == "--verbose" ]]; then
                echo "Skipping deployment of $adapterName. Adapter already deployed: $adapterAddress"
            fi

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
            --arg maxStaleness "${columns[11]}" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
                adapterRegistry: $adapterRegistry,
                base: $base,
                quote: $quote,
                feed: $feed,
                maxStaleness: $maxStaleness
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider" == "Chainlink Infrequent" ]]; then
        scriptName=${baseName}.s.sol:ChainlinkInfrequentAdapter
        jsonName=03_ChainlinkInfrequentAdapter

        base="${columns[8]}"
        quote="${columns[9]}"

        jq -n \
            --argjson addToAdapterRegistry false \
            --arg adapterRegistry "0x0000000000000000000000000000000000000000" \
            --arg base "${columns[8]}" \
            --arg quote "${columns[9]}" \
            --arg feed "${columns[10]}" \
            --arg maxStaleness "${columns[11]}" \
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
            --arg maxStaleness "${columns[11]}" \
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
            --arg maxStaleness "${columns[11]}" \
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
            --arg feedDecimals "${columns[9]}" \
            --arg maxStaleness "${columns[10]}" \
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
            --arg maxStaleness "${columns[10]}" \
            --arg maxConfWidth "${columns[11]}" \
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
            --arg rate "${columns[8]}" \
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
    elif [[ "$provider" == "Pendle" ]]; then
        scriptName=${baseName}.s.sol:PendleAdapter
        jsonName=03_PendleAdapter

        base="${columns[8]}"
        quote="${columns[9]}"

        jq -n \
            --argjson addToAdapterRegistry false \
            --arg adapterRegistry "0x0000000000000000000000000000000000000000" \
            --arg pendleOracle "${columns[6]}" \
            --arg pendleMarket "${columns[7]}" \
            --arg base "${columns[8]}" \
            --arg quote "${columns[9]}" \
            --arg twapWindow "${columns[10]}" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
                adapterRegistry: $adapterRegistry,
                pendleOracle: $pendleOracle,
                pendleMarket: $pendleMarket,
                base: $base,
                quote: $quote,
                twapWindow: $twapWindow
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider" == "PendleUniversal" ]]; then
        scriptName=${baseName}.s.sol:PendleUniversalAdapter
        jsonName=03_PendleUniversalAdapter

        base="${columns[8]}"
        quote="${columns[9]}"

        jq -n \
            --argjson addToAdapterRegistry false \
            --arg adapterRegistry "0x0000000000000000000000000000000000000000" \
            --arg pendleOracle "${columns[6]}" \
            --arg pendleMarket "${columns[7]}" \
            --arg base "${columns[8]}" \
            --arg quote "${columns[9]}" \
            --arg twapWindow "${columns[10]}" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
                adapterRegistry: $adapterRegistry,
                pendleOracle: $pendleOracle,
                pendleMarket: $pendleMarket,
                base: $base,
                quote: $quote,
                twapWindow: $twapWindow
            }' --indent 4 > script/${jsonName}_input.json
    elif [[ "$provider" == "Idle" ]]; then
        scriptName=${baseName}.s.sol:IdleTranchesAdapter
        jsonName=03_IdleTranchesAdapter

        base="${columns[6]}"
        quote="${columns[7]}"

        jq -n \
            --argjson addToAdapterRegistry false \
            --arg adapterRegistry "0x0000000000000000000000000000000000000000" \
            --arg cdo "${columns[8]}" \
            --arg tranche "${columns[9]}" \
            '{
                addToAdapterRegistry: $addToAdapterRegistry,
                adapterRegistry: $adapterRegistry,
                cdo: $cdo,
                tranche: $tranche
            }' --indent 4 > script/${jsonName}_input.json
    else
        echo "Error!"
        exit 1
    fi

    if [[ "$@" == *"--dry-run"* ]]; then
        echo "Dry run: Deploying $adapterName..."
        rm "script/${jsonName}_input.json"
        continue
    fi

    skip=false
    if [[ "$provider" == *Pendle* ]]; then
        result=$(cast call "${columns[6]}" "getOracleState(address,uint32)(bool,uint16,bool)" ${columns[7]} ${columns[10]} --rpc-url $DEPLOYMENT_RPC_URL)
        increaseCardinalityRequired=$(echo "$result" | head -1)
        cardinalityRequired=$(echo "$result" | sed -n '2p')
        oldestObservationSatisfied=$(echo "$result" | tail -1)
        
        if [[ "$increaseCardinalityRequired" == "true" ]]; then
            echo "Increasing observation cardinality for $adapterName..."
            cast send "${columns[7]}" "increaseObservationsCardinalityNext(uint16)" $cardinalityRequired --rpc-url $DEPLOYMENT_RPC_URL "$@"
            skip=true
        elif [[ "$oldestObservationSatisfied" == "false" ]]; then
            skip=true
        fi
    fi

    if [[ "$skip" != "true" ]] && script/utils/executeForgeScript.sh $scriptName "$@"; then
        counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/output/${jsonName}.json")
        adapter=$(jq -r '.adapter' "script/${jsonName}_output.json")
        entry="${baseSymbol},${quoteSymbol},${provider},${adapterName},${adapter},$base,$quote,${shouldWhitelist}"

        echo "Successfully deployed $adapterName: $adapter"
        echo "$entry" >> "$oracleAdaptersAddresses"

        if [[ "$add_to_csv" == "y" && "$csv_oracle_adapters_addresses_path" != "$oracleAdaptersAddresses" ]]; then
            echo "$entry" >> "$csv_oracle_adapters_addresses_path"
        fi

        cp "broadcast/${baseName}.s.sol/$chainId/run-latest.json" "$deployment_dir/broadcast/${jsonName}_${counter}.json"
        mv "script/${jsonName}_input.json" "$deployment_dir/input/${jsonName}_${counter}.json"
        mv "script/${jsonName}_output.json" "$deployment_dir/output/${jsonName}_${counter}.json"
    else
        for json_file in script/*.json; do
            rm "$json_file"
        done

        if [[ "$skip" == "true" ]]; then
            echo "Skipping deployment of $adapterName. Insufficient observation history."
            continue
        else
            echo "Error deploying $adapterName. Exiting..."
            exit 1
        fi
    fi
done < <(tr -d '\r' < "$csv_file")
