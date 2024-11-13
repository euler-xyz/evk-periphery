#!/bin/bash

adapters_list="$1"

if [[ -f "$adapters_list" ]]; then
    yes_keys=()
    yes_counts=()

    while IFS=, read -r -a adapter_columns || [ -n "$adapter_columns" ]; do
        base_col=$(echo "${adapter_columns[5]}" | tr '[:upper:]' '[:lower:]')
        quote_col=$(echo "${adapter_columns[6]}" | tr '[:upper:]' '[:lower:]')
        indicative_price_col="${adapter_columns[8]}"
        key="${base_col}:${quote_col}"

        if [[ "$indicative_price_col" == "Yes" ]]; then
            if [[ " ${yes_keys[*]} " == *" $key "* ]]; then
                for i in "${!yes_keys[@]}"; do
                    if [[ "${yes_keys[i]}" == "$key" ]]; then
                        yes_counts[i]=$((yes_counts[i] + 1))
                        break
                    fi
                done
            else
                yes_keys+=("$key")
                yes_counts+=(1)
            fi
        fi
    done < <(tr -d '\r' < "$adapters_list")

    for i in "${!yes_keys[@]}"; do
        key="${yes_keys[i]}"
        yes_count="${yes_counts[i]}"

        if [[ "$yes_count" -gt 1 ]]; then
            echo "More than one row with Indicative Price 'Yes' for $key"
            exit 1
        fi
    done
fi
