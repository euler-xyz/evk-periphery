#!/bin/bash

function backup_script_files {
    local scriptFileName=$1
    local tempScriptFileName=$2
    
    if [[ -f script/input/$scriptFileName ]]; then
        cp script/input/$scriptFileName script/input/$tempScriptFileName
    fi

    if [[ -f script/output/$scriptFileName ]]; then
        cp script/output/$scriptFileName script/output/$tempScriptFileName
    fi
}

function backup_and_restore_script_files {
    local scriptFileName=$1
    local tempScriptFileName=$2
    local deployment_name=$3
    local deployment_dir="script/deployments/$deployment_name"

    mkdir -p "$deployment_dir/input" "$deployment_dir/output"

    if [[ -f "$deployment_dir/input/$scriptFileName" ]]; then
        is_array=$(jq 'if (type == "array") then true else false end' < "$deployment_dir/input/$scriptFileName")

        if [[ $is_array == "true" ]]; then
            jq -s '.[0] + [.[1]]' "$deployment_dir/input/$scriptFileName" "script/input/$scriptFileName" > "$deployment_dir/input/temp_$scriptFileName"
            jq -s '.[0] + [.[1]]' "$deployment_dir/output/$scriptFileName" "script/output/$scriptFileName" > "$deployment_dir/output/temp_$scriptFileName"
        else
            jq -s '[.[0]] + [.[1]]' "$deployment_dir/input/$scriptFileName" "script/input/$scriptFileName" > "$deployment_dir/input/temp_$scriptFileName"
            jq -s '[.[0]] + [.[1]]' "$deployment_dir/output/$scriptFileName" "script/output/$scriptFileName" > "$deployment_dir/output/temp_$scriptFileName"
        fi
        
        mv "$deployment_dir/input/temp_$scriptFileName" "$deployment_dir/input/$scriptFileName"
        mv "$deployment_dir/output/temp_$scriptFileName" "$deployment_dir/output/$scriptFileName"
    else
        cp "script/input/$scriptFileName" "$deployment_dir/input/$scriptFileName"
        cp "script/output/$scriptFileName" "$deployment_dir/output/$scriptFileName"
    fi

    if [[ -f script/input/$tempScriptFileName ]]; then
        cp script/input/$tempScriptFileName script/input/$scriptFileName
        rm script/input/$tempScriptFileName
    else
        rm script/input/$scriptFileName
    fi

    if [[ -f script/output/$tempScriptFileName ]]; then
        cp script/output/$tempScriptFileName script/output/$scriptFileName
        rm script/output/$tempScriptFileName
    else
        rm script/output/$scriptFileName
    fi
}

function execute_forge_command {
    local scriptFileName=$1
    local shouldVerify=$2

    forge script script/$scriptFileName --rpc-url "$DEPLOYMENT_RPC_URL" --broadcast --legacy --slow

    if [[ $shouldVerify == "y" ]]; then
        scriptFileName=${scriptFileName%%:*}
        transactions=$(jq -c '.transactions[]' ./broadcast/$scriptFileName/1/run-latest.json)
        
        for tx in $transactions; do
            transactionType=$(echo $tx | grep -o '"transactionType":"[^"]*' | grep -o '[^"]*$')
            contractName=$(echo $tx | grep -o '"contractName":"[^"]*' | grep -o '[^"]*$')
            contractAddress=$(echo $tx | grep -o '"contractAddress":"[^"]*' | grep -o '[^"]*$')    

            if [[ $transactionType != "CREATE" || $contractName == "" || $contractAddress == "" ]]; then
                if [[ $transactionType == "CREATE" && ( $contractName != "" || $contractAddress != "" ) ]]; then
                    echo "Skipping verification of $contractName: $contractAddress"
                fi
                continue
            fi
    
            verify_command="forge verify-contract $contractAddress $contractName --rpc-url \"$DEPLOYMENT_RPC_URL\" --verifier-url \"$VERIFIER_URL\" --etherscan-api-key \"$VERIFIER_API_KEY\" --skip-is-verified-check --watch"
    
            echo "Verifying $contractName: $contractAddress"
            result=$(eval $verify_command --flatten --force 2>&1)

            if [[ "$result" == *"Contract successfully verified"* ]]; then
                echo "Success"
            else
                result=$(eval $verify_command 2>&1)

                if [[ "$result" == *"Contract successfully verified"* ]]; then
                    echo "Success"
                else
                    echo "Failure"
                fi
            fi
        done
    fi
}

if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Please install jq first."
    echo "You can install jq by running: sudo apt-get install jq"
    exit 1
fi

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

