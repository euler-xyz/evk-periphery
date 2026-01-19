#!/bin/bash

source .env
eval "$(./script/utils/determineArgs.sh "$@")"
eval 'set -- $SCRIPT_ARGS'

echo "Welcome to the deployment script!"
echo "This script will guide you through the deployment process."

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

broadcast="--broadcast"
if [[ "$@" == *"--dry-run"* ]]; then
    set -- "${@/--dry-run/}"
    dry_run="--dry-run"
    broadcast=""
fi

if [[ "$@" == *"--verify"* ]]; then
    set -- "${@/--verify/}"
    verify="--verify"
fi

if ! script/utils/checkEnvironment.sh "$@"; then
    echo "Environment check failed. Exiting."
    exit 1
fi

eulerEarnCompilerOptions="--via-ir --optimize --optimizer-runs 200 --use 0.8.26 --out out-euler-earn"
eulerSwapCompilerOptions="--optimize --optimizer-runs 2500 --use 0.8.27 --out out-euler-swap"
securitizeFactoryCompilerOptions="--optimize --optimizer-runs 10000 --use 0.8.24 --out out-securitize-factory"

while true; do
    echo ""
    echo "Select an option to deploy/configure:"
    echo "0. ERC20 tokens"
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
    echo "12. Governors"
    echo "13. Terms of Use Signer"
    echo "14. Bridging contracts"
    echo "15. Edge factory"
    echo "---------------------------------"
    echo "20. EulerEarn factory and public allocator"
    echo "---------------------------------"
    echo "50. Core and Periphery Deployment and Configuration"
    echo "51. Core Ownership Transfer"
    echo "52. Periphery Ownership Transfer"
    echo "53. Access Control Configuration"
    read -p "Enter your choice: " choice

    case $choice in
        0)
            echo "Deploying ERC20 token..."
            echo "Select the type of ERC20 token to deploy:"
            echo "0. Mock Mintable ERC20"
            echo "1. Burnable-Mintable ERC20"
            echo "2. Reward token"
            read -p "Enter your choice (0-2): " token_choice

            baseName=00_ERC20

            case $token_choice in
                0)
                    echo "Deploying Mock Mintable ERC20..."

                    scriptName=${baseName}.s.sol:MockERC20MintableDeployer
                    jsonName=00_MockERC20Mintable

                    read -p "Enter token name (default: MockERC20Mintable): " token_name
                    token_name=${token_name:-MockERC20Mintable}

                    read -p "Enter token symbol (default: MOCK): " token_symbol
                    token_symbol=${token_symbol:-MOCK}

                    read -p "Enter token decimals (default: 18): " token_decimals
                    token_decimals=${token_decimals:-18}

                    jq -n \
                        --arg name "$token_name" \
                        --arg symbol "$token_symbol" \
                        --arg decimals "$token_decimals" \
                        '{
                            name: $name,
                            symbol: $symbol,
                            decimals: $decimals
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                1)
                    echo "Deploying Burnable-Mintable ERC20..."

                    scriptName=${baseName}.s.sol:ERC20BurnableMintableDeployer
                    jsonName=00_ERC20BurnableMintable

                    read -p "Enter token name: " token_name
                    read -p "Enter token symbol: " token_symbol
                    read -p "Enter token decimals (default: 18): " token_decimals
                    token_decimals=${token_decimals:-18}

                    jq -n \
                        --arg name "$token_name" \
                        --arg symbol "$token_symbol" \
                        --arg decimals "$token_decimals" \
                        '{
                            name: $name,
                            symbol: $symbol,
                            decimals: $decimals
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                2)
                    echo "Deploying Reward token..."

                    scriptName=${baseName}.s.sol:RewardTokenDeployer
                    jsonName=00_RewardToken

                    read -p "Enter EVC address: " evc
                    read -p "Enter receiver address: " receiver
                    read -p "Enter underlying token address: " underlying
                    read -p "Enter token name: " token_name
                    read -p "Enter token symbol: " token_symbol
                    
                    jq -n \
                        --arg evc "$evc" \
                        --arg receiver "$receiver" \
                        --arg underlying "$underlying" \
                        --arg name "$token_name" \
                        --arg symbol "$token_symbol" \
                        '{
                            evc: $evc,
                            receiver: $receiver,
                            underlying: $underlying,
                            name: $name,
                            symbol: $symbol
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                *)
                    echo "Invalid token choice. Exiting."
                    exit 1
                    ;;
            esac
            ;;
        1)
            echo "Deploying integrations..."
        
            baseName=01_Integrations
            scriptName=${baseName}.s.sol
            jsonName=$baseName

            read -p "Enter the Permit2 contract address (default: 0x000000000022D473030F116dDEE9F6B43aC78BA3): " permit2
            permit2=${permit2:-0x000000000022D473030F116dDEE9F6B43aC78BA3}

            jq -n \
                --arg permit2 "$permit2" \
                '{
                    permit2: $permit2
                }' --indent 4 > script/${jsonName}_input.json
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
            echo "10. Pendle"
            echo "11. Chainlink Infrequent"
            echo "12. Idle Tranche"
            read -p "Enter your choice (0-12): " adapter_choice

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
                        --arg maxStaleness "$max_staleness" \
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
                        --arg maxStaleness "$max_staleness" \
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
                        --arg maxStaleness "$max_staleness" \
                        --arg maxConfWidth "$max_conf_width" \
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
                        --arg feedDecimals "$feed_decimals" \
                        --arg maxStaleness "$max_staleness" \
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
                        --arg fee "$fee" \
                        --arg twapWindow "$twap_window" \
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
                        --arg rate "$rate" \
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
                10)
                    echo "Deploying Pendle Adapter..."
                    
                    scriptName=${baseName}.s.sol:PendleAdapter
                    jsonName=03_PendleAdapter

                    read -p "Enter Pendle Oracle address: " pendle_oracle
                    read -p "Enter Pendle Market address: " pendle_market
                    read -p "Enter base token address: " base
                    read -p "Enter quote token address: " quote
                    read -p "Enter twapWindow: " twap_window

                    jq -n \
                        --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg pendleOracle "$pendle_oracle" \
                        --arg pendleMarket "$pendle_market" \
                        --arg base "$base" \
                        --arg quote "$quote" \
                        --arg twapWindow "$twap_window" \
                        '{
                            addToAdapterRegistry: $addToAdapterRegistry,
                            adapterRegistry: $adapterRegistry,
                            pendleOracle: $pendleOracle,
                            pendleMarket: $pendleMarket,
                            base: $base,
                            quote: $quote,
                            twapWindow: $twapWindow
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                11)
                    echo "Deploying Chainlink Infrequent Adapter..."
                    
                    scriptName=${baseName}.s.sol:ChainlinkInfrequentAdapter
                    jsonName=03_ChainlinkInfrequentAdapter

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
                        --arg maxStaleness "$max_staleness" \
                        '{
                            addToAdapterRegistry: $addToAdapterRegistry,
                            adapterRegistry: $adapterRegistry,
                            base: $base,
                            quote: $quote,
                            feed: $feed,
                            maxStaleness: $maxStaleness
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                12)
                    echo "Deploying Idle Tranche Adapter..."
                    
                    scriptName=${baseName}.s.sol:IdleTranchesAdapter
                    jsonName=03_IdleTranchesAdapter

                    read -p "Enter CDO address: " cdo
                    read -p "Enter tranche address: " tranche

                    jq -n \
                        --argjson addToAdapterRegistry "$(jq -n --argjson val \"$add_to_adapter_registry\" 'if $val != "n" then true else false end')" \
                        --arg adapterRegistry "$adapter_registry" \
                        --arg cdo "$cdo" \
                        --arg tranche "$tranche" \
                        '{
                            addToAdapterRegistry: $addToAdapterRegistry,
                            adapterRegistry: $adapterRegistry,
                            cdo: $cdo,
                            tranche: $tranche
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
            echo "1. Adaptive Curve"
            read -p "Enter your choice (0-1): " irm_choice

            baseName=04_IRM

            case $irm_choice in
                0)
                    echo "Deploying Kink IRM..."
                    
                    scriptName=${baseName}.s.sol:KinkIRMDeployer
                    jsonName=04_KinkIRM

                    read -p "Enter the Kink IRM Factory address: " kinkIRMFactory
                    read -p "Enter base rate SPY: " base_rate
                    read -p "Enter slope1 parameter: " slope1
                    read -p "Enter slope2 parameter: " slope2
                    read -p "Enter kink parameter: " kink

                    jq -n \
                        --arg kinkIRMFactory "$kinkIRMFactory" \
                        --arg baseRate "$base_rate" \
                        --arg slope1 "$slope1" \
                        --arg slope2 "$slope2" \
                        --arg kink "$kink" \
                        '{
                            kinkIRMFactory: $kinkIRMFactory,
                            baseRate: $baseRate,
                            slope1: $slope1,
                            slope2: $slope2,
                            kink: $kink
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                1)
                    echo "Deploying Adaptive Curve IRM..."
                    
                    scriptName=${baseName}.s.sol:AdaptiveCurveIRMDeployer
                    jsonName=04_AdaptiveCurveIRM

                    read -p "Enter the Adaptive Curve IRM Factory address: " adaptiveCurveIRMFactory
                    read -p "Enter target utilization: " target_utilization
                    read -p "Enter initial rate at target: " initial_rate_at_target
                    read -p "Enter min rate at target: " min_rate_at_target
                    read -p "Enter max rate at target: " max_rate_at_target
                    read -p "Enter curve steepness: " curve_steepness
                    read -p "Enter adjustment speed: " adjustment_speed

                    jq -n \
                        --arg adaptiveCurveIRMFactory "$adaptiveCurveIRMFactory" \
                        --arg targetUtilization "$target_utilization" \
                        --arg initialRateAtTarget "$initial_rate_at_target" \
                        --arg minRateAtTarget "$min_rate_at_target" \
                        --arg maxRateAtTarget "$max_rate_at_target" \
                        --arg curveSteepness "$curve_steepness" \
                        --arg adjustmentSpeed "$adjustment_speed" \
                        '{
                            adaptiveCurveIRMFactory: $adaptiveCurveIRMFactory,
                            targetUtilization: $targetUtilization,
                            initialRateAtTarget: $initialRateAtTarget,
                            minRateAtTarget: $minRateAtTarget,
                            maxRateAtTarget: $maxRateAtTarget,
                            curveSteepness: $curveSteepness,
                            adjustmentSpeed: $adjustmentSpeed
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
            echo "Select the type of EVault to deploy:"
            echo "0. Vanilla EVault"
            echo "1. Singleton Escrow EVault"
            read -p "Enter your choice (0-1): " vault_choice

            baseName=07_EVault

            case $vault_choice in
                0)
                    echo "Deploying vanilla EVault..."
                    
                    scriptName=${baseName}.s.sol:EVaultDeployer
                    jsonName=07_EVault

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
                1)
                    echo "Deploying singleton escrow EVault..."
                    
                    scriptName=${baseName}.s.sol:EVaultSingletonEscrowDeployer
                    jsonName=07_EVaultSingletonEscrow

                    read -p "Enter the EVC address: " evc
                    read -p "Enter the Escrowed Collateral Perspective address: " escrowed_collateral_perspective
                    read -p "Enter the EVault Factory address: " evault_factory
                    read -p "Enter the Asset address: " asset

                    jq -n \
                        --arg evc "$evc" \
                        --arg escrowedCollateralPerspective "$escrowed_collateral_perspective" \
                        --arg eVaultFactory "$evault_factory" \
                        --arg asset "$asset" \
                        '{
                            evc: $evc,
                            escrowedCollateralPerspective: $escrowedCollateralPerspective,
                            eVaultFactory: $eVaultFactory,
                            asset: $asset
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                *)
                    echo "Invalid EVault choice. Exiting."
                    exit 1
                    ;;
            esac
            ;;
        8)
            echo "Deploying lenses..."
            echo "Select the type of lens to deploy:"
            echo "0. All (Account Lens, Vault Lens, Euler Earn Vault Lens, Oracle Lens, IRM Lens, Utils Lens)"
            echo "1. Account Lens"
            echo "2. Vault Lens"
            echo "3. Euler Earn Vault Lens"
            echo "4. Oracle Lens"
            echo "5. IRM Lens"
            echo "6. Utils Lens"
            read -p "Enter your choice (0-6): " lens_choice
            
            baseName=08_Lenses

            case $lens_choice in
                0)
                    echo "Deploying all lenses..."
                    
                    scriptName=${baseName}.s.sol:Lenses
                    jsonName=08_Lenses

                    read -p "Enter the EVault Factory address: " eVaultFactory
                    read -p "Enter the Oracle Adapter Registry address: " oracle_adapter_registry
                    read -p "Enter the Kink IRM Factory address: " kink_irm_factory
                    read -p "Enter the Adaptive Curve IRM Factory address (or press Enter for address(0)): " adaptive_curve_irm_factory
                    adaptive_curve_irm_factory=${adaptive_curve_irm_factory:-0x0000000000000000000000000000000000000000}
                    read -p "Enter the Kinky IRM Factory address (or press Enter for address(0)): " kinky_irm_factory
                    kinky_irm_factory=${kinky_irm_factory:-0x0000000000000000000000000000000000000000}
                    read -p "Enter the Fixed Cyclical Binary IRM Factory address (or press Enter for address(0)): " fixed_cyclical_binary_irm_factory
                    fixed_cyclical_binary_irm_factory=${fixed_cyclical_binary_irm_factory:-0x0000000000000000000000000000000000000000}

                    jq -n \
                        --arg eVaultFactory "$eVaultFactory" \
                        --arg oracleAdapterRegistry "$oracle_adapter_registry" \
                        --arg kinkIRMFactory "$kink_irm_factory" \
                        --arg adaptiveCurveIRMFactory "$adaptive_curve_irm_factory" \
                        --arg kinkyIRMFactory "$kinky_irm_factory" \
                        --arg fixedCyclicalBinaryIRMFactory "$fixed_cyclical_binary_irm_factory" \
                        '{
                            eVaultFactory: $eVaultFactory,
                            oracleAdapterRegistry: $oracleAdapterRegistry,
                            kinkIRMFactory: $kinkIRMFactory,
                            adaptiveCurveIRMFactory: $adaptiveCurveIRMFactory,
                            kinkyIRMFactory: $kinkyIRMFactory,
                            fixedCyclicalBinaryIRMFactory: $fixedCyclicalBinaryIRMFactory
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                1)
                    echo "Deploying Account Lens..."
                    
                    scriptName=${baseName}.s.sol:LensAccountDeployer
                    jsonName=08_LensAccount
                    ;;
                2)
                    echo "Deploying Vault Lens..."
                    
                    scriptName=${baseName}.s.sol:LensVaultDeployer
                    jsonName=08_LensVault
                    
                    read -p "Enter the Oracle Lens address: " oracle_lens
                    read -p "Enter the Utils Lens address: " utils_lens
                    read -p "Enter the IRM Lens address: " irm_lens

                    jq -n \
                        --arg oracleLens "$oracle_lens" \
                        --arg utilsLens "$utils_lens" \
                        --arg irmLens "$irm_lens" \
                        '{
                            oracleLens: $oracleLens,
                            utilsLens: $utilsLens,
                            irmLens: $irmLens
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                3)
                    echo "Deploying Euler Earn Vault Lens..."
                    
                    scriptName=${baseName}.s.sol:LensEulerEarnVaultDeployer
                    jsonName=08_LensEulerEarnVault
                    
                    read -p "Enter the Utils Lens address: " utils_lens

                    jq -n \
                        --arg utilsLens "$utils_lens" \
                        '{
                            utilsLens: $utilsLens
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                4)
                    echo "Deploying Oracle Lens..."

                    scriptName=${baseName}.s.sol:LensOracleDeployer
                    jsonName=08_LensOracle

                    read -p "Enter the Oracle Adapter Registry address: " oracle_adapter_registry

                    jq -n \
                        --arg oracleAdapterRegistry "$oracle_adapter_registry" \
                        '{
                            oracleAdapterRegistry: $oracleAdapterRegistry
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                5)
                    echo "Deploying IRM Lens..."

                    scriptName=${baseName}.s.sol:LensIRMDeployer
                    jsonName=08_LensIRM

                    read -p "Enter the Kink IRM Factory address: " kink_irm_factory

                    jq -n \
                        --arg kinkIRMFactory "$kink_irm_factory" \
                        '{
                            kinkIRMFactory: $kinkIRMFactory
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                6)
                    echo "Deploying Utils Lens..."

                    scriptName=${baseName}.s.sol:LensUtilsDeployer
                    jsonName=08_LensUtils
                    
                    read -p "Enter the EVault Factory address: " eVaultFactory
                    read -p "Enter the Oracle Lens address: " oracle_lens

                    jq -n \
                        --arg eVaultFactory "$eVaultFactory" \
                        --arg oracleLens "$oracle_lens" \
                        '{
                            eVaultFactory: $eVaultFactory,
                            oracleLens: $oracleLens
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                *)
                    echo "Invalid lens choice. Exiting."
                    exit 1
                    ;;
            esac            
            ;;
        9)
            echo "Deploying Perspectives..."
            echo "Select the type of perspectives to deploy:"
            echo "0. All EVK Perspectives (EVK Factory, Governed, Escrowed Collateral, Euler Ungoverned 0x, Euler Ungoverned nzx)"
            echo "1. Governed Perspective"
            echo "2. EVK Escrowed Collateral Perspective"
            echo "3. EVK Euler Ungoverned 0x Perspective"
            echo "4. EVK Euler Ungoverned nzx Perspective"
            echo "5. Euler Earn Perspectives"
            echo "6. Edge Perspectives"
            read -p "Enter your choice (0-6): " perspectives_choice

            baseName=09_Perspectives

            case $perspectives_choice in
                0)
                    echo "Deploying all EVK Perspectives..."

                    scriptName=${baseName}.s.sol:EVKPerspectives
                    jsonName=09_EVKPerspectives

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
                1)
                    echo "Deploying Governed Perspective..."

                    scriptName=${baseName}.s.sol:PerspectiveGovernedDeployer
                    jsonName=09_PerspectiveGoverned

                    read -p "Enter the EVC address: " evc

                    jq -n \
                        --arg evc "$evc" \
                        '{
                            evc: $evc
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                2)
                    echo "Deploying EVK Escrowed Collateral Perspective..."

                    scriptName=${baseName}.s.sol:EVKPerspectiveEscrowedCollateralDeployer
                    jsonName=09_EVKPerspectiveEscrowedCollateral

                    read -p "Enter the EVault Factory address: " evault_factory

                    jq -n \
                        --arg eVaultFactory "$evault_factory" \
                        '{
                            eVaultFactory: $eVaultFactory
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                3)
                    echo "Deploying EVK Euler Ungoverned 0x Perspective..."

                    scriptName=${baseName}.s.sol:EVKPerspectiveEulerUngoverned0xDeployer
                    jsonName=09_EVKPerspectiveEulerUngoverned0x

                    read -p "Enter the EVault Factory address: " evault_factory
                    read -p "Enter the Oracle Router Factory address: " oracle_router_factory
                    read -p "Enter the Oracle Adapter Registry address: " oracle_adapter_registry
                    read -p "Enter the External Vault Registry address: " external_vault_registry
                    read -p "Enter the Kink IRM Factory address: " kink_irm_factory
                    read -p "Enter the IRM Registry address: " irm_registry
                    read -p "Enter the Escrowed Collateral Perspective address: " escrowed_collateral_perspective

                    jq -n \
                        --arg eVaultFactory "$evault_factory" \
                        --arg oracleRouterFactory "$oracle_router_factory" \
                        --arg oracleAdapterRegistry "$oracle_adapter_registry" \
                        --arg externalVaultRegistry "$external_vault_registry" \
                        --arg kinkIRMFactory "$kink_irm_factory" \
                        --arg irmRegistry "$irm_registry" \
                        --arg escrowedCollateralPerspective "$escrowed_collateral_perspective" \
                        '{
                            eVaultFactory: $eVaultFactory,
                            oracleRouterFactory: $oracleRouterFactory,
                            oracleAdapterRegistry: $oracleAdapterRegistry,
                            externalVaultRegistry: $externalVaultRegistry,
                            kinkIRMFactory: $kinkIRMFactory,
                            irmRegistry: $irmRegistry,
                            escrowedCollateralPerspective: $escrowedCollateralPerspective
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                4)
                    echo "Deploying EVK Euler Ungoverned nzx Perspective..."

                    scriptName=${baseName}.s.sol:EVKPerspectiveEulerUngovernedNzxDeployer
                    jsonName=09_EVKPerspectiveEulerUngovernedNzx

                    read -p "Enter the EVault Factory address: " evault_factory
                    read -p "Enter the Oracle Router Factory address: " oracle_router_factory
                    read -p "Enter the Oracle Adapter Registry address: " oracle_adapter_registry
                    read -p "Enter the External Vault Registry address: " external_vault_registry
                    read -p "Enter the Kink IRM Factory address: " kink_irm_factory
                    read -p "Enter the IRM Registry address: " irm_registry
                    read -p "Enter the Governed Perspective address: " governed_perspective
                    read -p "Enter the Escrowed Collateral Perspective address: " escrowed_collateral_perspective

                    jq -n \
                        --arg eVaultFactory "$evault_factory" \
                        --arg oracleRouterFactory "$oracle_router_factory" \
                        --arg oracleAdapterRegistry "$oracle_adapter_registry" \
                        --arg externalVaultRegistry "$external_vault_registry" \
                        --arg kinkIRMFactory "$kink_irm_factory" \
                        --arg irmRegistry "$irm_registry" \
                        --arg governedPerspective "$governed_perspective" \
                        --arg escrowedCollateralPerspective "$escrowed_collateral_perspective" \
                        '{
                            eVaultFactory: $eVaultFactory,
                            oracleRouterFactory: $oracleRouterFactory,
                            oracleAdapterRegistry: $oracleAdapterRegistry,
                            externalVaultRegistry: $externalVaultRegistry,
                            kinkIRMFactory: $kinkIRMFactory,
                            irmRegistry: $irmRegistry,
                            governedPerspective: $governedPerspective,
                            escrowedCollateralPerspective: $escrowedCollateralPerspective
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                5)
                    echo "Deploying Euler Earn Perspectives..."

                    scriptName=${baseName}.s.sol:EulerEarnPerspectivesDeployer
                    jsonName=09_EulerEarnPerspectives

                    read -p "Enter the Euler Earn Factory address: " euler_earn_factory

                    jq -n \
                        --arg eulerEarnFactory "$euler_earn_factory" \
                        '{
                            eulerEarnFactory: $eulerEarnFactory
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                6)
                    echo "Deploying Edge Perspectives..."

                    scriptName=${baseName}.s.sol:EdgePerspectivesDeployer
                    jsonName=09_EdgePerspectives

                    read -p "Enter the Edge Factory address: " edge_factory

                    jq -n \
                        --arg edgeFactory "$edge_factory" \
                        '{
                            edgeFactory: $edgeFactory
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                *)
                    echo "Invalid perspectives choice. Exiting."
                    exit 1
                    ;;
            esac
            ;;
        10)
            echo "Deploying Swapper..."
            
            baseName=10_Swap
            scriptName=${baseName}.s.sol
            jsonName=$baseName

            read -p "Enter the Uniswap V2 Router02 address (look up: https://docs.uniswap.org/contracts/v2/reference/smart-contracts/v2-deployments): " uniswap_router_v2
            read -p "Enter the Uniswap V3 Router address (look up: https://docs.uniswap.org/contracts/v3/reference/deployments or https://docs.oku.trade/home/extra-information/deployed-contracts): " uniswap_router_v3

            jq -n \
                --arg uniswapRouterV2 "$uniswap_router_v2" \
                --arg uniswapRouterV3 "$uniswap_router_v3" \
                '{
                    uniswapRouterV2: $uniswapRouterV2,
                    uniswapRouterV3: $uniswapRouterV3
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
                --arg initPrice "$init_price" \
                --arg paymentToken "$payment_token" \
                --arg paymentReceiver "$payment_receiver" \
                --arg epochPeriod "$epoch_period" \
                --arg priceMultiplier "$price_multiplier" \
                --arg minInitPrice "$min_init_price" \
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
        12)
            echo "Deploying governor..."
            echo "Select the type of governor to deploy:"
            echo "0. EVault Factory Governor"
            echo "1. Governor Access Control"
            echo "2. Governor Access Control Emergency"
            read -p "Enter your choice (0-2): " governor_choice

            baseName=12_Governor

            case $governor_choice in
                0)
                    echo "Deploying EVault Factory Governor..."
            
                    scriptName=${baseName}.s.sol:EVaultFactoryGovernorDeployer
                    jsonName=12_EVaultFactoryGovernor
                    ;;
                1)
                    echo "Deploying Governor Access Control..."
                    
                    scriptName=${baseName}.s.sol:GovernorAccessControlDeployer
                    jsonName=12_GovernorAccessControl
                    
                    read -p "Enter the EVC address: " evc

                    jq -n \
                        --arg evc "$evc" \
                        '{
                            evc: $evc
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                2)
                    echo "Deploying Governor Access Control Emergency..."
                    
                    scriptName=${baseName}.s.sol:GovernorAccessControlEmergencyDeployer
                    jsonName=12_GovernorAccessControlEmergency
                    
                    read -p "Enter the EVC address: " evc

                    jq -n \
                        --arg evc "$evc" \
                        '{
                            evc: $evc
                        }' --indent 4 > script/${jsonName}_input.json
                    ;;
                *)
                    echo "Invalid governor choice. Exiting."
                    exit 1
                    ;;
            esac
            ;;
        13)
            echo "Deploying Terms of Use Signer..."

            baseName=13_TermsOfUseSigner
            scriptName=${baseName}.s.sol
            jsonName=$baseName

            read -p "Enter the EVC address: " evc

            jq -n \
                --arg evc "$evc" \
                '{
                    evc: $evc
                }' --indent 4 > script/${jsonName}_input.json
            ;;
        14)
            echo "Deploying Bridging contracts..."
            echo "Option unavailable!"
            
            baseName=skip

            ;;
        15)
            echo "Deploying Edge Factory..."

            baseName=15_EdgeFactory
            scriptName=${baseName}.s.sol
            jsonName=$baseName

            read -p "Enter the EVault Factory address: " evault_factory
            read -p "Enter the Oracle Router Factory address: " oracle_router_factory
            read -p "Enter the Escrowed Collateral Perspective address: " escrowed_collateral_perspective

            jq -n \
                --arg eVaultFactory "$evault_factory" \
                --arg oracleRouterFactory "$oracle_router_factory" \
                --arg escrowedCollateralPerspective "$escrowed_collateral_perspective" \
                '{
                    eVaultFactory: $eVaultFactory,
                    oracleRouterFactory: $oracleRouterFactory,
                    escrowedCollateralPerspective: $escrowedCollateralPerspective
                }' --indent 4 > script/${jsonName}_input.json
            ;;
        20)
            echo "Deploying Euler Earn factory..."

            baseName=20_EulerEarnFactory
            scriptName=${baseName}.s.sol
            jsonName=$baseName

            read -p "Enter the EVC address: " evc
            read -p "Enter the Permit2 address: " permit2
            read -p "Enter the Perspective address: " perspective

            forge compile lib/euler-earn/src $eulerEarnCompilerOptions

            jq -n \
                --arg evc "$evc" \
                --arg permit2 "$permit2" \
                --arg perspective "$perspective" \
                '{
                    evc: $evc,
                    permit2: $permit2,
                    perspective: $perspective
                }' --indent 4 > script/${jsonName}_input.json
            ;;
        50)
            echo "Deploying and configuring Core and Periphery..."

            baseName=50_CoreAndPeriphery
            scriptName=${baseName}.s.sol
            jsonName=$baseName

            addressZero=0x0000000000000000000000000000000000000000

            addresses_dir_path="${ADDRESSES_DIR_PATH%/}/$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)"
            mkdir -p "$addresses_dir_path"

            if [ "$(ls -A "$addresses_dir_path")" ]; then
                multisig_dao=$(jq -r '.DAO' "$addresses_dir_path/MultisigAddresses.json" 2>/dev/null)
                multisig_labs=$(jq -r '.labs' "$addresses_dir_path/MultisigAddresses.json" 2>/dev/null)
                multisig_security_council=$(jq -r '.securityCouncil' "$addresses_dir_path/MultisigAddresses.json" 2>/dev/null)
                multisig_security_partner_A=$(jq -r '.securityPartnerA' "$addresses_dir_path/MultisigAddresses.json" 2>/dev/null)
                multisig_security_partner_B=$(jq -r '.securityPartnerB' "$addresses_dir_path/MultisigAddresses.json" 2>/dev/null)
                evc=$(jq -r '.evc' "$addresses_dir_path/CoreAddresses.json" 2>/dev/null)
                swapper=$(jq -r '.swapper' "$addresses_dir_path/PeripheryAddresses.json" 2>/dev/null)
                feeFlowController=$(jq -r '.feeFlowController' "$addresses_dir_path/PeripheryAddresses.json" 2>/dev/null)
                securitizeFactory=$(jq -r '.securitizeFactory' "$addresses_dir_path/PeripheryAddresses.json" 2>/dev/null)
                eulOFTAdapter=$(jq -r '.eulOFTAdapter' "$addresses_dir_path/BridgeAddresses.json" 2>/dev/null)
                eusdOFTAdapter=$(jq -r '.eusdOFTAdapter' "$addresses_dir_path/BridgeAddresses.json" 2>/dev/null)
                seusdOFTAdapter=$(jq -r '.seusdOFTAdapter' "$addresses_dir_path/BridgeAddresses.json" 2>/dev/null)
                eulerEarnFactory=$(jq -r '.eulerEarnFactory' "$addresses_dir_path/CoreAddresses.json" 2>/dev/null)
                eulerEarnFactory=${eulerEarnFactory:-$addressZero}
                eulerSwapV2Factory=$(jq -r '.eulerSwapV2Factory' "$addresses_dir_path/EulerSwapAddresses.json" 2>/dev/null)
            fi

            if [ -z "$multisig_dao" ] || [ "$multisig_dao" == "$addressZero" ] || [ "$multisig_dao" == "null" ]; then
                read -p "Enter the DAO multisig address: " multisig_dao
                read -p "Enter the Labs multisig address: " multisig_labs
                read -p "Enter the Security Council multisig address: " multisig_security_council
                read -p "Enter the Security Partner A address: " multisig_security_partner_A
                read -p "Enter the Security Partner B address: " multisig_security_partner_B
            fi

            if [ -z "$evc" ] || [ "$evc" == "$addressZero" ] || [ "$evc" == "null" ]; then
                read -p "Enter the Permit2 address (default: 0x000000000022D473030F116dDEE9F6B43aC78BA3 or look up https://docs.oku.trade/home/extra-information/deployed-contracts): " permit2
            fi
            
            if [ -z "$swapper" ] || [ "$swapper" == "$addressZero" ] || [ "$swapper" == "null" ]; then
                read -p "Enter the Uniswap V2 Router 02 address (default: address(0) or look up https://docs.uniswap.org/contracts/v2/reference/smart-contracts/v2-deployments): " uniswap_router_v2
                read -p "Enter the Uniswap V3 Router address (default: address(0) or look up https://docs.uniswap.org/contracts/v3/reference/deployments or https://docs.oku.trade/home/extra-information/deployed-contracts): " uniswap_router_v3
            fi
            
            if [ -z "$feeFlowController" ] || [ "$feeFlowController" == "$addressZero" ] || [ "$feeFlowController" == "null" ]; then
                read -p "Enter the init price for Fee Flow (default: 1e18 or enter 0 to skip): " init_price
            fi

            if [ -z "$eulOFTAdapter" ] || [ "$eulOFTAdapter" == "$addressZero" ] || [ "$eulOFTAdapter" == "null" ]; then
                read -p "Should deploy and configure EUL OFT Adapter? (y/n) (default: n): " deploy_eul_oft
            fi

            if [ -z "$eulerEarnFactory" ] || [ "$eulerEarnFactory" == "$addressZero" ] || [ "$eulerEarnFactory" == "null" ]; then
                read -p "Should deploy Euler Earn? (y/n) (default: n): " deploy_euler_earn
            fi

            if [ -z "$eulerSwapV2Factory" ] || [ "$eulerSwapV2Factory" == "$addressZero" ] || [ "$eulerSwapV2Factory" == "null" ]; then
                read -p "Should deploy EulerSwap V2? (y/n) (default: n): " deploy_euler_swap
                
                if [ "$deploy_euler_swap" = "y" ]; then
                    read -p "Enter the Uniswap V4 Pool Manager address (default: address(0) or look up https://docs.uniswap.org/contracts/v4/deployments): " uniswap_pool_manager
                    read -p "Enter the EulerSwap protocol fee config admin address (default: DAO multisig): " euler_swap_protocol_fee_config_admin
                    read -p "Enter the EulerSwap registry curator (default: Labs multisig): " euler_swap_registry_curator
                fi
            fi

            if [ -z "$eusdOFTAdapter" ] || [ "$eusdOFTAdapter" == "$addressZero" ] || [ "$eusdOFTAdapter" == "null" ]; then
                read -p "Should deploy and configure eUSD contracts system? (y/n) (default: n): " deploy_eusd
            fi

            if [ -z "$seusdOFTAdapter" ] || [ "$seusdOFTAdapter" == "$addressZero" ] || [ "$seusdOFTAdapter" == "null" ]; then
                read -p "Should deploy and configure seUSD contracts system? (y/n) (default: n): " deploy_seusd
            fi

            if [ -z "$securitizeFactory" ] || [ "$securitizeFactory" == "$addressZero" ] || [ "$securitizeFactory" == "null" ]; then
                read -p "Should deploy Securitize Vault Factory? (y/n) (default: n): " deploy_securitize_factory
            fi

            multisig_dao=${multisig_dao:-$addressZero}
            multisig_labs=${multisig_labs:-$addressZero}
            multisig_security_council=${multisig_security_council:-$addressZero}
            multisig_security_partner_A=${multisig_security_partner_A:-$addressZero}
            multisig_security_partner_B=${multisig_security_partner_B:-$addressZero}
            permit2=${permit2:-0x000000000022D473030F116dDEE9F6B43aC78BA3}
            uniswap_router_v2=${uniswap_router_v2:-$addressZero}
            uniswap_router_v3=${uniswap_router_v3:-$addressZero}
            init_price=${init_price:-1000000000000000000}
            deploy_eul_oft=${deploy_eul_oft:-n}
            deploy_euler_earn=${deploy_euler_earn:-n}
            deploy_euler_swap=${deploy_euler_swap:-n}
            deploy_eusd=${deploy_eusd:-n}
            deploy_seusd=${deploy_seusd:-n}
            deploy_securitize_factory=${deploy_securitize_factory:-n}
            uniswap_pool_manager=${uniswap_pool_manager:-$addressZero}
            euler_swap_protocol_fee_config_admin=${euler_swap_protocol_fee_config_admin:-$multisig_dao}
            euler_swap_registry_curator=${euler_swap_registry_curator:-$multisig_labs}

            if { [ -z "$eulerEarnFactory" ] || [ "$eulerEarnFactory" == "$addressZero" ] || [ "$eulerEarnFactory" == "null" ]; } && [ "$deploy_euler_earn" = "y" ]; then
                forge compile lib/euler-earn/src $eulerEarnCompilerOptions --force
            fi

            if { [ -z "$eulerSwapV2Factory" ] || [ "$eulerSwapV2Factory" == "$addressZero" ] || [ "$eulerSwapV2Factory" == "null" ]; } && [ "$deploy_euler_swap" = "y" ]; then
                forge compile lib/euler-swap/src $eulerSwapCompilerOptions --force
            fi

            if { [ -z "$securitizeFactory" ] || [ "$securitizeFactory" == "$addressZero" ] || [ "$securitizeFactory" == "null" ]; } && [ "$deploy_securitize_factory" = "y" ]; then
                forge compile src/VaultFactory/ERC4626EVCCollateralSecuritizeFactory.sol $securitizeFactoryCompilerOptions --force
            fi

            if [[ "$@" != *"--ffi"* ]]; then
                set -- "$@" --ffi
            fi

            jq -n \
                --arg multisigDAO "$multisig_dao" \
                --arg multisigLabs "$multisig_labs" \
                --arg multisigSecurityCouncil "$multisig_security_council" \
                --arg multisigSecurityPartnerA "$multisig_security_partner_A" \
                --arg multisigSecurityPartnerB "$multisig_security_partner_B" \
                --arg permit2 "$permit2" \
                --arg uniswapRouterV2 "$uniswap_router_v2" \
                --arg uniswapRouterV3 "$uniswap_router_v3" \
                --arg initPrice "$init_price" \
                --argjson deployEULOFT "$(jq -n --argjson val \"$deploy_eul_oft\" 'if $val == "y" then true else false end')" \
                --argjson deployEulerEarn "$(jq -n --argjson val \"$deploy_euler_earn\" 'if $val == "y" then true else false end')" \
                --argjson deployEulerSwap "$(jq -n --argjson val \"$deploy_euler_swap\" 'if $val == "y" then true else false end')" \
                --argjson deployEUSD "$(jq -n --argjson val \"$deploy_eusd\" 'if $val == "y" then true else false end')" \
                --argjson deploySEUSD "$(jq -n --argjson val \"$deploy_seusd\" 'if $val == "y" then true else false end')" \
                --argjson deploySecuritizeFactory "$(jq -n --argjson val \"$deploy_securitize_factory\" 'if $val == "y" then true else false end')" \
                --arg uniswapPoolManager "$uniswap_pool_manager" \
                --arg eulerSwapProtocolFeeConfigAdmin "$euler_swap_protocol_fee_config_admin" \
                --arg eulerSwapRegistryCurator "$euler_swap_registry_curator" \
                '{
                    multisigDAO: $multisigDAO,
                    multisigLabs: $multisigLabs,
                    multisigSecurityCouncil: $multisigSecurityCouncil,
                    multisigSecurityPartnerA: $multisigSecurityPartnerA,
                    multisigSecurityPartnerB: $multisigSecurityPartnerB,
                    permit2: $permit2,
                    uniswapV2Router: $uniswapRouterV2,
                    uniswapV3Router: $uniswapRouterV3,
                    feeFlowInitPrice: $initPrice,
                    deployEULOFT: $deployEULOFT,
                    deployEulerEarn: $deployEulerEarn,
                    deployEulerSwap: $deployEulerSwap,
                    deployEUSD: $deployEUSD,
                    deploySEUSD: $deploySEUSD,
                    deploySecuritizeFactory: $deploySecuritizeFactory,
                    uniswapPoolManager: $uniswapPoolManager,
                    eulerSwapProtocolFeeConfigAdmin: $eulerSwapProtocolFeeConfigAdmin,
                    eulerSwapRegistryCurator: $eulerSwapRegistryCurator
                }' --indent 4 > script/${jsonName}_input.json
            ;;
        51)
            echo "Core Ownership Transfer..."

            baseName=51_OwnershipTransferCore
            scriptName=${baseName}.s.sol
            jsonName=$baseName
            ;;
        52)
            echo "Periphery Ownership Transfer..."

            baseName=52_OwnershipTransferPeriphery
            scriptName=${baseName}.s.sol
            jsonName=$baseName
            ;;
        53)
            echo "Access Control Configuration..."
            
            baseName=skip
            
            read -p "Enter the Access Control contract address: " access_control_contract_address
            read -p "Enter the Account address to grant/revoke role: " account_address

            echo "Enter the role by: "
            echo "0. Bytes32 role identifier"
            echo "1. Bytes4 function selector, i.e. 0x12345678"
            echo "2. String function signature, i.e. setFeeReceiver(address)"
            echo "3. String role name, i.e. LTV_EMERGENCY_ROLE"
            read -p "Enter your choice (0-3): " role_choice
            
            case $role_choice in
                0)
                    read -p "Enter the bytes32 role identifier: " bytes32_role_identifier
                    ;;
                1)
                    read -p "Enter the bytes4 function selector: " selector_role
                    bytes32_role_identifier=$(cast to-bytes32 $selector_role)
                    ;;
                2)
                    read -p "Enter the string function signature: " signature_role
                    selector_role=$(cast sig $signature_role)
                    bytes32_role_identifier=$(cast to-bytes32 $selector_role)
                    ;;
                3)
                    read -p "Enter the string role name: " string_role_name
                    bytes32_role_identifier=$(cast keccak $string_role_name)
                    ;;
                *)
                    echo "Invalid role choice. Exiting."
                    exit 1
                    ;;
            esac

            echo "Select the operation type:"
            echo "0. Grant Role"
            echo "1. Revoke Role"
            read -p "Enter your choice (0-1): " operation_type
            
            case $operation_type in
                0)
                    echo "Granting role ($bytes32_role_identifier) to account ($account_address) on governor contract ($governor_contract_address)"
                    signature="grantRole(bytes32,address)"
                    ;;
                1)
                    echo "Revoking role ($bytes32_role_identifier) from account ($account_address) on governor contract ($governor_contract_address)"
                    signature="revokeRole(bytes32,address)"
                    ;;
                *)
                    echo "Invalid operation type. Exiting."
                    exit 1
                    ;;
            esac

            cast send $access_control_contract_address $signature $bytes32_role_identifier $account_address --rpc-url $DEPLOYMENT_RPC_URL --legacy $@
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac

    if [ $baseName == "skip" ]; then
        continue
    fi

    if script/utils/executeForgeScript.sh $scriptName "$@" $verify $dry_run; then
        source .env
        eval "$(./script/utils/determineArgs.sh "$@")"
        eval 'set -- $SCRIPT_ARGS'
        chainId=$(cast chain-id --rpc-url $DEPLOYMENT_RPC_URL)
        deployment_dir="script/deployments/$deployment_name/$chainId"
        broadcast_dir="broadcast/${scriptName%:*}/$chainId"

        if [ "$dry_run" = "--dry-run" ]; then
            deployment_dir="$deployment_dir/dry-run"
            broadcast_dir="$broadcast_dir/dry-run"
        fi

        mkdir -p "$deployment_dir/broadcast" "$deployment_dir/input" "$deployment_dir/output"

        counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/broadcast/${jsonName}.json")
        cp "$broadcast_dir/run-latest.json" "$deployment_dir/broadcast/${jsonName}_${counter}.json"

        for json_file in script/*_input.json; do
            [ -e "$json_file" ] || continue
            jsonFileName=$(basename "${json_file/_input/}")
            counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/input/$jsonFileName")

            mv "$json_file" "$deployment_dir/input/${jsonFileName%.json}_$counter.json"
        done

        for json_file in script/*_output.json; do
            [ -e "$json_file" ] || continue
            jsonFileName=$(basename "${json_file/_output/}")
            counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/output/$jsonFileName")

            mv "$json_file" "$deployment_dir/output/${jsonFileName%.json}_$counter.json"
        done

        for json_file in script/*.json; do
            [ -e "$json_file" ] || continue
            jsonFileName=$(basename "${json_file}")
            counter=$(script/utils/getFileNameCounter.sh "$deployment_dir/output/$jsonFileName")

            mv "$json_file" "$deployment_dir/output/${jsonFileName%.json}_$counter.json"
        done
    else
        for json_file in script/*.json; do
            [ -e "$json_file" ] || continue
            rm "$json_file"
        done
    fi
done
