#!/bin/bash

function save_results {
    local jsonName=$1
    local deployment_name=$2
    local deployment_dir="script/deployments/$deployment_name"
    local chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)

    mkdir -p "$deployment_dir/input" "$deployment_dir/output" "$deployment_dir/broadcast"

    if [[ -f "script/${jsonName}_output.json" ]]; then
        local counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/input/${jsonName}.json")

        mv "script/${jsonName}_input.json" "$deployment_dir/input/${jsonName}_${counter}.json"
        mv "script/${jsonName}_output.json" "$deployment_dir/output/${jsonName}_${counter}.json"
        mv "./broadcast/${jsonName}.s.sol/$chainId/run-latest.json" "$deployment_dir/broadcast/${jsonName}_${counter}.json"
    else
        rm "script/${jsonName}_input.json"
    fi
}

if ! command -v jq &> /dev/null
then
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

while true; do
    echo ""
    echo "Select an option to deploy:"
    echo "0. ERC20 mock token"
    echo "1. Integrations (EVC, Protocol Config, Sequence Registry, Balance Tracker, Permit2)"
    echo "2. Periphery factories and registries"
    echo "3. Oracle adapter"
    echo "4. IRM"
    echo "5. EVault implementation (modules and implementation contract)"
    echo "6. EVault factory"
    echo "7. EVault"
    echo "8. Lenses"
    echo "9. Perspectives"
    echo "10. Swap"
    echo "11. Fee Flow"
    read -p "Enter your choice (0-11): " choice

    case $choice in
        0)
            echo "Deploying ERC20 mock token..."

            baseName=00_MockERC20
            scriptName=${baseName}.s.sol
            jsonName=$baseName

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
                }' --indent 4 > script/${jsonName}_input.json
            ;;
        1)
            echo "Deploying intergrations..."
        
            baseName=01_Integrations
            scriptName=${baseName}.s.sol
            jsonName=$baseName
            ;;
        2)
            echo "Deploying periphery factories..."
            
            baseName=02_PeripheryFactories
            scriptName=${baseName}.s.sol
            jsonName=$baseName

            read -p "Enter the EVC address: " evc

            jq -n \
                --arg evc "$evc" \
                '{
                    evc: $evc
                }' --indent 4 > script/${jsonName}_input.json
            ;;
        3)
            echo "Deploying oracle adapter..."
            echo "Select the type of oracle adapter to deploy:"
            echo "0. Chainlink"
            echo "1. Chronicle"
            echo "2. Lido"
            echo "3. Pyth"
            echo "4. Redstone"
            echo "5. Cross"
            echo "6. Uniswap"
            echo "7. Lido Fundamental"
            echo "8. Fixed Rate"
            echo "9. Rate Provider"
            read -p "Enter your choice (0-9): " adapter_choice

            baseName=03_OracleAdapters

            read -p "Should the adapter be added to the Adapter Registry? (y/n) (default: n): " add_to_adapter_registry
            add_to_adapter_registry=${add_to_adapter_registry:-n}

            adapter_registry=0x0000000000000000000000000000000000000000
            if [[ $add_to_adapter_registry != "n" ]]; then
                read -p "Enter the Adapter Registry address: " adapter_registry
            fi

            case $adapter_choice in
                0)
                    echo "Deploying Chainlink Adapter..."
                    
                    scriptName=${baseName}.s.sol:ChainlinkAdapter
                    jsonName=03_ChainlinkAdapter

                    read -p "Enter base token address: " base
                    read -p "Enter quote token address: " quote
                    read -p "Enter feed address: " feed
                    read -p "Enter max staleness (in seconds): " max_staleness

                    jq -n \
                        --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg base "$base" \
                        --arg quote "$quote" \
                        --arg feed "$feed" \
                        --argjson maxStaleness "$max_staleness" \
                        '{
                            addToAdapterRegistry: $addToAdapterRegistry,
                            adapterRegistry: $adapterRegistry,
                            base: $base,
                            quote: $quote,
                            feed: $feed,
                            maxStaleness: $maxStaleness
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                1)
                    echo "Deploying Chronicle Adapter..."

                    scriptName=${baseName}.s.sol:ChronicleAdapter
                    jsonName=03_ChronicleAdapter

                    read -p "Enter base token address: " base
                    read -p "Enter quote token address: " quote
                    read -p "Enter feed address: " feed
                    read -p "Enter max staleness (in seconds): " max_staleness

                    jq -n \
                        --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg base "$base" \
                        --arg quote "$quote" \
                        --arg feed "$feed" \
                        --argjson maxStaleness "$max_staleness" \
                        '{
                            addToAdapterRegistry: $addToAdapterRegistry,
                            adapterRegistry: $adapterRegistry,
                            base: $base,
                            quote: $quote,
                            feed: $feed,
                            maxStaleness: $maxStaleness
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                2)
                    echo "Deploying Lido Adapter..."
                    
                    scriptName=${baseName}.s.sol:LidoAdapter
                    jsonName=03_LidoAdapter

                    jq -n \
                        --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
                        --arg adapterRegistry "$adapter_registry" \
                        '{
                            addToAdapterRegistry: $addToAdapterRegistry,
                            adapterRegistry: $adapterRegistry
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                3)
                    echo "Deploying Pyth Adapter..."
                    
                    scriptName=${baseName}.s.sol:PythAdapter
                    jsonName=03_PythAdapter

                    read -p "Enter Pyth address: " pyth
                    read -p "Enter base token address: " base
                    read -p "Enter quote token address: " quote
                    read -p "Enter feed ID: " feed_id
                    read -p "Enter max staleness (in seconds): " max_staleness
                    read -p "Enter max confidence width: " max_conf_width

                    jq -n \
                        --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg pyth "$pyth" \
                        --arg base "$base" \
                        --arg quote "$quote" \
                        --arg feedId "$feed_id" \
                        --argjson maxStaleness "$max_staleness" \
                        --argjson maxConfWidth "$max_conf_width" \
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
                    ;;
                4)
                    echo "Deploying Redstone Adapter..."
                    
                    scriptName=${baseName}.s.sol:RedstoneAdapter
                    jsonName=03_RedstoneAdapter

                    read -p "Enter base token address: " base
                    read -p "Enter quote token address: " quote
                    read -p "Enter feed ID: " feed_id
                    read -p "Enter feed decimals: " feed_decimals
                    read -p "Enter max staleness (in seconds): " max_staleness

                    jq -n \
                        --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg base "$base" \
                        --arg quote "$quote" \
                        --arg feedId "$feed_id" \
                        --argjson feedDecimals "$feed_decimals" \
                        --argjson maxStaleness "$max_staleness" \
                        '{
                            addToAdapterRegistry: $addToAdapterRegistry,
                            adapterRegistry: $adapterRegistry,
                            base: $base,
                            quote: $quote,
                            feedId: $feedId,
                            feedDecimals: $feedDecimals,
                            maxStaleness: $maxStaleness
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                5)
                    echo "Deploying Cross Adapter..."
                    
                    scriptName=${baseName}.s.sol:CrossAdapterDeployer
                    jsonName=03_CrossAdapter

                    read -p "Enter base token address: " base
                    read -p "Enter cross token address: " cross
                    read -p "Enter quote token address: " quote
                    read -p "Enter oracleBaseCross address: " oracle_base_cross
                    read -p "Enter oracleCrossQuote address: " oracle_cross_quote

                    jq -n \
                        --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg base "$base" \
                        --arg cross "$cross" \
                        --arg quote "$quote" \
                        --arg oracleBaseCross "$oracle_base_cross" \
                        --arg oracleCrossQuote "$oracle_cross_quote" \
                        '{
                            addToAdapterRegistry: $addToAdapterRegistry,
                            adapterRegistry: $adapterRegistry,
                            base: $base,
                            quote: $quote,
                            cross: $cross,
                            oracleBaseCross: $oracleBaseCross,
                            oracleCrossQuote: $oracleCrossQuote
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                6)
                    echo "Deploying Uniswap Adapter..."
                    
                    scriptName=${baseName}.s.sol:UniswapAdapter
                    jsonName=03_UniswapAdapter

                    read -p "Enter tokenA address: " token_a
                    read -p "Enter tokenB address: " token_b
                    read -p "Enter fee: " fee
                    read -p "Enter twapWindow: " twap_window
                    read -p "Enter uniswapV3Factory address: " uniswap_v3_factory

                    jq -n \
                        --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg tokenA "$token_a" \
                        --arg tokenB "$token_b" \
                        --argjson fee "$fee" \
                        --argjson twapWindow "$twap_window" \
                        --arg uniswapV3Factory "$uniswap_v3_factory" \
                        '{
                            addToAdapterRegistry: $addToAdapterRegistry,
                            adapterRegistry: $adapterRegistry,
                            tokenA: $tokenA,
                            tokenB: $tokenB,
                            fee: $fee,
                            twapWindow: $twapWindow,
                            uniswapV3Factory: $uniswapV3Factory
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                7)
                    echo "Deploying Lido Fundamental Adapter..."
                    
                    scriptName=${baseName}.s.sol:LidoFundamentalAdapter
                    jsonName=03_LidoFundamentalAdapter

                    jq -n \
                        --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
                        --arg adapterRegistry "$adapter_registry" \
                        '{
                            addToAdapterRegistry: $addToAdapterRegistry,
                            adapterRegistry: $adapterRegistry
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                8)
                    echo "Deploying Fixed Rate Adapter..."
                    
                    scriptName=${baseName}.s.sol:FixedRateAdapter
                    jsonName=03_FixedRateAdapter

                    read -p "Enter base token address: " base
                    read -p "Enter quote token address: " quote
                    read -p "Enter rate: " rate

                    jq -n \
                        --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg base "$base" \
                        --arg quote "$quote" \
                        --argjson rate "$rate" \
                        '{
                            addToAdapterRegistry: $addToAdapterRegistry,
                            adapterRegistry: $adapterRegistry,
                            base: $base,
                            quote: $quote,
                            rate: $rate
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                9)
                    echo "Deploying Rate Provider Adapter..."
                    
                    scriptName=${baseName}.s.sol:RateProviderAdapter
                    jsonName=03_RateProviderAdapter

                    read -p "Enter base token address: " base
                    read -p "Enter quote token address: " quote
                    read -p "Enter rate provider address: " rate_provider

                    jq -n \
                        --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg base "$base" \
                        --arg quote "$quote" \
                        --arg rateProvider "$rate_provider" \
                        '{
                            addToAdapterRegistry: $addToAdapterRegistry,
                            adapterRegistry: $adapterRegistry,
                            base: $base,
                            quote: $quote,
                            rateProvider: $rateProvider
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                *)
                    echo "Invalid adapter choice. Exiting."
                    exit 1
                    ;;
            esac            
            ;;
        4)
            echo "Deploying IRM..."
            echo "Select the type of IRM to deploy:"
            echo "0. Kink"
            read -p "Enter your choice (0-0): " irm_choice

            baseName=04_IRM

            case $irm_choice in
                0)
                    echo "Deploying Kink IRM..."
                    
                    scriptName=${baseName}.s.sol:KinkIRM
                    jsonName=04_KinkIRM

                    read -p "Enter the Kink IRM Factory address: " kinkIRMFactory
                    read -p "Enter base rate SPY: " base_rate
                    read -p "Enter slope1 parameter: " slope1
                    read -p "Enter slope2 parameter: " slope2
                    read -p "Enter kink parameter: " kink

                    jq -n \
                        --arg kinkIRMFactory "$kinkIRMFactory" \
                        --argjson baseRate "$base_rate" \
                        --argjson slope1 "$slope1" \
                        --argjson slope2 "$slope2" \
                        --argjson kink "$kink" \
                        '{
                            kinkIRMFactory: $kinkIRMFactory,
                            baseRate: $baseRate,
                            slope1: $slope1,
                            slope2: $slope2,
                            kink: $kink
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                *)
                    echo "Invalid IRM choice. Exiting."
                    exit 1
                    ;;
            esac            
            ;;
        5)
            echo "Deploying EVault implementation..."

            baseName=05_EVaultImplementation
            scriptName=${baseName}.s.sol
            jsonName=$baseName

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
                }' --indent 4 > script/${jsonName}_input.json
            ;;
        6)
            echo "Deploying EVault factory..."

            baseName=06_EVaultFactory
            scriptName=${baseName}.s.sol
            jsonName=$baseName

            read -p "Enter the EVault implementation address: " evault_implementation

            jq -n \
                --arg eVaultImplementation "$evault_implementation" \
                '{
                    eVaultImplementation: $eVaultImplementation
                }' --indent 4 > script/${jsonName}_input.json
            ;;
        7)
            echo "Deploying EVault..."

            baseName=07_EVault
            scriptName=${baseName}.s.sol:EVaultDeployer
            jsonName=$baseName

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
                }' --indent 4 > script/${jsonName}_input.json
            ;;
        8)
            echo "Deploying lenses..."
            
            baseName=08_Lenses
            scriptName=${baseName}.s.sol
            jsonName=$baseName
            
            read -p "Enter the Oracle Adapter Registry address: " oracle_adapter_registry
            read -p "Enter the Kink IRM Factory address: " kink_irm_factory

            jq -n \
                --arg oracleAdapterRegistry "$oracle_adapter_registry" \
                --arg kinkIRMFactory "$kink_irm_factory" \
                '{
                    oracleAdapterRegistry: $oracleAdapterRegistry,
                    kinkIRMFactory: $kinkIRMFactory
                }' --indent 4 > script/${jsonName}_input.json
            ;;
        9)
            echo "Deploying Perspectives..."
            
            baseName=09_Perspectives
            scriptName=${baseName}.s.sol
            jsonName=$baseName

            read -p "Enter the EVault Factory address: " evault_factory
            read -p "Enter the Oracle Router Factory address: " oracle_router_factory
            read -p "Enter the Oracle Adapter Registry address: " oracle_adapter_registry
            read -p "Enter the External Vault Registry address: " external_vault_registry
            read -p "Enter the Kink IRM Factory address: " kink_irm_factory
            read -p "Enter the IRM Registry address: " irm_registry

            jq -n \
                --arg eVaultFactory "$evault_factory" \
                --arg oracleRouterFactory "$oracle_router_factory" \
                --arg oracleAdapterRegistry "$oracle_adapter_registry" \
                --arg externalVaultRegistry "$external_vault_registry" \
                --arg kinkIRMFactory "$kink_irm_factory" \
                --arg irmRegistry "$irm_registry" \
                '{
                    eVaultFactory: $eVaultFactory,
                    oracleRouterFactory: $oracleRouterFactory,
                    oracleAdapterRegistry: $oracleAdapterRegistry,
                    externalVaultRegistry: $externalVaultRegistry,
                    kinkIRMFactory: $kinkIRMFactory,
                    irmRegistry: $irmRegistry
                }' --indent 4 > script/${jsonName}_input.json
            ;;
        10)
            echo "Deploying Swapper..."
            
            baseName=10_Swap
            scriptName=${baseName}.s.sol
            jsonName=$baseName

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
                }' --indent 4 > script/${jsonName}_input.json
            ;;
        11)
            echo "Deploying Fee Flow..."

            baseName=11_FeeFlow
            scriptName=${baseName}.s.sol
            jsonName=$baseName

            read -p "Enter the EVC address: " evc
            read -p "Enter the init price: " init_price
            read -p "Enter the payment token address: " payment_token
            read -p "Enter the payment receiver address: " payment_receiver
            read -p "Enter the epoch period: " epoch_period
            read -p "Enter the price multiplier: " price_multiplier
            read -p "Enter the min init price: " min_init_price

            jq -n \
                --arg evc "$evc" \
                --argjson initPrice "$init_price" \
                --arg paymentToken "$payment_token" \
                --arg paymentReceiver "$payment_receiver" \
                --argjson epochPeriod "$epoch_period" \
                --argjson priceMultiplier "$price_multiplier" \
                --argjson minInitPrice "$min_init_price" \
                '{
                    evc: $evc,
                    initPrice: $initPrice,
                    paymentToken: $paymentToken,
                    paymentReceiver: $paymentReceiver,
                    epochPeriod: $epochPeriod,
                    priceMultiplier: $priceMultiplier,
                    minInitPrice: $minInitPrice
                }' --indent 4 > script/${jsonName}_input.json

            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac

    script/utils/executeForgeScript.sh $scriptName $verify_contracts
    save_results $jsonName "$deployment_name"
done