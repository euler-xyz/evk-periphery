#!/bin/bash

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
echo "Welcome to the configuration script!"
echo "This script will guide you through the configuration process."

read -p "Do you want to work on a local fork? (y/n) (default: y): " local_fork
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

while true; do
    echo ""
    echo "Select an option to configure:"
    echo "0. ERC20 mock token"
    echo "1. Oracle Adapter Registry"
    echo "2. Euler Router"
    echo "3. EVault factory"
    echo "4. EVault"
    echo "5. Perspectives"
    echo "6. Exit"
    read -p "Enter your choice (0-6): " choice

    if [[ "$choice" == "6" ]]; then
        echo "Exiting..."
        break
    fi

    echo ""
    case $choice in
        0)
            echo "Configuring ERC20 mock token..."
            echo "Options:"
            echo "0. Mint"
            echo "1. Go back"
            read -p "Enter your choice (0-1): " sub_choice

            if [[ "$sub_choice" == "1" ]]; then
                continue
            fi

            case $sub_choice in
                0)
                    read -p "Enter the token address: " token_address
                    read -p "Enter the destination address: " destination_address
                    read -p "Enter the amount to mint: " amount

                    cast send $token_address "mint(address,uint256)" $destination_address $amount --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                *)
                    echo "Invalid choice. Exiting."
                    exit 1
                    ;;
            esac
            ;;
        1)
            echo "Configuring Oracle Adapter Registry..."
            echo "Options:"
            echo "0. Add oracle adapter"
            echo "1. Go back"
            read -p "Enter your choice (0-1): " sub_choice

            if [[ "$sub_choice" == "1" ]]; then
                continue
            fi

            case $sub_choice in
                0)
                    read -p "Enter the Oracle Adapter Registry address: " adapter_registry_address
                    read -p "Enter the Oracle Adapter address: " oracle_adapter_address
                    read -p "Enter the Base address: " base_address
                    read -p "Enter the Quote address: " quote_address

                    cast send $adapter_registry_address "add(address,address,address)" $oracle_adapter_address $base_address $quote_address --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                *)
                    echo "Invalid choice. Exiting."
                    exit 1
                    ;;
            esac
            ;;
        2)
            echo "Configuring Euler Router..."
            echo "Options:"
            echo "0. Set oracle config"
            echo "1. Set resolved vault"
            echo "2. Set fallback oracle"
            echo "3. Go back"
            read -p "Enter your choice (0-3): " sub_choice

            if [[ "$sub_choice" == "3" ]]; then
                continue
            fi

            read -p "Enter the Euler Router address: " euler_router_address

            case $sub_choice in
                0)
                    read -p "Enter the Base address: " base_address
                    read -p "Enter the Quote address: " quote_address
                    read -p "Enter the Oracle address: " oracle_address

                    cast send $euler_router_address "govSetConfig(address,address,address)" $base_address $quote_address $oracle_address --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                1)
                    read -p "Enter the Resolved Vault address: " resolved_vault_address
                    read -p "Do you want to set the resolved vault (true) or unset (false)?: " set_resolved_vault

                    cast send $euler_router_address "govSetResolvedVault(address,bool)" $resolved_vault_address $set_resolved_vault --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                2)
                    read -p "Enter the Fallback Oracle address: " fallback_oracle_address

                    cast send $euler_router_address "govSetFallbackOracle(address)" $fallback_oracle_address --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                *)
                    echo "Invalid choice. Exiting."
                    exit 1
                    ;;
            esac
            ;;
        3)
            echo "Configuring EVault Factory..."
            echo "Options:"
            echo "0. Set implementation"
            echo "1. Go back"
            read -p "Enter your choice (0-1): " sub_choice

            if [[ "$sub_choice" == "1" ]]; then
                continue
            fi

            case $sub_choice in
                0)
                    read -p "Enter the EVault Factory address: " evault_factory_address
                    read -p "Enter the EVault implementation address: " evault_implementation_address

                    cast send $evault_factory_address "setImplementation(address)" $evault_implementation_address --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                *)
                    echo "Invalid choice. Exiting."
                    exit 1
                    ;;
            esac
            ;;
        4)
            echo "Configuring EVault..."
            echo "Options:"
            echo "0. Set governor admin"
            echo "1. Set fee receiver"
            echo "2. Set LTV"
            echo "3. Set max liquidation discount"
            echo "4. Set liquidation cool off time"
            echo "5. Set interest rate model"
            echo "6. Set hook config"
            echo "7. Set config flags"
            echo "8. Set caps"
            echo "9. Set interest fee"
            echo "10. Go back"
            read -p "Enter your choice (0-10): " sub_choice

            if [[ "$sub_choice" == "10" ]]; then
                continue
            fi

            read -p "Enter the EVault address: " evault_address

            case $sub_choice in
                0)
                    read -p "Enter the governor admin address: " governor_admin_address

                    cast send $evault_address "setGovernorAdmin(address)" $governor_admin_address --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                1)
                    read -p "Enter the fee receiver address: " fee_receiver_address

                    cast send $evault_address "setFeeReceiver(address)" $fee_receiver_address --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                2)
                    read -p "Enter the collateral address: " collateral_address
                    read -p "Enter the borrow LTV: " borrow_ltv
                    read -p "Enter the liquidation LTV: " liquidation_ltv
                    read -p "Enter the ramp duration: " ramp_duration

                    cast send $evault_address "setLTV(address,uint16,uint16,uint32)" $collateral_address $borrow_ltv $liquidation_ltv $ramp_duration --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                3)
                    read -p "Enter the max liquidation discount: " max_liquidation_discount

                    cast send $evault_address "setMaxLiquidationDiscount(uint16)" $max_liquidation_discount --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                4)
                    read -p "Enter the liquidation cool off time: " liquidation_cool_off_time

                    cast send $evault_address "setLiquidationCoolOffTime(uint16)" $liquidation_cool_off_time --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                5)
                    read -p "Enter the interest rate model: " interest_rate_model

                    cast send $evault_address "setInterestRateModel(address)" $interest_rate_model --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                6)
                    read -p "Enter the hook target address: " hook_target_address
                    read -p "Enter the hooked ops: " hooked_ops

                    cast send $evault_address "setHookConfig(address,uint32)" $hook_target_address $hooked_ops --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                7)
                    read -p "Enter the config flags: " config_flags

                    cast send $evault_address "setConfigFlags(uint32)" $config_flags --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                8)
                    read -p "Enter the supply cap: " supply_cap
                    read -p "Enter the borrow cap: " borrow_cap

                    cast send $evault_address "setCaps(uint16,uint16)" $supply_cap $borrow_cap --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                9)
                    read -p "Enter the interest fee: " interest_fee

                    cast send $evault_address "setInterestFee(uint16)" $interest_fee --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                *)
                    echo "Invalid choice. Exiting."
                    exit 1
                    ;;
            esac
            ;;
        5)
            echo "Configuring Perspectives..."
            echo "Options:"
            echo "0. Verify vault"
            echo "1. Go back"
            read -p "Enter your choice (0-1): " sub_choice

            if [[ "$sub_choice" == "1" ]]; then
                continue
            fi

            case $sub_choice in
                0)
                    read -p "Enter the Perspectives address: " perspectives_address
                    read -p "Enter the EVault address: " evault_address

                    cast send $perspectives_address "perspectiveVerify(address,bool)" $evault_address true --private-key "$DEPLOYER_KEY" --rpc-url "$DEPLOYMENT_RPC_URL"
                    ;;
                *)
                    echo "Invalid choice. Exiting."
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
done