if [[ ! -d "$(pwd)/script" ]]; then
    echo "Error: script directory does not exist in the current directory."
    echo "Please ensure this script is run from the top project directory."
    exit 1
fi

if [[ -f .env ]]; then
    source .env
    echo ".env file loaded successfully."
else
    echo "Error: .env file does not exist. Please create it and try again."
    exit 1
fi

# Check if DEPLOYMENT_RPC_URL environment variable is set
if [ -z "$DEPLOYMENT_RPC_URL" ]; then
    echo "Error: DEPLOYMENT_RPC_URL environment variable is not set. Please set it and try again."
    exit 1
else
    echo "DEPLOYMENT_RPC_URL is set to: $DEPLOYMENT_RPC_URL"
fi

echo ""
echo "Welcome to the deployment script!"
echo "This script will guide you through the deployment process."

read -p "Do you want to deploy on a local fork? (y/n) (default: y): " local_fork
local_fork=${local_fork:-y}

if [[ $local_fork == "y" ]]; then
    # Check if Anvil is running
    if ! pgrep -x "anvil" > /dev/null; then
        echo "Anvil is not running. Please start Anvil and try again."
        echo "You can spin up a local fork with the following command:"
        echo "anvil --fork-url ${FORK_RPC_URL}"
        exit 1
    fi  
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

while true; do
    echo ""
    echo "Select an option to deploy:"
    echo "0. ERC20 mock token"
    echo "1. Periphery factories (Oracle Router, Oracle Adapter Registry, Kink IRM Factory)"
    echo "2. Oracle adapter"
    echo "3. Kink IRM"
    echo "4. Integrations (EVC, Protocol Config, Sequence Registry, Balance Tracker, Permit2)"
    echo "5. EVault implementation (modules and implementation contract)"
    echo "6. EVault factory"
    echo "7. EVault"
    echo "8. Lenses"
    echo "9. Perspectives"
    echo "10. Swap"
    echo "11. Exit"
    read -p "Enter your choice (0-11): " choice

    if [[ "$choice" == "11" ]]; then
        echo "Exiting..."
        break
    fi

    case $choice in
        0)
            echo "Deploying ERC20 mock token..."

            fileName=00_MockERC20
            scriptFileName=$fileName.s.sol
            scriptJsonFileName=$fileName.json
            tempScriptJsonFileName=temp_$scriptJsonFileName
            backup_script_files $scriptJsonFileName $tempScriptJsonFileName

            read -p "Enter token name (default: MockERC20): " token_name
            token_name=${token_name:-MockERC20}

            read -p "Enter token symbol (default: MOCK): " token_symbol
            token_symbol=${token_symbol:-MOCK}

            read -p "Enter token decimals (default: 18): " token_decimals
            token_decimals=${token_decimals:-18}

            jq -n \
                --arg name "$token_name" \
                --arg symbol "$token_symbol" \
                --argjson decimals "$token_decimals" \
                '{
                    name: $name,
                    symbol: $symbol,
                    decimals: $decimals
                }' --indent 4 > script/input/$scriptJsonFileName
            ;;
        1)
            echo "Deploying periphery factories..."

            fileName=01_PeripheryFactories
            scriptFileName=$fileName.s.sol
            scriptJsonFileName=$fileName.json
            tempScriptJsonFileName=temp_$scriptJsonFileName
            backup_script_files $scriptJsonFileName $tempScriptJsonFileName
            ;;
        2)
            echo "Deploying oracle adapter..."
            echo "Select the type of oracle adapter to deploy:"
            echo "0. Chainlink"
            echo "1. Chronicle"
            echo "2. Lido"
            echo "3. Pyth"
            echo "4. Redstone"
            echo "5. Cross"
            read -p "Enter your choice (0-5): " adapter_choice

            scriptFileName=02_OracleAdapters.s.sol

            case $adapter_choice in
                0)
                    echo "Deploying Chainlink Adapter..."
                    
                    scriptFileName=$scriptFileName:ChainlinkAdapter
                    scriptJsonFileName=02_ChainlinkAdapter.json
                    tempScriptJsonFileName=temp_$scriptJsonFileName
                    backup_script_files $scriptJsonFileName $tempScriptJsonFileName

                    read -p "Enter the Adapter Registry address: " adapter_registry
                    read -p "Enter base token address: " base
                    read -p "Enter quote token address: " quote
                    read -p "Enter feed address: " feed
                    read -p "Enter max staleness (in seconds): " max_staleness

                    jq -n \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg base "$base" \
                        --arg quote "$quote" \
                        --arg feed "$feed" \
                        --argjson maxStaleness "$max_staleness" \
                        '{
                            adapterRegistry: $adapterRegistry,
                            base: $base,
                            quote: $quote,
                            feed: $feed,
                            maxStaleness: $maxStaleness
                        }' --indent 4 > script/input/$scriptJsonFileName
                    ;;
                1)
                    echo "Deploying Chronicle Adapter..."
                    scriptFileName=$scriptFileName:ChronicleAdapter
                    scriptJsonFileName=02_ChronicleAdapter.json
                    tempScriptJsonFileName=temp_$scriptJsonFileName
                    backup_script_files $scriptJsonFileName $tempScriptJsonFileName

                    read -p "Enter the Adapter Registry address: " adapter_registry
                    read -p "Enter base token address: " base
                    read -p "Enter quote token address: " quote
                    read -p "Enter feed address: " feed
                    read -p "Enter max staleness (in seconds): " max_staleness

                    jq -n \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg base "$base" \
                        --arg quote "$quote" \
                        --arg feed "$feed" \
                        --argjson maxStaleness "$max_staleness" \
                        '{
                            adapterRegistry: $adapterRegistry,
                            base: $base,
                            quote: $quote,
                            feed: $feed,
                            maxStaleness: $maxStaleness
                        }' --indent 4 > script/input/$scriptJsonFileName
                    ;;
                2)
                    echo "Deploying Lido Adapter..."
                    
                    scriptFileName=$scriptFileName:LidoAdapter
                    scriptJsonFileName=02_LidoAdapter.json
                    tempScriptJsonFileName=temp_$scriptJsonFileName
                    backup_script_files $scriptJsonFileName $tempScriptJsonFileName

                    read -p "Enter the Adapter Registry address: " adapter_registry

                    jq -n \
                        --arg adapterRegistry "$adapter_registry" \
                        '{
                            adapterRegistry: $adapterRegistry
                        }' --indent 4 > script/input/$scriptJsonFileName
                    ;;
                3)
                    echo "Deploying Pyth Adapter..."
                    
                    scriptFileName=$scriptFileName:PythAdapter
                    scriptJsonFileName=02_PythAdapter.json
                    tempScriptJsonFileName=temp_$scriptJsonFileName
                    backup_script_files $scriptJsonFileName $tempScriptJsonFileName

                    read -p "Enter the Adapter Registry address: " adapter_registry
                    read -p "Enter Pyth address: " pyth
                    read -p "Enter base token address: " base
                    read -p "Enter quote token address: " quote
                    read -p "Enter feed ID: " feed_id
                    read -p "Enter max staleness (in seconds): " max_staleness
                    read -p "Enter max confidence width: " max_conf_width

                    jq -n \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg pyth "$pyth" \
                        --arg base "$base" \
                        --arg quote "$quote" \
                        --arg feedId "$feed_id" \
                        --argjson maxStaleness "$max_staleness" \
                        --argjson maxConfWidth "$max_conf_width" \
                        '{
                            adapterRegistry: $adapterRegistry,
                            pyth: $pyth,
                            base: $base,
                            quote: $quote,
                            feedId: $feedId,
                            maxStaleness: $maxStaleness,
                            maxConfWidth: $maxConfWidth
                        }' --indent 4 > script/input/$scriptJsonFileName
                    ;;
                4)
                    echo "Deploying Redstone Adapter..."
                    
                    scriptFileName=$scriptFileName:RedstoneAdapter
                    scriptJsonFileName=02_RedstoneAdapter.json
                    tempScriptJsonFileName=temp_$scriptJsonFileName
                    backup_script_files $scriptJsonFileName $tempScriptJsonFileName

                    read -p "Enter the Adapter Registry address: " adapter_registry
                    read -p "Enter base token address: " base
                    read -p "Enter quote token address: " quote
                    read -p "Enter feed ID: " feed_id
                    read -p "Enter feed decimals: " feed_decimals
                    read -p "Enter max staleness (in seconds): " max_staleness

                    jq -n \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg base "$base" \
                        --arg quote "$quote" \
                        --arg feedId "$feed_id" \
                        --argjson feedDecimals "$feed_decimals" \
                        --argjson maxStaleness "$max_staleness" \
                        '{
                            adapterRegistry: $adapterRegistry,
                            base: $base,
                            quote: $quote,
                            feedId: $feedId,
                            feedDecimals: $feedDecimals,
                            maxStaleness: $maxStaleness
                        }' --indent 4 > script/input/$scriptJsonFileName
                    ;;
                5)
                    echo "Deploying Cross Adapter..."
                    
                    scriptFileName=$scriptFileName:CrossAdapter
                    scriptJsonFileName=02_CrossAdapter.json
                    tempScriptJsonFileName=temp_$scriptJsonFileName
                    backup_script_files $scriptJsonFileName $tempScriptJsonFileName

                    read -p "Enter the Adapter Registry address: " adapter_registry
                    read -p "Enter base token address: " base
                    read -p "Enter cross token address: " cross
                    read -p "Enter quote token address: " quote
                    read -p "Enter oracleBaseCross address: " oracle_base_cross
                    read -p "Enter oracleCrossQuote address: " oracle_cross_quote

                    jq -n \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg base "$base" \
                        --arg cross "$cross" \
                        --arg quote "$quote" \
                        --arg oracleBaseCross "$oracle_base_cross" \
                        --arg oracleCrossQuote "$oracle_cross_quote" \
                        '{
                            adapterRegistry: $adapterRegistry,
                            base: $base,
                            quote: $quote,
                            cross: $cross,
                            oracleBaseCross: $oracleBaseCross,
                            oracleCrossQuote: $oracleCrossQuote
                        }' --indent 4 > script/input/$scriptJsonFileName
                    ;;
                *)
                    echo "Invalid adapter choice. Exiting."
                    exit 1
                    ;;
            esac            
            ;;
        3)
            echo "Deploying kink IRM..."
            
            fileName=03_KinkIRM
            scriptFileName=$fileName.s.sol
            scriptJsonFileName=$fileName.json
            tempScriptJsonFileName=temp_$scriptJsonFileName
            backup_script_files $scriptJsonFileName $tempScriptJsonFileName

            read -p "Enter the IRM Factory address: " irm_factory
            read -p "Enter base rate SPY: " base_rate
            read -p "Enter slope1 parameter: " slope1
            read -p "Enter slope2 parameter: " slope2
            read -p "Enter kink parameter: " kink

            jq -n \
                --arg irmFactory "$irm_factory" \
                --arg baseRate "$base_rate" \
                --arg slope1 "$slope1" \
                --arg slope2 "$slope2" \
                --arg kink "$kink" \
                '{
                    irmFactory: $irmFactory,
                    baseRate: $baseRate,
                    slope1: $slope1,
                    slope2: $slope2,
                    kink: $kink
                }' --indent 4 > script/input/$scriptJsonFileName
            ;;
        4)
            echo "Deploying intergrations..."
            
            fileName=04_Integrations
            scriptFileName=$fileName.s.sol
            scriptJsonFileName=$fileName.json
            tempScriptJsonFileName=temp_$scriptJsonFileName
            backup_script_files $scriptJsonFileName $tempScriptJsonFileName
            ;;
        5)
            echo "Deploying EVault implementation..."
            
            fileName=05_EVaultImplementation
            scriptFileName=$fileName.s.sol
            scriptJsonFileName=$fileName.json
            tempScriptJsonFileName=temp_$scriptJsonFileName
            backup_script_files $scriptJsonFileName $tempScriptJsonFileName

            read -p "Enter the EVC address: " evc
            read -p "Enter the Protocol Config address: " protocol_config
            read -p "Enter the Sequence Registry address: " sequence_registry
            read -p "Enter the Balance Tracker address: " balance_tracker
            read -p "Enter the Permit2 address: " permit2

            jq -n \
                --arg evc "$evc" \
                --arg protocolConfig "$protocol_config" \
                --arg sequenceRegistry "$sequence_registry" \
                --arg balanceTracker "$balance_tracker" \
                --arg permit2 "$permit2" \
                '{
                    evc: $evc,
                    protocolConfig: $protocolConfig,
                    sequenceRegistry: $sequenceRegistry,
                    balanceTracker: $balanceTracker,
                    permit2: $permit2
                }' --indent 4 > script/input/$scriptJsonFileName
            ;;
        6)
            echo "Deploying EVault factory..."

            fileName=06_EVaultFactory
            scriptFileName=$fileName.s.sol
            scriptJsonFileName=$fileName.json
            tempScriptJsonFileName=temp_$scriptJsonFileName
            backup_script_files $scriptJsonFileName $tempScriptJsonFileName

            read -p "Enter the EVault implementation address: " evault_implementation

            jq -n \
                --arg eVaultImplementation "$evault_implementation" \
                '{
                    eVaultImplementation: $eVaultImplementation
                }' --indent 4 > script/input/$scriptJsonFileName
            ;;
        7)
            echo "Deploying EVault..."
            
            fileName=07_EVault
            scriptFileName=$fileName.s.sol
            scriptJsonFileName=$fileName.json
            tempScriptJsonFileName=temp_$scriptJsonFileName
            backup_script_files $scriptJsonFileName $tempScriptJsonFileName

            read -p "Should deploy a new router for the oracle? (y/n) (default: y): " deploy_router_for_oracle
            deploy_router_for_oracle=${deploy_router_for_oracle:-y}

            oracle_router_factory=0x0000000000000000000000000000000000000000
            if [[ $deploy_router_for_oracle != "n" ]]; then
                read -p "Enter the Oracle Router Factory address: " oracle_router_factory
            fi
            
            read -p "Enter the EVault Factory address: " evault_factory
            read -p "Should the vault be upgradable? (y/n) (default: n): " upgradable
            upgradable=${upgradable:-n}
            read -p "Enter the Asset address: " asset
            read -p "Enter the Oracle address: " oracle
            read -p "Enter the Unit of Account address: " unit_of_account

            jq -n \
                --argjson deployRouterForOracle "$(jq -n --argjson val \"$deploy_router_for_oracle\" 'if $val != "n" then true else false end')" \
                --arg oracleRouterFactory "$oracle_router_factory" \
                --arg eVaultFactory "$evault_factory" \
                --argjson upgradable "$(jq -n --argjson val \"$upgradable\" 'if $val == "y" then true else false end')" \
                --arg asset "$asset" \
                --arg oracle "$oracle" \
                --arg unitOfAccount "$unit_of_account" \
                '{
                    deployRouterForOracle: $deployRouterForOracle,
                    oracleRouterFactory: $oracleRouterFactory,
                    eVaultFactory: $eVaultFactory,
                    upgradable: $upgradable,
                    asset: $asset,
                    oracle: $oracle,
                    unitOfAccount: $unitOfAccount
                }' --indent 4 > script/input/$scriptJsonFileName
            ;;
        8)
            echo "Deploying lenses..."
            
            fileName=08_Lenses
            scriptFileName=$fileName.s.sol
            scriptJsonFileName=$fileName.json
            tempScriptJsonFileName=temp_$scriptJsonFileName
            backup_script_files $scriptJsonFileName $tempScriptJsonFileName
            ;;
        9)
            echo "Deploying Perspectives..."
            
            fileName=09_Perspectives
            scriptFileName=$fileName.s.sol
            scriptJsonFileName=$fileName.json
            tempScriptJsonFileName=temp_$scriptJsonFileName
            backup_script_files $scriptJsonFileName $tempScriptJsonFileName

            read -p "Enter the EVault Factory address: " evault_factory
            read -p "Enter the Oracle Router Factory address: " oracle_router_factory
            read -p "Enter the Oracle Adapter Registry address: " oracle_adapter_registry
            read -p "Enter the Kink IRM Factory address: " kink_irm_factory

            jq -n \
                --arg eVaultFactory "$evault_factory" \
                --arg oracleRouterFactory "$oracle_router_factory" \
                --arg oracleAdapterRegistry "$oracle_adapter_registry" \
                --arg kinkIRMFactory "$kink_irm_factory" \
                '{
                    eVaultFactory: $eVaultFactory,
                    oracleRouterFactory: $oracleRouterFactory,
                    oracleAdapterRegistry: $oracleAdapterRegistry,
                    kinkIRMFactory: $kinkIRMFactory
                }' --indent 4 > script/input/$scriptJsonFileName
            ;;
        10)
            echo "Deploying Swapper..."
            
            fileName=10_Swap
            scriptFileName=$fileName.s.sol
            scriptJsonFileName=$fileName.json
            tempScriptJsonFileName=temp_$scriptJsonFileName
            backup_script_files $scriptJsonFileName $tempScriptJsonFileName

            read -p "Enter the OneInch Aggregator address: " oneinch_aggregator
            read -p "Enter the Uniswap Router V2 address: " uniswap_router_v2
            read -p "Enter the Uniswap Router V3 address: " uniswap_router_v3
            read -p "Enter the Uniswap Router 02 address: " uniswap_router_02

            jq -n \
                --arg oneInchAggregator "$oneinch_aggregator" \
                --arg uniswapRouterV2 "$uniswap_router_v2" \
                --arg uniswapRouterV3 "$uniswap_router_v3" \
                --arg uniswapRouter02 "$uniswap_router_02" \
                '{
                    oneInchAggregator: $oneInchAggregator,
                    uniswapRouterV2: $uniswapRouterV2,
                    uniswapRouterV3: $uniswapRouterV3,
                    uniswapRouter02: $uniswapRouter02
                }' --indent 4 > script/input/$scriptJsonFileName
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac

    execute_forge_command $scriptFileName $verify_contracts
    backup_and_restore_script_files $scriptJsonFileName $tempScriptJsonFileName "$deployment_name"
done